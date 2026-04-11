defmodule Units do
  @moduledoc """
  An Elixir unit conversion calculator inspired by the Unix `units` utility.

  Uses `Localize.Unit` as the primary engine for unit creation, conversion,
  arithmetic, and localized output. Adds a NimbleParsec-based expression
  parser and an interpreter that evaluates unit expressions interactively
  or from the command line.

  ## Quick start

      iex> result = Units.eval!("3 meters to feet")
      iex> result.name
      "foot"

      iex> Units.eval!("60 mph to km/h") |> Units.format!()
      "96.56064 kilometers per hour"

  ## Expression syntax

  * `3 meters to feet` — unit conversion.

  * `60 mph + 10 km/h` — arithmetic on compatible units.

  * `100 kg * 9.8 m/s^2` — unit multiplication.

  * `sqrt(9 m^2)` — built-in functions.

  * `1|3 cup` — rational numbers.

  * `let x = 42 km` — variable binding.

  """

  @type result :: Localize.Unit.t() | number() | {:decomposed, [Localize.Unit.t()]}
  @type env :: Units.Interpreter.env()

  @doc """
  Parses and evaluates a unit expression string.

  ### Arguments

  * `input` - the expression string to evaluate.

  * `environment` - a map of variable bindings. Defaults to `%{}`.

  ### Returns

  * `{:ok, result, environment}` on success.

  * `{:error, message}` on failure.

  ### Examples

      iex> {:ok, result, _env} = Units.eval("3 meters to feet")
      iex> Float.round(result.value, 2)
      9.84

  """
  @spec eval(String.t(), env()) :: {:ok, result(), env()} | {:error, String.t()}
  def eval(input, environment \\ %{}) do
    case Units.Parser.parse(input) do
      {:ok, ast} ->
        Units.Interpreter.eval(ast, environment)

      {:error, message} ->
        {:error, message}
    end
  end

  @doc """
  Parses and evaluates a unit expression string, raising on failure.

  ### Arguments

  * `input` - the expression string to evaluate.

  * `environment` - a map of variable bindings. Defaults to `%{}`.

  ### Returns

  The evaluation result (`Localize.Unit.t()` or a number).

  ### Examples

      iex> result = Units.eval!("3 meters to feet")
      iex> result.name
      "foot"

  """
  @spec eval!(String.t(), env()) :: result()
  def eval!(input, environment \\ %{}) do
    case eval(input, environment) do
      {:ok, result, _env} -> result
      {:error, message} -> raise ArgumentError, message
    end
  end

  @doc """
  Formats a result value for display.

  Delegates to `Units.Formatter.format/2`.

  ### Arguments

  * `result` - a `Localize.Unit.t()` or a number.

  * `options` - formatting options. See `Units.Formatter.format/2`.

  ### Returns

  * `{:ok, formatted_string}` on success.

  * `{:error, reason}` on failure.

  ### Examples

      iex> {:ok, unit} = Localize.Unit.new(9.84252, "foot")
      iex> Units.format(unit)
      {:ok, "9.84252 feet"}

  """
  @spec format(result(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  defdelegate format(result, options \\ []), to: Units.Formatter

  @doc """
  Formats a result value for display, raising on failure.

  ### Arguments

  * `result` - a `Localize.Unit.t()` or a number.

  * `options` - formatting options. See `Units.Formatter.format/2`.

  ### Returns

  The formatted string.

  ### Examples

      iex> {:ok, unit} = Localize.Unit.new(9.84252, "foot")
      iex> Units.format!(unit)
      "9.84252 feet"

  """
  @spec format!(result(), keyword()) :: String.t()
  defdelegate format!(result, options \\ []), to: Units.Formatter
end
