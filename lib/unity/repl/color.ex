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
  # Numbers are bright cyan; units are green — both high-contrast on dark
  # terminal backgrounds and distinct from each other without being harsh.
  #
  # CLDR number formatting uses different Unicode characters depending
  # on role, and we must keep them apart:
  #
  #   * Inside a number (thousands separator, French): U+202F NARROW
  #     NO-BREAK SPACE. Allowed in the number character class.
  #   * Between number and unit (German, French): U+00A0 NO-BREAK SPACE.
  #     NOT allowed in the number class — must only appear as the
  #     separator, otherwise the greedy number match swallows it.
  #   * ASCII digits, `.`, `,`, `_`, and NNBSP in the number.
  #   * Any of ASCII whitespace, NBSP, or NNBSP as the unit separator.
  defp do_colorize(text) do
    Regex.replace(
      ~r/^([\-+]?[\d.,_\x{202F}]+(?:[eE][\-+]?\d+)?)([\s\x{00A0}\x{202F}]+)(.+)$/u,
      text,
      fn _full, num, sep, rest ->
        bright_cyan(num) <> sep <> green(rest)
      end
    )
  end
end
