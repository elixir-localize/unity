defmodule Unity.GnuUnitsImporter do
  @moduledoc """
  Imports unit definitions from a GNU `units` definition file into
  the Localize custom unit registry.

  Supports simple linear conversions, fractional definitions, compound
  expressions, and aliases. Function definitions (nonlinear conversions),
  conditional blocks, and directives are skipped.

  ## Usage

      # Import from the system default location
      {:ok, stats} = Unity.GnuUnitsImporter.import()

      # Import from a specific file
      {:ok, stats} = Unity.GnuUnitsImporter.import("/path/to/definitions.units")

      # Export to a .exs file for use with Localize.Unit.load_custom_units/1
      {:ok, count} = Unity.GnuUnitsImporter.export("priv/gnu_units.exs")

      # Parse without registering (for inspection)
      {:ok, parsed} = Unity.GnuUnitsImporter.parse("/path/to/definitions.units")

  """

  alias Unity.GnuUnitsImporter.{Parser, Resolver, Registrar}

  @bundled_path Application.app_dir(:unity, "priv/definitions.units")

  @system_paths [
    "/opt/homebrew/share/units/definitions.units",
    "/usr/share/units/definitions.units",
    "/usr/local/share/units/definitions.units"
  ]

  @doc """
  Imports GNU unit definitions and registers them via `Localize.Unit.define_unit/2`.

  ### Arguments

  * `path` — path to the definitions file. If omitted, uses the
    bundled file shipped with this library.

  ### Returns

  * `{:ok, stats}` where stats is a map with `:imported`, `:skipped`, and
    `:errors` keys.

  * `{:error, reason}` if the file cannot be found or parsed.

  """
  @spec import(String.t() | nil) :: {:ok, map()} | {:error, String.t()}
  def import(path \\ nil) do
    with {:ok, file_path} <- find_file(path),
         {:ok, parsed} <- Parser.parse_file(file_path),
         {:ok, resolved} <- Resolver.resolve_all(parsed) do
      stats = Registrar.register_all(resolved)
      {:ok, stats}
    end
  end

  @doc """
  Exports resolved GNU unit definitions to an `.exs` file compatible
  with `Localize.Unit.load_custom_units/1`.

  This allows generating the definitions once, inspecting or editing
  the output, and loading it at application startup without re-parsing
  the GNU file.

  ### Arguments

  * `output_path` — path for the output `.exs` file.

  * `input_path` — path to the GNU definitions file. If omitted,
    uses the bundled file shipped with this library.

  ### Returns

  * `{:ok, count}` with the number of definitions exported.

  * `{:error, reason}` on failure.

  """
  @spec export(String.t(), String.t() | nil) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def export(output_path, input_path \\ nil) do
    with {:ok, file_path} <- find_file(input_path),
         {:ok, parsed} <- Parser.parse_file(file_path),
         {:ok, resolved} <- Resolver.resolve_all(parsed) do
      definitions = Registrar.to_definition_list(resolved)
      content = inspect(definitions, limit: :infinity, pretty: true, width: 100)
      File.write!(Path.expand(output_path), content <> "\n")
      {:ok, length(definitions)}
    end
  end

  @doc """
  Parses a GNU units definition file without registering or exporting.

  Useful for inspecting the parsed and resolved data.

  ### Arguments

  * `path` — path to the definitions file. If omitted, uses the
    bundled file shipped with this library.

  ### Returns

  * `{:ok, %{parsed: parsed, resolved: resolved}}` with the raw data.

  * `{:error, reason}` on failure.

  """
  @spec parse(String.t() | nil) :: {:ok, map()} | {:error, String.t()}
  def parse(path \\ nil) do
    with {:ok, file_path} <- find_file(path),
         {:ok, parsed} <- Parser.parse_file(file_path),
         {:ok, resolved} <- Resolver.resolve_all(parsed) do
      {:ok, %{parsed: parsed, resolved: resolved}}
    end
  end

  defp find_file(nil) do
    # Prefer the bundled file shipped with this library.
    # Fall back to system-installed GNU units if the bundled file is missing.
    all_paths = [@bundled_path | @system_paths]

    case Enum.find(all_paths, &File.exists?/1) do
      nil ->
        {:error, "GNU units definition file not found. Searched: #{Enum.join(all_paths, ", ")}"}

      path ->
        {:ok, path}
    end
  end

  defp find_file(path) do
    expanded = Path.expand(path)

    if File.exists?(expanded) do
      {:ok, expanded}
    else
      {:error, "file not found: #{expanded}"}
    end
  end
end
