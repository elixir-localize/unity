defmodule Units.Parser do
  @moduledoc """
  NimbleParsec-based expression parser for unit expressions.

  Parses expressions like `"3 meters to feet"`, `"60 mph + 10 km/h"`,
  or `"sqrt(9 m^2)"` into an AST that the interpreter can evaluate.

  The grammar supports:

  * Numeric literals (integers, floats, rationals with `|`).

  * Unit names (resolved via `Units.Aliases`).

  * Arithmetic operators: `+`, `-`, `*`, `/`, `^`.

  * Juxtaposition multiplication (space between units): `kg m` = `kg * m`.

  * `per` as a synonym for `/`.

  * Conversion operators: `to`, `in`, `->`.

  * Parenthesized sub-expressions.

  * Function calls: `sqrt(expr)`, `abs(expr)`, etc.

  * Concatenated single-digit exponents: `cm3` = `cm^3`.

  * Rational numbers: `1|3` = 1/3.

  """

  import NimbleParsec

  # ── Whitespace ──

  ws = ascii_string([?\s, ?\t], min: 1) |> ignore()
  optional_ws = ascii_string([?\s, ?\t], min: 0) |> ignore()

  # ── Number literals ──

  sign = ascii_char([?-, ?+]) |> reduce({List, :to_string, []})

  digits = ascii_string([?0..?9], min: 1)

  integer =
    optional(sign)
    |> concat(digits)
    |> reduce(:build_integer)

  float_literal =
    optional(sign)
    |> concat(digits)
    |> ignore(string("."))
    |> concat(digits)
    |> optional(
      ignore(ascii_string([?e, ?E], 1))
      |> concat(optional(ascii_string([?-, ?+], 1)))
      |> concat(digits)
    )
    |> reduce(:build_float)

  rational =
    optional(sign)
    |> concat(digits)
    |> ignore(ascii_char([?|]))
    |> concat(digits)
    |> reduce(:build_rational)

  number =
    choice([
      rational,
      float_literal,
      integer
    ])

  # ── Identifiers (unit names, function names) ──

  identifier =
    ascii_string([?a..?z, ?A..?Z, ?_], 1)
    |> ascii_string([?a..?z, ?A..?Z, ?0..?9, ?_, ?-], min: 0)
    |> reduce({Enum, :join, [""]})

  # Special characters in unit names (°, µ)
  special_identifier =
    choice([
      string("°C") |> replace("°C"),
      string("°F") |> replace("°F"),
      string("°") |> replace("°"),
      string("µm") |> replace("µm"),
      string("µs") |> replace("µs"),
      string("µg") |> replace("µg")
    ])

  unit_identifier =
    choice([
      special_identifier,
      identifier
    ])

  # ── Function calls ──
  # Parsed as {:function, name, [args...]}

  function_call =
    identifier
    |> ignore(optional_ws)
    |> ignore(ascii_char([?(]))
    |> ignore(optional_ws)
    |> parsec(:expression)
    |> repeat(
      ignore(optional_ws)
      |> ignore(ascii_char([?,]))
      |> ignore(optional_ws)
      |> parsec(:expression)
    )
    |> ignore(optional_ws)
    |> ignore(ascii_char([?)]))
    |> reduce(:build_function_call)

  # ── Unit name with optional concatenated exponent ──
  # "cm3" → {:power, {:unit_name, "cm"}, 3}
  # The identifier already consumes trailing digits, so we split them off
  # in the reducer if the last character is a single digit.

  unit_name =
    unit_identifier
    |> reduce(:build_unit_name)

  # ── Quantity: optional number followed by unit ──
  # "3.5 meters" or just "meters"

  quantity =
    choice([
      number
      |> ignore(optional_ws)
      |> concat(unit_name)
      |> reduce(:build_quantity),
      unit_name |> reduce(:build_bare_unit)
    ])

  # ── Parenthesized expression ──

  paren_expr =
    ignore(ascii_char([?(]))
    |> ignore(optional_ws)
    |> parsec(:expression)
    |> ignore(optional_ws)
    |> ignore(ascii_char([?)]))

  # ── Base (atom of expression) ──

  base =
    choice([
      paren_expr,
      function_call,
      number |> lookahead_not(ignore(optional_ws) |> concat(unit_identifier)),
      quantity
    ])

  # ── Factor: base with optional exponent ──

  factor =
    base
    |> optional(
      ignore(optional_ws)
      |> ignore(ascii_char([?^]))
      |> ignore(optional_ws)
      |> concat(
        choice([
          paren_expr,
          number
        ])
      )
      |> reduce(:mark_exponent)
    )
    |> reduce(:build_factor)

  # ── Term: factors joined by *, /, per, or juxtaposition ──

  mult_op =
    choice([
      ignore(optional_ws) |> ascii_char([?*]) |> ignore(optional_ws) |> replace(:mult),
      ignore(optional_ws)
      |> ascii_char([?/])
      |> ignore(optional_ws)
      |> replace(:div),
      ignore(ws) |> string("per") |> ignore(ws) |> replace(:div)
    ])

  term =
    factor
    |> repeat(
      mult_op
      |> concat(factor)
    )
    |> reduce(:build_term)

  # ── Computation: terms joined by + or - ──

  add_op =
    choice([
      ignore(optional_ws) |> ascii_char([?+]) |> ignore(optional_ws) |> replace(:add),
      ignore(optional_ws) |> ascii_char([?-]) |> ignore(optional_ws) |> replace(:sub)
    ])

  computation =
    term
    |> repeat(
      add_op
      |> concat(term)
    )
    |> reduce(:build_computation)

  # ── Conversion: computation followed by "to"/"in"/"->" and a target ──

  conversion_op =
    choice([
      ignore(ws) |> string("->") |> ignore(optional_ws) |> replace(:convert),
      ignore(ws) |> string("to") |> ignore(ws) |> replace(:convert),
      ignore(ws) |> string("in") |> ignore(ws) |> replace(:convert)
    ])

  expression =
    computation
    |> optional(
      conversion_op
      |> concat(computation)
      |> reduce(:mark_conversion)
    )
    |> reduce(:build_expression)

  # ── Let binding ──

  let_binding =
    ignore(string("let"))
    |> ignore(ws)
    |> concat(identifier)
    |> ignore(optional_ws)
    |> ignore(ascii_char([?=]))
    |> ignore(optional_ws)
    |> parsec(:expression)
    |> reduce(:build_let)

  # ── Top-level ──

  top_level =
    ignore(optional_ws)
    |> choice([
      let_binding,
      expression
    ])
    |> ignore(optional_ws)
    |> eos()

  defparsec(:expression, expression)
  defparsec(:parse_expression, top_level)

  # ── Public API ──

  @doc """
  Parses a unit expression string into an AST.

  ### Arguments

  * `input` - the expression string to parse.

  ### Returns

  * `{:ok, ast}` on success.

  * `{:error, message}` on parse failure.

  ### Examples

      iex> Units.Parser.parse("3 meters")
      {:ok, {:quantity, 3, "meters"}}

      iex> Units.Parser.parse("3 meters to feet")
      {:ok, {:convert, {:quantity, 3, "meters"}, {:unit_name, "feet"}}}

  """
  @spec parse(String.t()) :: {:ok, term()} | {:error, String.t()}
  def parse(input) do
    case parse_expression(input) do
      {:ok, [ast], "", _context, _line, _offset} ->
        {:ok, ast}

      {:ok, [ast], rest, _context, _line, _offset} ->
        {:error, "unexpected input after expression: #{inspect(rest)}", ast}

      {:error, message, _rest, _context, {line, _}, offset} ->
        {:error, format_parse_error(input, message, line, offset)}
    end
  end

  @doc """
  Parses a unit expression string into an AST, raising on failure.

  ### Arguments

  * `input` - the expression string to parse.

  ### Returns

  The parsed AST.

  ### Examples

      iex> Units.Parser.parse!("3 meters")
      {:quantity, 3, "meters"}

  """
  @spec parse!(String.t()) :: term()
  def parse!(input) do
    case parse(input) do
      {:ok, ast} -> ast
      {:error, message} -> raise ArgumentError, message
      {:error, message, _partial} -> raise ArgumentError, message
    end
  end

  # ── AST builders (called by reduce) ──

  @doc false
  def build_integer(parts) do
    str = Enum.join(parts)
    {:number, String.to_integer(str)}
  end

  @doc false
  def build_float(parts) do
    {sign, rest} =
      case parts do
        [s | r] when s in ["-", "+"] -> {s, r}
        r -> {"", r}
      end

    [int_part, frac_part | exp_parts] = rest

    float_str = sign <> int_part <> "." <> frac_part

    float_str =
      case exp_parts do
        [] ->
          float_str

        _ ->
          exp_str = Enum.join(exp_parts)
          float_str <> "e" <> exp_str
      end

    {:number, String.to_float(float_str)}
  end

  @doc false
  def build_rational(parts) do
    {sign, rest} =
      case parts do
        [s | r] when s in ["-", "+"] -> {s, r}
        r -> {"", r}
      end

    [numerator_str, denominator_str] = rest
    numerator = String.to_integer(sign <> numerator_str)
    denominator = String.to_integer(denominator_str)

    if denominator == 0 do
      {:error, :division_by_zero}
    else
      {:number, numerator / denominator}
    end
  end

  @doc false
  def build_unit_name([name]) do
    case Regex.run(~r/^(.+?)(\d)$/, name) do
      [_, base, exp] when byte_size(base) > 0 ->
        # Only treat trailing digit as exponent if the base resolves to a known unit
        case Units.Aliases.resolve(base) do
          {:ok, _} ->
            {:power, {:unit_name, base}, {:number, String.to_integer(exp)}}

          {:error, _} ->
            {:unit_name, name}
        end

      _ ->
        {:unit_name, name}
    end
  end

  @doc false
  def build_quantity(parts) do
    case parts do
      [{:number, value}, unit_ast] ->
        {:quantity, value, unit_ast}

      [{:error, _} = error, _unit_ast] ->
        error
    end
  end

  @doc false
  def build_bare_unit([unit_ast]) do
    unit_ast
  end

  @doc false
  def build_function_call([name | args]) do
    {:function, name, args}
  end

  @doc false
  def mark_exponent(parts) do
    {:exponent, parts}
  end

  @doc false
  def build_factor(parts) do
    case parts do
      [base, {:exponent, [exponent]}] ->
        {:power, base, exponent}

      [base] ->
        base
    end
  end

  @doc false
  def build_term(parts) do
    build_left_assoc(parts)
  end

  @doc false
  def build_computation(parts) do
    build_left_assoc(parts)
  end

  @doc false
  def mark_conversion(parts) do
    case parts do
      [:convert, target] -> {:conversion_target, target}
    end
  end

  @doc false
  def build_expression(parts) do
    case parts do
      [expr, {:conversion_target, target}] ->
        {:convert, expr, target}

      [expr] ->
        expr
    end
  end

  @doc false
  def build_let([name, expr]) do
    {:let, name, expr}
  end

  # ── Helpers ──

  defp build_left_assoc([first | rest]) do
    rest
    |> Enum.chunk_every(2)
    |> Enum.reduce(first, fn [op, right], left ->
      {op, left, right}
    end)
  end

  defp format_parse_error(input, message, _line, offset) do
    pointer = String.duplicate(" ", max(offset, 0)) <> "^"
    "parse error: #{message}\n  #{input}\n  #{pointer}"
  end
end
