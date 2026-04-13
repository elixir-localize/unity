defmodule Unity.Repl do
  @moduledoc """
  Interactive REPL (Read-Eval-Print Loop) for the units calculator.

  Supports expression evaluation, variable bindings with `let`, chained
  conversions with `_` (previous result), and special commands like
  `help`, `list`, `search`, `conformable`, `info`, `locale`, and `quit`.

  """

  @version Mix.Project.config()[:version]
  @history_file "~/.units_history"

  @doc """
  Starts the interactive REPL.

  ### Options

  * `:quiet` - if `true`, suppresses the welcome banner. Defaults to `false`.

  * `:locale` - initial locale for formatting. Defaults to the current
    process locale.

  * `:history_file` - path to a file for persisting command history.
    Defaults to `"~/.units_history"`. Set to `nil` to disable.

  """
  @spec start(keyword()) :: :ok
  def start(options \\ []) do
    quiet = Keyword.get(options, :quiet, false)

    if locale = Keyword.get(options, :locale) do
      Localize.put_locale(locale)
    end

    history_path = resolve_history_path(Keyword.get(options, :history_file, @history_file))
    load_history(history_path)

    unless quiet do
      IO.puts("Unity v#{@version} — type \"help\" for commands, \"quit\" to exit\n")
    end

    loop(%{}, history_path)
  end

  defp loop(environment, history_path) do
    case IO.gets("> ") do
      :eof ->
        IO.puts("")
        save_history(history_path)
        :ok

      {:error, _reason} ->
        save_history(history_path)
        :ok

      input ->
        input = String.trim(input)

        case handle_input(input, environment) do
          {:continue, environment} ->
            loop(environment, history_path)

          :quit ->
            save_history(history_path)
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

  defp handle_input("search " <> query, environment) do
    search_units(String.trim(query))
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
        IO.puts(Unity.Error.format(Exception.message(exception)))
    end

    {:continue, environment}
  end

  # Dialyzer's success typing cannot trace {:decomposed, _} through the
  # eval chain, but it is a valid runtime return from mixed-unit conversions.
  @dialyzer {:nowarn_function, handle_input: 2}
  defp handle_input(input, environment) do
    case Unity.eval(input, environment) do
      {:ok, result, environment} ->
        case Unity.Formatter.format(result) do
          {:ok, formatted} ->
            IO.puts(formatted)

          {:error, reason} ->
            IO.puts(Unity.Error.format(reason))
        end

        # Store the result as "_" so it can be referenced in subsequent expressions.
        # For decomposed results, store the first (largest) component.
        result_for_env =
          case result do
            {:decomposed, [first | _]} -> first
            other -> other
          end

        environment = Map.put(environment, "_", result_for_env)
        {:continue, environment}

      {:error, message} ->
        IO.puts(Unity.Error.format(message))
        {:continue, environment}
    end
  end

  # ── Search ──

  defp search_units(query) do
    query_down = String.downcase(query)

    # Search through aliases
    alias_matches =
      Unity.Aliases.known_aliases()
      |> Enum.filter(&String.contains?(String.downcase(&1), query_down))

    # Search through CLDR unit names
    cldr_matches =
      Unity.Aliases.all_known_names()
      |> Enum.filter(&String.contains?(&1, query_down))

    # Combine, resolve to CLDR names, deduplicate
    all_matches =
      (alias_matches ++ cldr_matches)
      |> Enum.map(fn name ->
        case Unity.Aliases.resolve(name) do
          {:ok, cldr} -> {name, cldr}
          _ -> {name, name}
        end
      end)
      |> Enum.uniq_by(fn {_name, cldr} -> cldr end)
      |> Enum.sort_by(fn {name, _cldr} -> name end)

    case all_matches do
      [] ->
        IO.puts("No units matching #{inspect(query)}")

      matches ->
        lines =
          Enum.map(matches, fn
            {name, cldr} when name == cldr -> name
            {name, cldr} -> "#{name} (#{cldr})"
          end)

        IO.puts(Enum.join(lines, ", "))
    end
  end

  # ── History ──

  defp resolve_history_path(nil), do: nil

  defp resolve_history_path(path) do
    path
    |> String.replace_leading("~", System.user_home!())
    |> Path.expand()
  end

  defp load_history(nil), do: :ok

  defp load_history(path) do
    if group_history_available?() do
      case File.read(path) do
        {:ok, content} ->
          content
          |> String.split("\n", trim: true)
          |> Enum.each(fn line ->
            apply(:group_history, :add, [String.to_charlist(line)])
          end)

        {:error, _} ->
          :ok
      end
    end
  end

  defp save_history(nil), do: :ok

  defp save_history(path) do
    if group_history_available?() do
      case apply(:group_history, :get, []) do
        lines when is_list(lines) ->
          history =
            lines
            |> Enum.reverse()
            |> Enum.take(-500)
            |> Enum.map_join("\n", &List.to_string/1)

          if history != "" do
            File.write(path, history <> "\n")
          end

        _ ->
          :ok
      end
    end
  end

  defp group_history_available? do
    Code.ensure_loaded?(:group_history) and function_exported?(:group_history, :get, 0)
  end

  # ── Help ──

  defp print_help do
    IO.puts("""
    Expression syntax:
      3 meters to feet       Convert between units
      60 mph + 10 km/h       Add compatible units
      100 kg * 9.8 m/s^2    Multiply units (also: **)
      sqrt(9 m^2)            Functions: sqrt, cbrt, abs, round, ceil, floor
      1|3 cup                Rational numbers
      let x = 42 km          Variable binding
      _                      Previous result
      _ to feet              Convert previous result

    Commands:
      help                   Show this help
      list [category]        List known units
      search <text>          Search unit names containing <text>
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
        IO.puts(Unity.Error.format("unknown category: #{inspect(category)}"))

      units ->
        IO.puts("#{category}: #{Enum.sort(units) |> Enum.join(", ")}")
    end
  end

  defp list_conformable(name) do
    case Unity.Aliases.resolve(name) do
      {:ok, cldr_name} ->
        case Localize.Unit.unit_category(cldr_name) do
          {:ok, category} ->
            by_category = Localize.Unit.known_units_by_category()
            units = Map.get(by_category, category, [])
            IO.puts(Enum.sort(units) |> Enum.join(", "))

          {:error, exception} ->
            IO.puts(Unity.Error.format(Exception.message(exception)))
        end

      {:error, :unknown_unit} ->
        suggestions = Unity.Aliases.suggest(name)

        message =
          case suggestions do
            [] ->
              "unknown unit: #{inspect(name)}"

            _ ->
              "unknown unit: #{inspect(name)}\n  Did you mean: #{Enum.map_join(suggestions, ", ", &elem(&1, 0))}?"
          end

        IO.puts(Unity.Error.format(message))
    end
  end

  defp show_unit_info(name) do
    case Unity.Aliases.resolve(name) do
      {:ok, cldr_name} ->
        case Localize.Unit.unit_category(cldr_name) do
          {:ok, category} ->
            IO.puts("#{cldr_name} (#{category})")

            # Show aliases that map to this unit
            aliases =
              Unity.Aliases.known_aliases()
              |> Enum.filter(fn alias_name ->
                case Unity.Aliases.resolve(alias_name) do
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
            IO.puts(Unity.Error.format(Exception.message(exception)))
        end

      {:error, :unknown_unit} ->
        IO.puts(Unity.Error.format("unknown unit: #{inspect(name)}"))
    end
  end
end
