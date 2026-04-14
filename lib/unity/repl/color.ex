defmodule Unity.Repl.Color do
  @moduledoc false

  # ANSI coloring for REPL output.
  #
  # Coloring is automatically disabled when:
  #   * stdout is not a terminal (piped/redirected output)
  #   * the NO_COLOR environment variable is set (https://no-color.org/)
  #   * the application env :unity, :no_color is true

  @reset "\e[0m"
  @bold "\e[1m"
  @dim "\e[2m"
  @italic "\e[3m"

  # Foreground colors (8-bit safe)
  @red "\e[31m"
  @green "\e[32m"
  @yellow "\e[33m"
  @blue "\e[34m"
  @magenta "\e[35m"
  @cyan "\e[36m"
  @bright_cyan "\e[96m"
  @bright_yellow "\e[93m"

  @doc "Returns true if ANSI coloring should be used for output."
  @spec enabled?() :: boolean()
  def enabled? do
    not Application.get_env(:unity, :no_color, false) and
      System.get_env("NO_COLOR") in [nil, ""] and
      tty?()
  end

  defp tty? do
    case :io.getopts(:standard_io) do
      options when is_list(options) -> Keyword.get(options, :echo, false) != false
      _ -> false
    end
  end

  @doc "Wraps text in ANSI codes if coloring is enabled."
  @spec wrap(String.t(), String.t()) :: String.t()
  def wrap(text, code) do
    if enabled?(), do: code <> text <> @reset, else: text
  end

  def bold(text), do: wrap(text, @bold)
  def dim(text), do: wrap(text, @dim)
  def italic(text), do: wrap(text, @italic)
  def red(text), do: wrap(text, @red)
  def green(text), do: wrap(text, @green)
  def yellow(text), do: wrap(text, @yellow)
  def blue(text), do: wrap(text, @blue)
  def magenta(text), do: wrap(text, @magenta)
  def cyan(text), do: wrap(text, @cyan)
  def bright_cyan(text), do: wrap(text, @bright_cyan)
  def bright_yellow(text), do: wrap(text, @bright_yellow)

  @doc "Format an error message with red bold prefix."
  @spec error(String.t()) :: String.t()
  def error(message), do: wrap("error: ", @red <> @bold) <> message

  @doc "Format an info status with cyan bold prefix."
  @spec info(String.t()) :: String.t()
  def info(message), do: wrap("info: ", @cyan <> @bold) <> message

  @doc """
  Colorize a formatted result string by tokenizing into number/unit/separator parts.

  Numbers (including decimals, scientific notation, signs, and locale digit separators)
  are rendered in bright cyan. Unit names are rendered in dim white. Hyphens within
  unit names (compound separators) are kept dim.

  Falls back to plain text when coloring is disabled.

  ### Examples

      iex> Application.put_env(:unity, :no_color, true)
      iex> Unity.Repl.Color.colorize_result("9.84252 feet")
      "9.84252 feet"
  """
  @spec colorize_result(String.t()) :: String.t()
  def colorize_result(formatted) when is_binary(formatted) do
    if enabled?() do
      do_colorize(formatted)
    else
      formatted
    end
  end

  # Tokenize the formatted output and color number tokens vs unit tokens.
  defp do_colorize(text) do
    # Match a leading number (with optional sign, decimals, exponent, and digit separators)
    # followed by optional unit text.
    Regex.replace(
      ~r/^([\-+]?[\d.,_]+(?:[eE][\-+]?\d+)?)(\s+)(.+)$/,
      text,
      fn _full, num, sep, rest ->
        bright_cyan(num) <> sep <> dim(rest)
      end
    )
  end
end
