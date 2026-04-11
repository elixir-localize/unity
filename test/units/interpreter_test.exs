defmodule Units.InterpreterTest do
  use ExUnit.Case, async: true

  alias Units.{Parser, Interpreter}

  defp eval!(input, environment \\ %{}) do
    {:ok, ast} = Parser.parse(input)

    case Interpreter.eval(ast, environment) do
      {:ok, result, env} -> {result, env}
      {:error, message} -> raise "evaluation failed: #{message}"
    end
  end

  defp eval_error(input, environment \\ %{}) do
    {:ok, ast} = Parser.parse(input)
    {:error, message} = Interpreter.eval(ast, environment)
    message
  end

  describe "basic unit creation" do
    test "creates a unit from quantity" do
      {result, _env} = eval!("3 meters")
      assert %Localize.Unit{value: 3, name: "meter"} = result
    end

    test "creates a unit from bare unit name" do
      {result, _env} = eval!("meter")
      assert %Localize.Unit{value: 1, name: "meter"} = result
    end

    test "resolves aliases" do
      {result, _env} = eval!("3 km")
      assert %Localize.Unit{value: 3, name: "kilometer"} = result
    end

    test "resolves abbreviations" do
      {result, _env} = eval!("60 mph")
      assert %Localize.Unit{value: 60, name: "mile-per-hour"} = result
    end
  end

  describe "conversion" do
    test "converts meters to feet" do
      {result, _env} = eval!("3 meters to feet")
      assert result.name == "foot"
      assert_in_delta result.value, 9.84252, 0.001
    end

    test "converts mph to km/h" do
      {result, _env} = eval!("60 mph to km/h")
      assert result.name == "kilometer-per-hour"
      assert_in_delta result.value, 96.5606, 0.001
    end

    test "converts gallons to liters" do
      {result, _env} = eval!("1 gallon to liters")
      assert result.name == "liter"
      assert_in_delta result.value, 3.78541, 0.001
    end

    test "converts celsius to fahrenheit" do
      {result, _env} = eval!("100 celsius to fahrenheit")
      assert result.name == "fahrenheit"
      assert_in_delta result.value, 212, 0.001
    end

    test "converts using arrow operator" do
      {result, _env} = eval!("3 m -> cm")
      assert result.name == "centimeter"
      assert_in_delta result.value, 300, 0.001
    end

    test "converts using in keyword" do
      {result, _env} = eval!("1 km in m")
      assert result.name == "meter"
      assert_in_delta result.value, 1000, 0.001
    end
  end

  describe "addition" do
    test "adds compatible units" do
      {result, _env} = eval!("3.5 km + 500 m")
      assert result.name == "kilometer"
      assert_in_delta result.value, 4.0, 0.001
    end

    test "adds feet and inches" do
      {result, _env} = eval!("12 ft + 3 in")
      assert result.name == "foot"
      assert_in_delta result.value, 12.25, 0.001
    end

    test "add then convert" do
      {result, _env} = eval!("12 ft + 3 in to ft")
      assert result.name == "foot"
      assert_in_delta result.value, 12.25, 0.001
    end

    test "adds bare numbers" do
      {result, _env} = eval!("3 + 4")
      assert result == 7
    end
  end

  describe "subtraction" do
    test "subtracts compatible units" do
      {result, _env} = eval!("10 km - 3 km")
      assert result.name == "kilometer"
      assert_in_delta result.value, 7.0, 0.001
    end

    test "subtracts bare numbers" do
      {result, _env} = eval!("10 - 3")
      assert result == 7
    end
  end

  describe "multiplication" do
    test "multiplies units" do
      {result, _env} = eval!("100 kg * 9.8 m/s^2")
      assert result.name == "kilogram-meter-per-square-second"
      assert_in_delta result.value, 980, 0.001
    end

    test "multiplies bare numbers" do
      {result, _env} = eval!("6 * 7")
      assert result == 42
    end
  end

  describe "division" do
    test "divides units" do
      {result, _env} = eval!("100 m / 10 s")
      assert result.name == "meter-per-second"
      assert_in_delta result.value, 10, 0.001
    end

    test "divides with per keyword" do
      {result, _env} = eval!("5 miles per hour")
      assert result.name == "mile-per-hour"
      assert_in_delta result.value, 5, 0.001
    end

    test "division by zero returns error" do
      message = eval_error("10 / 0")
      assert message =~ "division by zero"
    end
  end

  describe "exponentiation" do
    test "unit squared" do
      {result, _env} = eval!("9 m^2")
      assert result.name == "square-meter"
      assert result.value == 9
    end

    test "unit cubed" do
      {result, _env} = eval!("27 m^3")
      assert result.name == "cubic-meter"
      assert result.value == 27
    end

    test "concatenated exponent" do
      {result, _env} = eval!("9 cm3")
      assert result.name == "cubic-centimeter"
      assert result.value == 9
    end

    test "number exponentiation" do
      {result, _env} = eval!("2^10")
      assert_in_delta result, 1024, 0.001
    end
  end

  describe "functions" do
    test "sqrt of square unit" do
      {result, _env} = eval!("sqrt(9 m^2)")
      assert result.name == "meter"
      assert_in_delta result.value, 3.0, 0.001
    end

    test "sqrt of number" do
      {result, _env} = eval!("sqrt(16)")
      assert_in_delta result, 4.0, 0.001
    end

    test "abs of negative unit" do
      {result, _env} = eval!("abs(-5 m)")
      assert result.name == "meter"
      assert result.value == 5
    end

    test "round" do
      {result, _env} = eval!("round(3.7)")
      assert result == 4
    end

    test "ceil" do
      {result, _env} = eval!("ceil(3.2)")
      assert result == 4
    end

    test "floor" do
      {result, _env} = eval!("floor(3.7)")
      assert result == 3
    end

    test "sin" do
      {result, _env} = eval!("sin(0)")
      assert_in_delta result, 0.0, 0.001
    end

    test "sqrt of non-square unit returns error" do
      message = eval_error("sqrt(9 m^3)")
      assert message =~ "square root"
    end

    test "unknown function returns error" do
      message = eval_error("blarg(3)")
      assert message =~ "unknown function"
    end
  end

  describe "let bindings and variable references" do
    test "simple variable binding" do
      {_result, env} = eval!("let x = 3 m")
      assert %Localize.Unit{value: 3, name: "meter"} = env["x"]
    end

    test "variable reference in conversion" do
      {_, env} = eval!("let distance = 42.195 km")
      {result, _env} = eval!("distance to miles", env)
      assert result.name == "mile"
      assert_in_delta result.value, 26.219, 0.01
    end

    test "variable reference in arithmetic" do
      {_, env} = eval!("let x = 10 m")
      {result, _env} = eval!("x + 5 m", env)
      assert result.name == "meter"
      assert_in_delta result.value, 15, 0.001
    end

    test "underscore references previous result" do
      env = %{"_" => Localize.Unit.new!(10, "meter")}
      {result, _env} = eval!("_ to cm", env)
      assert result.name == "centimeter"
      assert_in_delta result.value, 1000, 0.001
    end

    test "underscore in arithmetic" do
      env = %{"_" => Localize.Unit.new!(10, "meter")}
      {result, _env} = eval!("_ + 5 m", env)
      assert result.name == "meter"
      assert_in_delta result.value, 15, 0.001
    end
  end

  describe "juxtaposition multiplication" do
    test "kg m evaluates to compound unit" do
      {result, _env} = eval!("kg m")
      assert result.name == "kilogram-meter"
    end

    test "kg m / s^2 evaluates correctly (juxtaposition higher than /)" do
      {result, _env} = eval!("kg m / s^2")
      assert result.name == "kilogram-meter-per-square-second"
    end

    test "(3 + 4) m evaluates to 7 meters" do
      {result, _env} = eval!("(3 + 4) * m")
      assert result.name == "meter"
      assert_in_delta result.value, 7, 0.001
    end

    test "parenthesized juxtaposition" do
      {result, _env} = eval!("(3 + 4) m")
      assert result.name == "meter"
      assert_in_delta result.value, 7, 0.001
    end
  end

  describe "mixed-unit decomposition" do
    test "hours to h;min;s" do
      {result, _env} = eval!("3.756 hours to h;min;s")
      assert {:decomposed, parts} = result
      assert length(parts) == 3

      [hours, minutes, seconds] = parts
      assert hours.name == "hour"
      assert hours.value == 3
      assert minutes.name == "minute"
      assert minutes.value == 45
      assert_in_delta seconds.value, 21.6, 0.1
    end

    test "formats mixed-unit result" do
      {result, _env} = eval!("3.756 hours to h;min;s")
      assert {:ok, formatted} = Units.Formatter.format(result)
      assert formatted =~ "hour"
      assert formatted =~ "minute"
      assert formatted =~ "second"
    end
  end

  describe "error handling" do
    test "unknown unit" do
      message = eval_error("3 frobnicators")
      assert message =~ "unknown unit"
      assert message =~ "frobnicator"
    end

    test "unknown unit with suggestion" do
      message = eval_error("3 meterz")
      assert message =~ "unknown unit"
      assert message =~ "Did you mean"
    end
  end
end
