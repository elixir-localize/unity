defmodule Units.CLI do
  @moduledoc """
  Command-line entry point for the units calculator.

  Supports both interactive (REPL) mode and single-expression evaluation.
  Can be built as an escript via `mix escript.build`.

  ## Usage

      # Interactive mode
      units

      # Single expression
      units "3 meters to feet"

      # Two-argument conversion (GNU units style)
      units "3 meters" "feet"

      # With options
      units -v "1 gallon" "liters"
      units -t "100 celsius" "fahrenheit"
      units --locale de "1234.5 meter to kilometer"

  """

  @version Mix.Project.config()[:version]

  @doc """
  Main entry point for escript execution.

  """
  @spec main([String.t()]) :: :ok
  def main(args) do
    {options, positional, _invalid} =
      OptionParser.parse(args,
        aliases: [
          v: :verbose,
          t: :terse,
          q: :quiet,
          h: :help,
          d: :digits,
          e: :exponential,
          o: :output_format,
          s: :strict
        ],
        switches: [
          verbose: :boolean,
          terse: :boolean,
          quiet: :boolean,
          strict: :boolean,
          exponential: :boolean,
          one_line: :boolean,
          locale: :string,
          digits: :integer,
          output_format: :string,
          conformable: :string,
          list: :string,
          version: :boolean,
          help: :boolean
        ]
      )

    cond do
      options[:version] ->
        IO.puts("Units v#{@version}")

      options[:help] ->
        print_usage()

      options[:conformable] ->
        show_conformable(options[:conformable])

      Keyword.has_key?(options, :list) ->
        show_list(options[:list] || "")

      positional != [] ->
        run_expression(positional, options)

      not io_tty?() ->
        run_stdin(options)

      true ->
        repl_options = build_repl_options(options)
        Units.Repl.start(repl_options)
    end
  end

  defp run_stdin(options) do
    if locale = options[:locale] do
      Localize.put_locale(locale)
    end

    format_options = build_format_options(options, nil)

    IO.stream(:stdio, :line)
    |> Enum.each(fn line ->
      expression = String.trim(line)

      if expression != "" do
        expr_options = Keyword.put(format_options, :input, expression)

        case Units.eval(expression) do
          {:ok, result, _env} ->
            case Units.Formatter.format(result, expr_options) do
              {:ok, formatted} -> IO.puts(formatted)
              {:error, reason} -> IO.puts(:stderr, Units.Error.format(reason))
            end

          {:error, message} ->
            IO.puts(:stderr, Units.Error.format(message))
        end
      end
    end)
  end

  defp io_tty? do
    case :io.getopts(:standard_io) do
      opts when is_list(opts) -> Keyword.get(opts, :echo, false) != false
      _ -> false
    end
  end

  defp run_expression(positional, options) do
    if locale = options[:locale] do
      Localize.put_locale(locale)
    end

    expression =
      case positional do
        # "units - feet" reads from stdin for the source
        ["-", target] ->
          source = IO.read(:stdio, :eof) |> String.trim()
          "#{source} to #{target}"

        [expr] ->
          expr

        [from, to] ->
          "#{from} to #{to}"

        _ ->
          Enum.join(positional, " ")
      end

    format_options = build_format_options(options, expression)

    case Units.eval(expression) do
      {:ok, result, _env} ->
        case Units.Formatter.format(result, format_options) do
          {:ok, formatted} -> IO.puts(formatted)
          {:error, reason} -> error_exit(reason)
        end

      {:error, message} ->
        error_exit(message)
    end
  end

  defp build_format_options(options, input) do
    format = format_from_options(options)
    opts = [format: format]
    opts = if input, do: [{:input, input} | opts], else: opts
    opts = if options[:locale], do: [{:locale, options[:locale]} | opts], else: opts
    opts = if options[:digits], do: [{:digits, options[:digits]} | opts], else: opts
    opts = if options[:exponential], do: [{:exponential, true} | opts], else: opts

    opts =
      if options[:output_format],
        do: [{:output_format, options[:output_format]} | opts],
        else: opts

    # Reciprocal line: shown by default for :default format, suppressed by --strict or --one-line
    show_reciprocal = format == :default and not options[:strict] and not options[:one_line]
    [{:show_reciprocal, show_reciprocal} | opts]
  end

  defp show_conformable(unit_name) do
    case Units.Aliases.resolve(unit_name) do
      {:ok, cldr_name} ->
        case Localize.Unit.unit_category(cldr_name) do
          {:ok, category} ->
            by_category = Localize.Unit.known_units_by_category()
            units = Map.get(by_category, category, [])
            IO.puts(Enum.sort(units) |> Enum.join(", "))

          {:error, exception} ->
            error_exit(Exception.message(exception))
        end

      {:error, :unknown_unit} ->
        error_exit("unknown unit: #{inspect(unit_name)}")
    end
  end

  defp show_list("") do
    categories = Localize.Unit.known_categories() |> Enum.sort()
    IO.puts(Enum.join(categories, ", "))
  end

  defp show_list(category) do
    by_category = Localize.Unit.known_units_by_category()

    case Map.get(by_category, category) do
      nil -> error_exit("unknown category: #{inspect(category)}")
      units -> IO.puts(Enum.sort(units) |> Enum.join(", "))
    end
  end

  defp format_from_options(options) do
    cond do
      options[:verbose] -> :verbose
      options[:terse] -> :terse
      true -> :default
    end
  end

  defp build_repl_options(options) do
    repl_options = []
    repl_options = if options[:quiet], do: [{:quiet, true} | repl_options], else: repl_options

    repl_options =
      if options[:locale], do: [{:locale, options[:locale]} | repl_options], else: repl_options

    repl_options
  end

  @spec error_exit(String.t()) :: no_return()
  defp error_exit(message) do
    IO.puts(:stderr, Units.Error.format(message))
    System.halt(1)
  end

  defp print_usage do
    IO.puts("""
    Usage: units [options] [expression] [target]

    Options:
      -v, --verbose          Show "from = to" format
      -t, --terse            Bare numeric result only
      -q, --quiet            Suppress REPL prompts
      -s, --strict           Suppress reciprocal conversions
      -1, --one-line         Forward conversion only (no reciprocal)
      -d, --digits <n>       Maximum fractional digits (default: 6)
      -e, --exponential      Scientific notation output
      -o, --output-format <fmt>  Printf-style format (e.g., "%.8g")
      --locale <id>          Set formatting locale
      --conformable <unit>   List conformable units
      --list [category]      List known units or categories
      --version              Print version
      -h, --help             Print this help

    Examples:
      units                          Start interactive mode
      units "3 meters to feet"       Single conversion
      units "3 meters" "feet"        Two-argument conversion
      units -v "1 gallon" "liters"   Verbose output
      units -t "100 celsius" "fahrenheit"   Numeric only
      units -d 10 "3 meters" "feet"  High precision
      units -e "1 light-year" "km"   Scientific notation
    """)
  end
end
