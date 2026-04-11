defmodule Units.Formatter do
  @moduledoc """
  Formats evaluation results for display in terse, verbose, or
  locale-aware modes.

  The formatter delegates to `Localize.Unit.to_string/2` for unit
  formatting and `Localize.Number.to_string/2` for bare numbers.

  """

  @type format :: :default | :verbose | :terse
  @type options :: [format: format(), locale: atom() | String.t()]

  @max_fractional_digits 6

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

  ### Returns

  * `{:ok, formatted_string}` on success.

  * `{:error, reason}` on failure.

  ### Examples

      iex> {:ok, unit} = Localize.Unit.new(9.84252, "foot")
      iex> Units.Formatter.format(unit)
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

    case format_mode do
      :terse ->
        format_terse(unit, locale_options)

      :verbose ->
        format_verbose(unit, input, locale_options)

      :default ->
        format_default(unit, locale_options)
    end
  end

  def format(number, options) when is_number(number) do
    locale_options = build_locale_options(options)
    format_number(number, locale_options)
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
    opts = []
    opts = if locale = Keyword.get(options, :locale), do: [{:locale, locale} | opts], else: opts
    [{:max_fractional_digits, @max_fractional_digits} | opts]
  end

  defp format_default(unit, locale_options) do
    case Localize.Unit.to_string(unit, locale_options) do
      {:ok, string} -> {:ok, string}
      {:error, exception} -> {:error, Exception.message(exception)}
    end
  end

  defp format_terse(%Localize.Unit{value: value}, locale_options) do
    format_number(value, locale_options)
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

  defp format_number(number, locale_options) when is_number(number) do
    case Localize.Number.to_string(number, locale_options) do
      {:ok, string} -> {:ok, string}
      {:error, exception} -> {:error, Exception.message(exception)}
    end
  end

  defp format_number(number, _locale_options) do
    {:ok, to_string(number)}
  end
end
