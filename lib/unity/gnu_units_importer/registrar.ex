defmodule Unity.GnuUnitsImporter.Registrar do
  @moduledoc """
  Pass 3: converts resolved GNU unit definitions into Localize custom
  unit registrations.

  Maps GNU primitive dimensions to CLDR base unit names, determines
  categories, and either registers units directly or produces `.exs`
  export data.

  """

  @primitive_to_cldr %{
    "s" => "second",
    "m" => "meter",
    "kg" => "kilogram",
    "K" => "kelvin",
    "A" => "ampere",
    "mol" => "mole",
    "cd" => "candela",
    "radian" => "radian",
    "sr" => "steradian",
    "bit" => "bit"
  }

  @cldr_power_prefix %{2 => "square-", 3 => "cubic-"}

  # CLDR compound unit component ordering, derived from the base_unit_order
  # in CLDR supplemental data. Components in compound unit strings must
  # appear in this order for category lookups to match.
  @cldr_component_order %{
    "candela" => 0,
    "kilogram" => 1,
    "meter" => 2,
    "second" => 3,
    "ampere" => 4,
    "kelvin" => 5,
    "mole" => 6,
    "steradian" => 7,
    "radian" => 8,
    "bit" => 9
  }

  @base_unit_to_quantity Localize.Unit.Data.base_unit_to_quantity()
  @existing_conversions Localize.Unit.Data.conversions()
  @valid_name_pattern ~r/^[a-z][a-z0-9_-]*$/

  @doc """
  Registers all resolved definitions via `Localize.Unit.define_unit/2`.

  ### Arguments

  * `resolved` — map of `name => {factor, dimensions}` from the resolver.

  ### Returns

  * `%{imported: count, skipped: count, errors: [{name, reason}]}`

  """
  @spec register_all(%{String.t() => {float(), map()}}) :: %{
          imported: non_neg_integer(),
          skipped: non_neg_integer(),
          errors: [{String.t(), String.t()}]
        }
  def register_all(resolved) do
    results =
      resolved
      |> Enum.map(fn {name, {factor, dims}} ->
        register_one(name, factor, dims)
      end)

    imported = Enum.count(results, &match?(:ok, &1))
    errors = Enum.filter(results, &match?({:error, _, _}, &1))
    error_pairs = Enum.map(errors, fn {:error, name, reason} -> {name, reason} end)

    %{
      imported: imported,
      skipped: length(results) - imported,
      errors: error_pairs
    }
  end

  @doc """
  Converts resolved definitions into a list of definition maps suitable
  for `Localize.Unit.load_custom_units/1`.

  """
  @spec to_definition_list(%{String.t() => {float(), map()}}) :: [map()]
  def to_definition_list(resolved) do
    resolved
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.flat_map(fn {name, {factor, dims}} ->
      case build_definition(name, factor, dims) do
        {:ok, definition} -> [definition]
        {:error, _reason} -> []
      end
    end)
  end

  @doc """
  Extracts dimensionless resolved entries as named constants.

  Returns a map of `%{name => numeric_value}` suitable for use as
  `let` bindings in a Unity evaluation environment.

  ### Arguments

  * `resolved` — map of `name => {factor, dimensions}` from the resolver.

  ### Returns

  * A map of `%{String.t() => number()}`.

  """
  @spec constants(%{String.t() => {float(), map()}}) :: %{String.t() => number()}
  def constants(resolved) do
    resolved
    |> Enum.filter(fn {_name, {_factor, dims}} -> map_size(dims) == 0 end)
    |> Enum.map(fn {name, {factor, _dims}} -> {String.downcase(name), factor} end)
    |> Enum.filter(fn {name, _} -> Regex.match?(@valid_name_pattern, name) end)
    |> Map.new()
  end

  # ── Private ──

  defp register_one(name, factor, dims) do
    case build_definition(name, factor, dims) do
      {:ok, %{unit: unit_name} = definition} ->
        case Localize.Unit.define_unit(unit_name, Map.delete(definition, :unit)) do
          :ok -> :ok
          {:error, reason} -> {:error, name, reason}
        end

      {:error, reason} ->
        {:error, name, reason}
    end
  end

  defp build_definition(name, factor, dims) do
    lower_name = String.downcase(name)

    with :ok <- validate_name(lower_name),
         :ok <- validate_no_collision(lower_name),
         {:ok, base_unit} <- dims_to_cldr_base_unit(dims),
         {:ok, category} <- lookup_category(base_unit) do
      definition = %{
        unit: lower_name,
        base_unit: base_unit,
        factor: factor,
        category: category,
        display: build_display(lower_name)
      }

      {:ok, definition}
    end
  end

  defp validate_name(name) do
    if Regex.match?(@valid_name_pattern, name) do
      :ok
    else
      {:error, "invalid name: #{inspect(name)}"}
    end
  end

  defp validate_no_collision(name) do
    if Map.has_key?(@existing_conversions, name) do
      {:error, "collides with CLDR unit: #{name}"}
    else
      :ok
    end
  end

  # Converts a dimension map like %{"m" => 1, "s" => -2} to a CLDR
  # base unit string like "meter-per-square-second".
  defp dims_to_cldr_base_unit(dims) when map_size(dims) == 0 do
    {:error, "dimensionless"}
  end

  defp dims_to_cldr_base_unit(dims) do
    {numerator, denominator} =
      Enum.split_with(dims, fn {_name, power} -> power > 0 end)

    num_parts =
      numerator
      |> Enum.sort_by(fn {name, _} -> cldr_sort_position(name) end)
      |> Enum.map(fn {name, power} -> format_cldr_component(name, power) end)

    den_parts =
      denominator
      |> Enum.sort_by(fn {name, _} -> cldr_sort_position(name) end)
      |> Enum.map(fn {name, power} -> format_cldr_component(name, abs(power)) end)

    case {num_parts, den_parts} do
      {[], []} ->
        {:error, "dimensionless"}

      {num, []} ->
        {:ok, Enum.join(num, "-")}

      {[], den} ->
        {:ok, "per-" <> Enum.join(den, "-")}

      {num, den} ->
        {:ok, Enum.join(num, "-") <> "-per-" <> Enum.join(den, "-")}
    end
  end

  defp cldr_sort_position(gnu_name) do
    cldr_name = Map.get(@primitive_to_cldr, gnu_name, gnu_name)
    Map.get(@cldr_component_order, cldr_name, 99)
  end

  defp format_cldr_component(gnu_name, power) do
    cldr_name = Map.get(@primitive_to_cldr, gnu_name, gnu_name)
    power_prefix = Map.get(@cldr_power_prefix, power, "")

    if power > 3 do
      "pow#{power}-#{cldr_name}"
    else
      "#{power_prefix}#{cldr_name}"
    end
  end

  defp lookup_category(base_unit) do
    category =
      Map.get(@base_unit_to_quantity, base_unit) ||
        case Localize.Unit.unit_category(base_unit) do
          {:ok, cat} -> cat
          _ -> nil
        end

    if is_nil(category) do
      {:error, "unknown category for base unit: #{base_unit}"}
    else
      {:ok, category}
    end
  end

  defp build_display(name) do
    # Simple English-only display: singular and naive plural (add "s")
    plural = naive_plural(name)

    %{
      en: %{
        long: %{
          one: "{0} #{name}",
          other: "{0} #{plural}",
          display_name: plural
        }
      }
    }
  end

  defp naive_plural(name) do
    cond do
      String.ends_with?(name, "s") -> name
      String.ends_with?(name, "ch") -> name <> "es"
      String.ends_with?(name, "sh") -> name <> "es"
      String.ends_with?(name, "x") -> name <> "es"
      String.ends_with?(name, "y") -> String.trim_trailing(name, "y") <> "ies"
      true -> name <> "s"
    end
  end
end
