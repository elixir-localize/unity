defmodule Units.Repl do
  @moduledoc """
  Interactive REPL (Read-Eval-Print Loop) for the units calculator.

  Supports expression evaluation, variable bindings with `let`, chained
  conversions with `_` (previous result), and special commands like
  `help`, `list`, `conformable`, `info`, `locale`, and `quit`.

  """

  @version Mix.Project.config()[:version]

  @doc """
  Starts the interactive REPL.

  ### Options

  * `:quiet` - if `true`, suppresses the welcome banner. Defaults to `false`.

  * `:locale` - initial locale for formatting. Defaults to the current
    process locale.

  """
  @spec start(keyword()) :: :ok
  def start(options \\ []) do
    quiet = Keyword.get(options, :quiet, false)

    if locale = Keyword.get(options, :locale) do
      Localize.put_locale(locale)
    end

    unless quiet do
      IO.puts("Units v#{@version} — type \"help\" for commands, \"quit\" to exit\n")
    end

    loop(%{})
  end

  defp loop(environment) do
    case IO.gets("> ") do
      :eof ->
        IO.puts("")
        :ok

      {:error, _reason} ->
        :ok

      input ->
        input = String.trim(input)

        case handle_input(input, environment) do
          {:continue, environment} ->
            loop(environment)

          :quit ->
            :ok
        end
    end
  end

  defp handle_input("", environment) do
    {:continue, environment}
  end

  defp handle_input(input, _environment) when input in ["quit", "exit", "q"] do
    :quit
  end

  defp handle_input("help", environment) do
    print_help()
    {:continue, environment}
  end

  defp handle_input("list" <> rest, environment) do
    category = String.trim(rest)
    list_units(category)
    {:continue, environment}
  end

  defp handle_input("conformable " <> unit_name, environment) do
    list_conformable(String.trim(unit_name))
    {:continue, environment}
  end

  defp handle_input("info " <> unit_name, environment) do
    show_unit_info(String.trim(unit_name))
    {:continue, environment}
  end

  defp handle_input("locale " <> locale_id, environment) do
    locale_id = String.trim(locale_id)

    case Localize.put_locale(locale_id) do
      {:ok, _} ->
        IO.puts("Locale set to :#{locale_id}")

      {:error, exception} ->
        IO.puts(Units.Error.format(Exception.message(exception)))
    end

    {:continue, environment}
  end

  defp handle_input(input, environment) do
    case Units.eval(input, environment) do
      {:ok, result, environment} ->
        case Units.Formatter.format(result) do
          {:ok, formatted} ->
            IO.puts(formatted)

          {:error, reason} ->
            IO.puts(Units.Error.format(reason))
        end

        # Store the result as "_" so it can be referenced in subsequent expressions
        result_for_env = unwrap_decomposed(result)
        environment = Map.put(environment, "_", result_for_env)
        {:continue, environment}

      {:error, message} ->
        IO.puts(Units.Error.format(message))
        {:continue, environment}

      {:error, message, _partial} ->
        IO.puts(Units.Error.format(message))
        {:continue, environment}
    end
  end

  # When storing a decomposed result as _, use the first component
  # (the largest unit) so it can be meaningfully reused.
  defp unwrap_decomposed({:decomposed, [first | _]}), do: first
  defp unwrap_decomposed(result), do: result

  defp print_help do
    IO.puts("""
    Expression syntax:
      3 meters to feet       Convert between units
      60 mph + 10 km/h       Add compatible units
      100 kg * 9.8 m/s^2    Multiply units
      sqrt(9 m^2)            Functions: sqrt, cbrt, abs, round, ceil, floor
      1|3 cup                Rational numbers
      let x = 42 km          Variable binding
      _                      Previous result
      _ to feet              Convert previous result

    Commands:
      help                   Show this help
      list [category]        List known units
      conformable <unit>     List units convertible with <unit>
      info <unit>            Show unit information
      locale <id>            Change display locale (e.g., locale de)
      quit / exit            Exit the REPL
    """)
  end

  defp list_units("") do
    categories = Localize.Unit.known_categories() |> Enum.sort()
    IO.puts("Unit categories: #{Enum.join(categories, ", ")}")
    IO.puts("Use \"list <category>\" to see units in a category.")
  end

  defp list_units(category) do
    by_category = Localize.Unit.known_units_by_category()

    case Map.get(by_category, category) do
      nil ->
        IO.puts(Units.Error.format("unknown category: #{inspect(category)}"))

      units ->
        IO.puts("#{category}: #{Enum.sort(units) |> Enum.join(", ")}")
    end
  end

  defp list_conformable(name) do
    case Units.Aliases.resolve(name) do
      {:ok, cldr_name} ->
        case Localize.Unit.unit_category(cldr_name) do
          {:ok, category} ->
            by_category = Localize.Unit.known_units_by_category()
            units = Map.get(by_category, category, [])
            IO.puts(Enum.sort(units) |> Enum.join(", "))

          {:error, exception} ->
            IO.puts(Units.Error.format(Exception.message(exception)))
        end

      {:error, :unknown_unit} ->
        suggestions = Units.Aliases.suggest(name)

        message =
          case suggestions do
            [] ->
              "unknown unit: #{inspect(name)}"

            _ ->
              "unknown unit: #{inspect(name)}\n  Did you mean: #{Enum.map_join(suggestions, ", ", &elem(&1, 0))}?"
          end

        IO.puts(Units.Error.format(message))
    end
  end

  defp show_unit_info(name) do
    case Units.Aliases.resolve(name) do
      {:ok, cldr_name} ->
        case Localize.Unit.unit_category(cldr_name) do
          {:ok, category} ->
            IO.puts("#{cldr_name} (#{category})")

            # Show aliases that map to this unit
            aliases =
              Units.Aliases.known_aliases()
              |> Enum.filter(fn alias_name ->
                case Units.Aliases.resolve(alias_name) do
                  {:ok, ^cldr_name} -> true
                  _ -> false
                end
              end)
              |> Enum.sort()

            if aliases != [] do
              IO.puts("  Aliases: #{Enum.join(aliases, ", ")}")
            end

            # Show conformable units
            by_category = Localize.Unit.known_units_by_category()
            conformable = Map.get(by_category, category, []) -- [cldr_name]

            if conformable != [] do
              display = conformable |> Enum.sort() |> Enum.take(10)
              suffix = if length(conformable) > 10, do: ", ...", else: ""
              IO.puts("  Conformable: #{Enum.join(display, ", ")}#{suffix}")
            end

          {:error, exception} ->
            IO.puts(Units.Error.format(Exception.message(exception)))
        end

      {:error, :unknown_unit} ->
        IO.puts(Units.Error.format("unknown unit: #{inspect(name)}"))
    end
  end
end
