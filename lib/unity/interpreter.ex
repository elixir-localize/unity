defmodule Unity.Interpreter do
  @moduledoc """
  Evaluates ASTs produced by `Unity.Parser` by building `Localize.Unit`
  structs and applying operations via `Localize.Unit.Math`.

  The interpreter maintains an environment map for variable bindings
  (via `let`) and a special `_` binding for the previous result.

  """

  @type env :: %{String.t() => Localize.Unit.t() | number()}
  @type result :: Localize.Unit.t() | number() | {:decomposed, [Localize.Unit.t()]}

  @doc """
  Evaluates a parsed AST in the given environment.

  ### Arguments

  * `ast` - the AST node from `Unity.Parser`.

  * `environment` - a map of variable bindings. Defaults to `%{}`.

  ### Returns

  * `{:ok, result, environment}` on success, where `result` is a
    `Localize.Unit.t()` or a number, and `environment` is the updated
    variable bindings.

  * `{:error, message}` on failure.

  ### Examples

      iex> {:ok, ast} = Unity.Parser.parse("3 meters to feet")
      iex> {:ok, result, _env} = Unity.Interpreter.eval(ast)
      iex> result.name
      "foot"

  """
  @spec eval(term(), env()) :: {:ok, result(), env()} | {:error, String.t()}
  def eval(ast, environment \\ %{})

  # ── Let binding ──

  def eval({:let, name, expr}, environment) do
    case eval(expr, environment) do
      {:ok, value, environment} ->
        {:ok, value, Map.put(environment, name, value)}

      error ->
        error
    end
  end

  # ── Number literal ──

  def eval({:number, value}, environment) do
    {:ok, value, environment}
  end

  # ── Variable reference ──

  def eval({:variable, name}, environment) do
    case Map.fetch(environment, name) do
      {:ok, value} -> {:ok, value, environment}
      :error -> {:error, "undefined variable: #{inspect(name)}"}
    end
  end

  # ── Unit name (bare unit, implicit quantity 1) ──
  # Check the environment first — the name might be a variable.

  def eval({:unit_name, name}, environment) do
    case Map.fetch(environment, name) do
      {:ok, value} ->
        {:ok, value, environment}

      :error ->
        case resolve_and_create(1, name) do
          {:ok, unit} -> {:ok, unit, environment}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  # ── Quantity (number + unit) ──

  def eval({:quantity, value, unit_ast}, environment) do
    case resolve_unit_ast(unit_ast) do
      {:ok, unit_name} ->
        case Localize.Unit.new(value, unit_name) do
          {:ok, unit} -> {:ok, unit, environment}
          {:error, exception} -> {:error, Exception.message(exception)}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ── Conversion ──

  def eval({:convert, expr, {:preferred_system}}, environment) do
    with {:ok, value, environment} <- eval(expr, environment) do
      locale = Localize.get_locale()
      {:ok, territory} = Localize.Territory.territory_from_locale(locale)
      system = Localize.Unit.measurement_system_for_territory(territory)
      convert_to_system(value, system, environment)
    end
  end

  def eval({:convert, expr, {:measurement_system, system}}, environment) do
    with {:ok, value, environment} <- eval(expr, environment) do
      convert_to_system(value, system, environment)
    end
  end

  def eval({:convert, expr, {:mixed_units, unit_asts}}, environment) do
    with {:ok, value, environment} <- eval(expr, environment) do
      decompose_value(value, unit_asts, environment)
    end
  end

  def eval({:convert, expr, target_ast}, environment) do
    with {:ok, value, environment} <- eval(expr, environment),
         {:ok, target_name} <- resolve_unit_ast(target_ast),
         {:ok, result} <- convert_value(value, target_name) do
      {:ok, result, environment}
    end
  end

  # ── Addition ──

  def eval({:add, left_ast, right_ast}, environment) do
    with {:ok, left, environment} <- eval(left_ast, environment),
         {:ok, right, environment} <- eval(right_ast, environment) do
      add_values(left, right, environment)
    end
  end

  # ── Subtraction ──

  def eval({:sub, left_ast, right_ast}, environment) do
    with {:ok, left, environment} <- eval(left_ast, environment),
         {:ok, right, environment} <- eval(right_ast, environment) do
      sub_values(left, right, environment)
    end
  end

  # ── Multiplication ──

  def eval({:mult, left_ast, right_ast}, environment) do
    with {:ok, left, environment} <- eval(left_ast, environment),
         {:ok, right, environment} <- eval(right_ast, environment) do
      mult_values(left, right, environment)
    end
  end

  # ── Division ──

  def eval({:div, left_ast, right_ast}, environment) do
    with {:ok, left, environment} <- eval(left_ast, environment),
         {:ok, right, environment} <- eval(right_ast, environment) do
      div_values(left, right, environment)
    end
  end

  # ── Power ──

  def eval({:power, base_ast, exp_ast}, environment) do
    with {:ok, base, environment} <- eval(base_ast, environment),
         {:ok, exponent, environment} <- eval(exp_ast, environment) do
      power_value(base, exponent, environment)
    end
  end

  # ── Negation ──

  def eval({:negate, expr_ast}, environment) do
    with {:ok, value, environment} <- eval(expr_ast, environment) do
      negate_value(value, environment)
    end
  end

  # ── Function call ──

  def eval({:function, name, arg_asts}, environment) do
    {args, environment} =
      Enum.reduce_while(arg_asts, {[], environment}, fn ast, {acc, env} ->
        case eval(ast, env) do
          {:ok, value, env} -> {:cont, {[value | acc], env}}
          {:error, _} = error -> {:halt, {error, env}}
        end
      end)

    case args do
      {:error, _} = error ->
        error

      args ->
        args = Enum.reverse(args)
        apply_function(name, args, environment)
    end
  end

  # ── Catch-all ──

  def eval(ast, _environment) do
    {:error, "cannot evaluate: #{inspect(ast)}"}
  end

  # ── Unit name resolution ──

  defp resolve_unit_ast({:unit_name, name}) do
    case Unity.Aliases.resolve(name) do
      {:ok, cldr_name} ->
        {:ok, cldr_name}

      {:error, :unknown_unit} ->
        suggestions = Unity.Aliases.suggest(name)
        suggestion_text = format_suggestions(suggestions)
        {:error, "unknown unit: #{inspect(name)}#{suggestion_text}"}
    end
  end

  defp resolve_unit_ast({:power, {:unit_name, name}, {:number, exponent}}) do
    case Unity.Aliases.resolve(name) do
      {:ok, cldr_name} ->
        power_name = power_prefix(exponent) <> cldr_name
        {:ok, power_name}

      {:error, :unknown_unit} ->
        suggestions = Unity.Aliases.suggest(name)
        suggestion_text = format_suggestions(suggestions)
        {:error, "unknown unit: #{inspect(name)}#{suggestion_text}"}
    end
  end

  defp resolve_unit_ast({:div, left_ast, right_ast}) do
    with {:ok, left_name} <- resolve_unit_ast(left_ast),
         {:ok, right_name} <- resolve_unit_ast(right_ast) do
      {:ok, left_name <> "-per-" <> right_name}
    end
  end

  defp resolve_unit_ast({:mult, left_ast, right_ast}) do
    with {:ok, left_name} <- resolve_unit_ast(left_ast),
         {:ok, right_name} <- resolve_unit_ast(right_ast) do
      {:ok, left_name <> "-" <> right_name}
    end
  end

  defp resolve_unit_ast(other) do
    {:error, "cannot resolve unit expression: #{inspect(other)}"}
  end

  defp power_prefix(2), do: "square-"
  defp power_prefix(3), do: "cubic-"
  defp power_prefix(n), do: "pow#{n}-"

  defp resolve_and_create(value, name) do
    case Unity.Aliases.resolve(name) do
      {:ok, cldr_name} ->
        case Localize.Unit.new(value, cldr_name) do
          {:ok, unit} -> {:ok, unit}
          {:error, exception} -> {:error, Exception.message(exception)}
        end

      {:error, :unknown_unit} ->
        suggestions = Unity.Aliases.suggest(name)
        suggestion_text = format_suggestions(suggestions)
        {:error, "unknown unit: #{inspect(name)}#{suggestion_text}"}
    end
  end

  defp format_suggestions([]), do: ""

  defp format_suggestions(suggestions) do
    names = Enum.map(suggestions, fn {name, _dist} -> inspect(name) end)
    "\n  Did you mean: #{Enum.join(names, ", ")}?"
  end

  # ── Conversion ──

  defp convert_value(%Localize.Unit{} = unit, target_name) do
    case Localize.Unit.convert(unit, target_name) do
      {:ok, result} ->
        {:ok, result}

      {:error, exception} when is_exception(exception) ->
        {:error, Exception.message(exception)}

      {:error, reason} ->
        {:error, "conversion error: #{inspect(reason)}"}
    end
  end

  defp convert_value(number, target_name) when is_number(number) do
    {:error,
     "cannot convert bare number #{number} to #{inspect(target_name)} — specify a source unit"}
  end

  # ── Measurement system conversion ──

  defp convert_to_system(%Localize.Unit{} = unit, system, environment) do
    case Localize.Unit.convert_measurement_system(unit, system) do
      {:ok, result} ->
        {:ok, result, environment}

      {:error, reason} ->
        {:error, format_math_error("convert to measurement system", reason)}
    end
  end

  defp convert_to_system(_value, _system, _environment) do
    {:error, "measurement system conversion requires a unit value"}
  end

  # ── Mixed-unit decomposition ──

  defp decompose_value(%Localize.Unit{} = unit, unit_asts, environment) do
    with {:ok, target_names} <- resolve_unit_list(unit_asts) do
      case Localize.Unit.decompose(unit, target_names) do
        {:ok, parts} ->
          {:ok, {:decomposed, parts}, environment}

        {:error, exception} when is_exception(exception) ->
          {:error, Exception.message(exception)}

        {:error, reason} ->
          {:error, "decomposition error: #{inspect(reason)}"}
      end
    end
  end

  defp decompose_value(_value, _unit_asts, _environment) do
    {:error, "mixed-unit decomposition requires a unit value"}
  end

  defp resolve_unit_list(unit_asts) do
    Enum.reduce_while(unit_asts, {:ok, []}, fn ast, {:ok, acc} ->
      case resolve_unit_ast(ast) do
        {:ok, name} -> {:cont, {:ok, acc ++ [name]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  # ── Arithmetic dispatch ──

  defp add_values(%Localize.Unit{} = left, %Localize.Unit{} = right, environment) do
    case Localize.Unit.Math.add(left, right) do
      {:ok, result} -> {:ok, result, environment}
      {:error, reason} -> {:error, format_math_error("add", reason)}
    end
  end

  defp add_values(left, right, environment) when is_number(left) and is_number(right) do
    {:ok, left + right, environment}
  end

  defp add_values(_left, _right, _environment) do
    {:error, "cannot add incompatible types"}
  end

  defp sub_values(%Localize.Unit{} = left, %Localize.Unit{} = right, environment) do
    case Localize.Unit.Math.sub(left, right) do
      {:ok, result} -> {:ok, result, environment}
      {:error, reason} -> {:error, format_math_error("subtract", reason)}
    end
  end

  defp sub_values(left, right, environment) when is_number(left) and is_number(right) do
    {:ok, left - right, environment}
  end

  defp sub_values(_left, _right, _environment) do
    {:error, "cannot subtract incompatible types"}
  end

  defp mult_values(%Localize.Unit{} = left, %Localize.Unit{} = right, environment) do
    {:ok, result} = Localize.Unit.Math.mult(left, right)
    {:ok, result, environment}
  end

  defp mult_values(%Localize.Unit{} = unit, number, environment) when is_number(number) do
    {:ok, result} = Localize.Unit.Math.mult(unit, number)
    {:ok, result, environment}
  end

  defp mult_values(number, %Localize.Unit{} = unit, environment) when is_number(number) do
    {:ok, result} = Localize.Unit.Math.mult(unit, number)
    {:ok, result, environment}
  end

  defp mult_values(left, right, environment) when is_number(left) and is_number(right) do
    {:ok, left * right, environment}
  end

  defp mult_values(_left, _right, _environment) do
    {:error, "cannot multiply incompatible types"}
  end

  defp div_values(%Localize.Unit{} = left, %Localize.Unit{} = right, environment) do
    {:ok, result} = Localize.Unit.Math.div(left, right)
    {:ok, result, environment}
  end

  defp div_values(%Localize.Unit{} = unit, number, environment) when is_number(number) do
    if number == 0 do
      {:error, "division by zero"}
    else
      {:ok, result} = Localize.Unit.Math.div(unit, number)
      {:ok, result, environment}
    end
  end

  defp div_values(number, %Localize.Unit{} = unit, environment) when is_number(number) do
    # number / unit → invert the unit then multiply by the number
    {:ok, inverted} = Localize.Unit.Math.invert(unit)
    {:ok, result} = Localize.Unit.Math.mult(inverted, number)
    {:ok, result, environment}
  end

  defp div_values(left, right, environment) when is_number(left) and is_number(right) do
    if right == 0 do
      {:error, "division by zero"}
    else
      {:ok, left / right, environment}
    end
  end

  defp div_values(_left, _right, _environment) do
    {:error, "cannot divide incompatible types"}
  end

  # ── Power ──

  defp power_value(%Localize.Unit{} = unit, exponent, environment) when is_number(exponent) do
    int_exp = trunc(exponent)

    if int_exp != exponent do
      {:error, "non-integer exponents on units are not supported"}
    else
      unit_name = unit.name
      power_name = power_prefix(int_exp) <> unit_name

      case Localize.Unit.new(1, power_name) do
        {:ok, _} ->
          # For "9 m^2", the value stays 9 and the unit becomes square-meter.
          # The exponent applies to the unit, not the value.
          value = unit.value || 1

          case Localize.Unit.new(value, power_name) do
            {:ok, result} -> {:ok, result, environment}
            {:error, exception} -> {:error, Exception.message(exception)}
          end

        {:error, _} ->
          # Fall back to repeated multiplication for compound units
          repeated_mult(unit, int_exp, environment)
      end
    end
  end

  defp power_value(base, exponent, environment) when is_number(base) and is_number(exponent) do
    {:ok, :math.pow(base, exponent), environment}
  end

  defp power_value(_base, _exponent, _environment) do
    {:error, "cannot raise to non-numeric exponent"}
  end

  defp repeated_mult(_unit, 0, environment) do
    {:ok, 1, environment}
  end

  defp repeated_mult(unit, 1, environment) do
    {:ok, unit, environment}
  end

  defp repeated_mult(unit, n, environment) when n > 1 do
    result =
      Enum.reduce(2..n, unit, fn _i, acc ->
        {:ok, product} = Localize.Unit.Math.mult(acc, unit)
        product
      end)

    {:ok, result, environment}
  end

  defp repeated_mult(unit, n, environment) when n < 0 do
    case repeated_mult(unit, -n, environment) do
      {:ok, result, env} ->
        case Localize.Unit.Math.invert(result) do
          {:ok, inverted} -> {:ok, inverted, env}
          {:error, reason} -> {:error, format_math_error("power", reason)}
        end

      error ->
        error
    end
  end

  # ── Negation ──

  defp negate_value(%Localize.Unit{} = unit, environment) do
    case Localize.Unit.Math.negate(unit) do
      {:ok, result} -> {:ok, result, environment}
      {:error, reason} -> {:error, format_math_error("negate", reason)}
    end
  end

  defp negate_value(number, environment) when is_number(number) do
    {:ok, -number, environment}
  end

  # ── Built-in functions ──
  #
  # All unit-aware functions delegate to Localize.Unit.Math.
  # Bare-number overloads use :math directly.

  @unit_functions %{
    "sqrt" => :sqrt,
    "cbrt" => :cbrt,
    "abs" => :abs,
    "round" => :round,
    "ceil" => :ceil,
    "floor" => :floor
  }

  @dimensionless_functions %{
    "sin" => :sin,
    "cos" => :cos,
    "tan" => :tan,
    "asin" => :asin,
    "acos" => :acos,
    "atan" => :atan,
    "ln" => :ln,
    "log" => :log,
    "log2" => :log2,
    "exp" => :exp
  }

  @all_functions Map.keys(@unit_functions) ++ Map.keys(@dimensionless_functions)

  defp apply_function(name, [%Localize.Unit{} = unit], environment)
       when is_map_key(@unit_functions, name) do
    math_fn = Map.fetch!(@unit_functions, name)

    case apply(Localize.Unit.Math, math_fn, [unit]) do
      {:ok, result} -> {:ok, result, environment}
      {:error, reason} -> {:error, format_math_error(name, reason)}
    end
  end

  defp apply_function(name, [n], environment)
       when is_map_key(@unit_functions, name) and is_number(n) do
    result =
      case name do
        "sqrt" -> :math.sqrt(n)
        "cbrt" -> :math.pow(n, 1 / 3)
        "abs" -> Kernel.abs(n)
        "round" -> Kernel.round(n)
        "ceil" -> Kernel.ceil(n)
        "floor" -> Kernel.floor(n)
      end

    {:ok, result, environment}
  end

  defp apply_function(name, [%Localize.Unit{} = unit], environment)
       when is_map_key(@dimensionless_functions, name) do
    math_fn = Map.fetch!(@dimensionless_functions, name)

    case Localize.Unit.Math.apply_dimensionless(math_fn, unit) do
      {:ok, result} -> {:ok, result, environment}
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_function(name, [n], environment)
       when is_map_key(@dimensionless_functions, name) and is_number(n) do
    result =
      case name do
        "sin" -> :math.sin(n)
        "cos" -> :math.cos(n)
        "tan" -> :math.tan(n)
        "asin" -> :math.asin(n)
        "acos" -> :math.acos(n)
        "atan" -> :math.atan(n)
        "ln" -> :math.log(n)
        "log" -> :math.log10(n)
        "log2" -> :math.log2(n)
        "exp" -> :math.exp(n)
      end

    {:ok, result, environment}
  end

  defp apply_function(name, args, _environment) when name in @all_functions do
    {:error, "#{name} expects exactly 1 argument, got #{length(args)}"}
  end

  # Special conversion function: tempC(100) → 373.15 kelvin
  defp apply_function(name, [arg], environment) when is_number(arg) do
    case Localize.Unit.CustomRegistry.get(name) do
      %{factor: :special, forward: {mod, fun}, base_unit: base_unit} ->
        result_value = apply(mod, fun, [arg])
        {:ok, Localize.Unit.new!(result_value, base_unit), environment}

      _ ->
        {:error, "unknown function: #{inspect(name)}"}
    end
  end

  defp apply_function(name, _args, _environment) do
    {:error, "unknown function: #{inspect(name)}"}
  end

  defp format_math_error(operation, reason) when is_binary(reason) do
    "cannot #{operation}: #{reason}"
  end

  defp format_math_error(operation, reason) when is_exception(reason) do
    "cannot #{operation}: #{Exception.message(reason)}"
  end

  defp format_math_error(operation, reason) do
    "cannot #{operation}: #{inspect(reason)}"
  end
end
