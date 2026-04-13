defmodule Unity.Repl do
  @moduledoc """
  Interactive REPL (Read-Eval-Print Loop) for the units calculator.

  Supports expression evaluation, variable bindings with `let`, chained
  conversions with `_` (previous result), and special commands like
  `help`, `list`, `search`, `conformable`, `info`, `locale`, and `quit`.

  """

  @version Mix.Project.config()[:version]
  @shell_history_dir "~/.unity_history"

  @doc """
  Starts the interactive REPL.

  ### Options

  * `:quiet` - if `true`, suppresses the welcome banner. Defaults to `false`.

  * `:locale` - initial locale for formatting. Defaults to the current
    process locale.

  * `:history_file` - path to a directory for persisting command history
    across sessions. Defaults to `"~/.unity_history"`. Set to `nil` to
    disable. Only used when the REPL bootstraps its own terminal (i.e.
    not running under IEx).

  """
  @spec start(keyword()) :: :ok
  def start(options \\ []) do
    if needs_terminal_bootstrap?() do
      start_with_terminal(options)
    else
      run_repl(options)
    end
  end

  defp start_with_terminal(options) do
    configure_shell_history(options)

    parent = self()
    ref = make_ref()

    :shell.start_interactive({__MODULE__, :__run_interactive__, [options, parent, ref]})

    receive do
      {^ref, :done} -> :ok
    end
  end

  # Configures the Erlang shell's built-in history to use a Unity-specific
  # directory so REPL history is persisted across sessions and kept separate
  # from the standard Erlang/IEx shell history.
  defp configure_shell_history(options) do
    history_dir =
      case Keyword.get(options, :history_file, @shell_history_dir) do
        nil -> nil
        path -> resolve_history_path(path)
      end

    if history_dir do
      File.mkdir_p(history_dir)
      Application.put_env(:kernel, :shell_history, :enabled)
      Application.put_env(:kernel, :shell_history_path, String.to_charlist(history_dir))
    else
      Application.put_env(:kernel, :shell_history, :disabled)
    end
  end

  @doc false
  @spec __run_interactive__(keyword(), pid(), reference()) :: :ok
  def __run_interactive__(options, parent, ref) do
    configure_tab_completion()
    run_repl(options)
    send(parent, {ref, :done})
    :ok
  end

  defp configure_tab_completion do
    :io.setopts(:standard_io, expand_fun: &Unity.Repl.Completion.expand/1)
  end

  defp run_repl(options) do
    quiet = Keyword.get(options, :quiet, false)

    if locale = Keyword.get(options, :locale) do
      Localize.put_locale(locale)
    end

    unless quiet do
      IO.puts("Unity v#{@version} — type \"help\" for commands, \"quit\" to exit\n")
    end

    loop(%{})
  end

  # Returns true when we have a real terminal but no interactive shell (iex)
  # providing line editing. In that case we need to bootstrap the Erlang
  # terminal driver via shell:start_interactive/1.
  defp needs_terminal_bootstrap? do
    not iex_running?() and tty?()
  end

  defp iex_running? do
    Code.ensure_loaded?(IEx) and function_exported?(IEx, :started?, 0) and
      apply(IEx, :started?, [])
  end

  defp tty? do
    case :io.getopts(:standard_io) do
      options when is_list(options) -> Keyword.get(options, :echo, false) != false
      _ -> false
    end
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

  defp handle_input("bindings", environment) do
    show_bindings(environment)
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

  defp resolve_history_path(path) do
    path
    |> String.replace_leading("~", System.user_home!())
    |> Path.expand()
  end

  # ── Bindings ──

  defp show_bindings(environment) when map_size(environment) == 0 do
    IO.puts("No bindings set.")
  end

  defp show_bindings(environment) do
    environment
    |> Enum.sort_by(fn {name, _} -> name end)
    |> Enum.each(fn {name, value} ->
      formatted =
        case Unity.Formatter.format(value) do
          {:ok, str} -> str
          {:error, _} -> inspect(value)
        end

      IO.puts("  #{name} = #{formatted}")
    end)
  end

  # ── Help ──

  defp print_help do
    IO.puts("""
    Expression syntax:
      3 meters to feet       Convert between units
      60 mph + 10 km/h       Add compatible units
      100 kg * 9.8 m/s^2    Multiply units (also: **)
      1|3 cup                Rational numbers
      0xFF, 0o77, 0b1010     Hex, octal, binary literals
      1_000_000              Underscore digit separators
      let x = 42 km          Variable binding
      _                      Previous result
      _ to feet              Convert previous result

    Functions:
      sqrt, cbrt, abs, round, ceil, floor
      sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, asinh, acosh, atanh
      ln, log, log2, exp, factorial, gamma
      atan2, hypot, gcd, lcm, min, max, mod
      now(), today(), datetime("..."), unixtime(n), timestamp(dt)
      unit_of(expr), value_of(expr), is_dimensionless(expr)
      increase_by(val, pct), decrease_by(val, pct), percentage_change(a, b)
      assert_eq(a, b), assert_eq(a, b, tolerance)

    Commands:
      help                   Show this help
      bindings               Show current variable bindings
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
