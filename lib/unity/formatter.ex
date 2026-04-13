defmodule Unity.Formatter do
  @moduledoc """
  Formats evaluation results for display in terse, verbose, or
  locale-aware modes.

  The formatter delegates to `Localize.Unit.to_string/2` for unit
  formatting and `Localize.Number.to_string/2` for bare numbers.

  """

  @type format :: :default | :verbose | :terse
  @type options :: [
          format: format(),
          locale: atom() | String.t(),
          input: String.t(),
          digits: pos_integer(),
          exponential: boolean(),
          output_format: String.t(),
          show_reciprocal: boolean()
        ]

  @default_max_fractional_digits 6

  @doc """
  Formats a result value for display.

  ### Arguments

  * `result` - a `Localize.Unit.t()` or a number.

  * `options` - keyword list of formatting options.

  ### Options

  * `:format` - output format. `:default` shows the value and unit name,
    `:verbose` shows `from = to` format, `:terse` shows only the numeric
    value. Defaults to `:default`.

  * `:locale` - locale for number and unit formatting. Defaults to the
    current process locale.

  * `:input` - the original input string, used in verbose mode.

  * `:digits` - maximum number of fractional digits to display.
    Defaults to 6.

  * `:exponential` - if `true`, format numbers in scientific notation.
    Defaults to `false`.

  * `:output_format` - a printf-style format string (e.g., `"%.8g"`).
    When set, overrides `:digits` and `:exponential`.

  * `:show_reciprocal` - if `true`, append a reciprocal conversion line
    (e.g., `/ 0.3048`). Defaults to `true` in `:default` format for
    conversions. Set to `false` with `--strict` or `--one-line`.

  ### Returns

  * `{:ok, formatted_string}` on success.

  * `{:error, reason}` on failure.

  ### Examples

      iex> {:ok, unit} = Localize.Unit.new(9.84252, "foot")
      iex> Unity.Formatter.format(unit)
      {:ok, "9.84252 feet"}

  """
  @spec format(Localize.Unit.t() | number(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def format(result, options \\ [])

  def format({:decomposed, parts}, options) when is_list(parts) do
    locale_options = build_locale_options(options)

    results =
      Enum.reduce_while(parts, {:ok, []}, fn unit, {:ok, acc} ->
        case Localize.Unit.to_string(unit, locale_options) do
          {:ok, str} -> {:cont, {:ok, [str | acc]}}
          {:error, exception} -> {:halt, {:error, Exception.message(exception)}}
        end
      end)

    case results do
      {:ok, strings} -> {:ok, Enum.reverse(strings) |> Enum.join(", ")}
      {:error, _} = error -> error
    end
  end

  def format(%Localize.Unit{} = unit, options) do
    format_mode = Keyword.get(options, :format, :default)
    input = Keyword.get(options, :input)
    locale_options = build_locale_options(options)

    result =
      case format_mode do
        :terse ->
          format_terse(unit, options)

        :verbose ->
          format_verbose(unit, input, locale_options)

        :default ->
          format_default(unit, locale_options)
      end

    with {:ok, main_line} <- result do
      if Keyword.get(options, :show_reciprocal, false) and unit.value != nil and unit.value != 0 do
        reciprocal = 1.0 / unit.value
        {:ok, reciprocal_str} = format_raw_number(reciprocal, options)
        {:ok, main_line <> "\n\t/ #{reciprocal_str}"}
      else
        {:ok, main_line}
      end
    end
  end

  def format(number, options) when is_number(number) do
    format_raw_number(number, options)
  end

  def format(%DateTime{} = dt, _options) do
    {:ok, DateTime.to_iso8601(dt)}
  end

  def format(%Date{} = date, _options) do
    {:ok, Date.to_iso8601(date)}
  end

  def format(true, _options), do: {:ok, "true"}
  def format(false, _options), do: {:ok, "false"}

  def format(result, _options) when is_binary(result) do
    {:ok, result}
  end

  def format(result, _options) do
    {:ok, inspect(result)}
  end

  @doc """
  Formats a result value for display, raising on failure.

  """
  @spec format!(Localize.Unit.t() | number(), keyword()) :: String.t()
  def format!(result, options \\ []) do
    case format(result, options) do
      {:ok, string} -> string
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  # ── Private ──

  defp build_locale_options(options) do
    digits = Keyword.get(options, :digits, @default_max_fractional_digits)
    opts = [max_fractional_digits: digits]
    opts = if locale = Keyword.get(options, :locale), do: [{:locale, locale} | opts], else: opts
    opts
  end

  defp format_default(unit, locale_options) do
    case Localize.Unit.to_string(unit, locale_options) do
      {:ok, string} -> {:ok, string}
      {:error, exception} -> {:error, Exception.message(exception)}
    end
  end

  defp format_terse(%Localize.Unit{value: value}, options) do
    format_raw_number(value, options)
  end

  defp format_verbose(unit, input, locale_options) do
    case Localize.Unit.to_string(unit, locale_options) do
      {:ok, string} ->
        prefix = if input, do: "#{input} = ", else: ""
        {:ok, prefix <> string}

      {:error, exception} ->
        {:error, Exception.message(exception)}
    end
  end

  # Formats a raw number, respecting :output_format, :exponential, and :digits.
  #
  # Uses Localize.Number.to_string for all standard formatting. The only
  # exception is --output-format which accepts an Erlang :io_lib.format
  # string as a power-user escape hatch for exact numeric control.
  defp format_raw_number(number, options) when is_number(number) do
    cond do
      output_format = Keyword.get(options, :output_format) ->
        erlang_fmt = printf_to_erlang(output_format)
        formatted = :io_lib.format(erlang_fmt, [number / 1])
        {:ok, IO.chardata_to_string(formatted)}

      Keyword.get(options, :exponential, false) ->
        locale_options = build_locale_options(options) ++ [format: :scientific]

        case Localize.Number.to_string(number, locale_options) do
          {:ok, string} -> {:ok, string}
          {:error, exception} -> {:error, Exception.message(exception)}
        end

      true ->
        locale_options = build_locale_options(options)

        case Localize.Number.to_string(number, locale_options) do
          {:ok, string} -> {:ok, string}
          {:error, exception} -> {:error, Exception.message(exception)}
        end
    end
  end

  defp format_raw_number(number, _options) do
    {:ok, to_string(number)}
  end

  # Converts a printf-style format string (e.g., "%.8g") to an Erlang
  # :io_lib.format string (e.g., ~c"~.8g"). Only used by --output-format.
  defp printf_to_erlang(format) do
    format
    |> String.replace("%", "~")
    |> String.to_charlist()
  end
end
