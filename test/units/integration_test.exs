defmodule Units.IntegrationTest do
  use ExUnit.Case, async: true

  describe "eval/1" do
    test "simple conversion" do
      {:ok, result, _env} = Units.eval("3 meters to feet")
      assert result.name == "foot"
      assert_in_delta result.value, 9.84252, 0.001
    end

    test "complex expression" do
      {:ok, result, _env} = Units.eval("100 kg * 9.8 m/s^2")
      assert result.name == "kilogram-meter-per-square-second"
      assert_in_delta result.value, 980, 0.001
    end

    test "parse error" do
      assert {:error, _message} = Units.eval("")
    end
  end

  describe "eval!/1" do
    test "returns result on success" do
      result = Units.eval!("1 km to m")
      assert result.name == "meter"
      assert_in_delta result.value, 1000, 0.001
    end

    test "raises on failure" do
      assert_raise ArgumentError, fn ->
        Units.eval!("")
      end
    end
  end

  describe "format/2" do
    test "formats a unit" do
      result = Units.eval!("3 meters")
      assert {:ok, formatted} = Units.format(result)
      assert formatted =~ "meter"
    end

    test "formats a number" do
      result = Units.eval!("3 + 4")
      assert {:ok, "7"} = Units.format(result)
    end

    test "verbose format" do
      result = Units.eval!("3 meters to feet")
      assert {:ok, formatted} = Units.format(result, format: :verbose, input: "3 meters to feet")
      assert formatted =~ "3 meters to feet ="
      assert formatted =~ "feet"
    end

    test "terse format" do
      result = Units.eval!("3 meters to feet")
      assert {:ok, formatted} = Units.format(result, format: :terse)
      assert formatted =~ "9"
      refute formatted =~ "feet"
    end
  end

  describe "full expression pipeline examples from plan" do
    test "3 meters to feet" do
      {:ok, result, _env} = Units.eval("3 meters to feet")
      assert_in_delta result.value, 9.84252, 0.001
    end

    test "60 mph to km/h" do
      {:ok, result, _env} = Units.eval("60 mph to km/h")
      assert_in_delta result.value, 96.5606, 0.001
    end

    test "100 kg * 9.8 m/s^2" do
      {:ok, result, _env} = Units.eval("100 kg * 9.8 m/s^2")
      assert_in_delta result.value, 980, 0.001
    end

    test "1 gallon to liters" do
      {:ok, result, _env} = Units.eval("1 gallon to liters")
      assert_in_delta result.value, 3.78541, 0.001
    end

    test "12 ft + 3 in" do
      {:ok, result, _env} = Units.eval("12 ft + 3 in")
      assert_in_delta result.value, 12.25, 0.001
    end

    test "12 ft + 3 in to ft" do
      {:ok, result, _env} = Units.eval("12 ft + 3 in to ft")
      assert_in_delta result.value, 12.25, 0.001
    end

    test "sqrt(9 m^2)" do
      {:ok, result, _env} = Units.eval("sqrt(9 m^2)")
      assert result.name == "meter"
      assert_in_delta result.value, 3.0, 0.001
    end

    test "1|3 cup to mL" do
      {:ok, result, _env} = Units.eval("1|3 cup to mL")
      assert_in_delta result.value, 78.8627, 0.01
    end

    test "100 celsius to fahrenheit" do
      {:ok, result, _env} = Units.eval("100 celsius to fahrenheit")
      assert_in_delta result.value, 212, 0.001
    end

    test "5 miles per hour to m/s" do
      {:ok, result, _env} = Units.eval("5 miles per hour to m/s")
      assert result.name == "meter-per-second"
      assert_in_delta result.value, 2.2352, 0.001
    end
  end

  describe "juxtaposition multiplication" do
    test "kg m / s^2 as force" do
      {:ok, result, _env} = Units.eval("100 kg m / s^2")
      assert result.name == "kilogram-meter-per-square-second"
      assert_in_delta result.value, 100, 0.001
    end

    test "(3 + 4) m evaluates" do
      {:ok, result, _env} = Units.eval("(3 + 4) m")
      assert result.name == "meter"
      assert_in_delta result.value, 7, 0.001
    end
  end

  describe "variables and environment chaining" do
    test "let binding and reuse" do
      {:ok, _result, env} = Units.eval("let distance = 42.195 km")
      assert %Localize.Unit{name: "kilometer"} = env["distance"]
    end

    test "let and reference across evals" do
      {:ok, _, env} = Units.eval("let distance = 42.195 km")
      {:ok, _, env} = Units.eval("let time = 2 hours", env)
      {:ok, result, _env} = Units.eval("distance / time", env)
      assert result.name == "kilometer-per-hour"
      assert_in_delta result.value, 21.0975, 0.001
    end

    test "underscore as previous result" do
      {:ok, result, env} = Units.eval("10 meters")
      env = Map.put(env, "_", result)
      {:ok, result2, _env} = Units.eval("_ to cm", env)
      assert result2.name == "centimeter"
      assert_in_delta result2.value, 1000, 0.001
    end
  end

  describe "mixed-unit display" do
    test "3.756 hours to h;min;s" do
      {:ok, result, _env} = Units.eval("3.756 hours to h;min;s")
      assert {:decomposed, parts} = result
      assert length(parts) == 3
      {:ok, formatted} = Units.format(result)
      assert formatted =~ "hour"
      assert formatted =~ "minute"
      assert formatted =~ "second"
    end

    test "1.5 hours to h;min" do
      {:ok, result, _env} = Units.eval("1.5 hours to h;min")
      assert {:decomposed, [hours, minutes]} = result
      assert hours.value == 1
      assert minutes.value == 30
    end
  end

  describe "locale-aware formatting" do
    test "German locale" do
      result = Units.eval!("1234.5 meter to kilometer")
      Localize.put_locale(:de)
      {:ok, formatted} = Units.format(result)
      # German uses comma as decimal separator
      assert formatted =~ ","
      Localize.put_locale(:en)
    end

    test "Japanese locale" do
      result = Units.eval!("1 kilometer")
      Localize.put_locale(:ja)
      {:ok, formatted} = Units.format(result)
      assert formatted =~ "キロメートル"
      Localize.put_locale(:en)
    end

    test "format with explicit locale option" do
      result = Units.eval!("1234.5 meter to kilometer")
      {:ok, formatted} = Units.format(result, locale: :de)
      assert formatted =~ ","
    end
  end

  describe "aliases" do
    test "common abbreviations resolve" do
      assert {:ok, "meter"} = Units.Aliases.resolve("m")
      assert {:ok, "kilometer"} = Units.Aliases.resolve("km")
      assert {:ok, "foot"} = Units.Aliases.resolve("ft")
      assert {:ok, "mile-per-hour"} = Units.Aliases.resolve("mph")
      assert {:ok, "kilogram"} = Units.Aliases.resolve("kg")
      assert {:ok, "liter"} = Units.Aliases.resolve("L")
      assert {:ok, "celsius"} = Units.Aliases.resolve("°C")
    end

    test "CLDR names pass through" do
      assert {:ok, "meter"} = Units.Aliases.resolve("meter")
      assert {:ok, "kilogram"} = Units.Aliases.resolve("kilogram")
      assert {:ok, "second"} = Units.Aliases.resolve("second")
    end

    test "unknown unit returns error" do
      assert {:error, :unknown_unit} = Units.Aliases.resolve("frobnicator")
    end

    test "suggest returns similar names" do
      suggestions = Units.Aliases.suggest("metrs")
      names = Enum.map(suggestions, &elem(&1, 0))
      assert "meters" in names or "meter" in names
    end
  end

  describe "error formatting" do
    test "unknown unit error" do
      formatted = Units.Error.format("unknown unit: \"frobnicator\"")
      assert formatted =~ "Unknown unit"
    end

    test "parse error" do
      formatted = Units.Error.format("parse error: expected expression")
      assert formatted =~ "Parse error"
    end

    test "conformability error" do
      formatted = Units.Error.format("cannot add: incompatible units")
      assert formatted =~ "Cannot add"
    end
  end
end
