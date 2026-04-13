defmodule Unity.LocalizeUnitExerciseTest do
  @moduledoc """
  Exercises Localize.Unit creation, conversion, math, and formatting
  for both standard CLDR units and custom units imported from the
  GNU units definition file.

  These tests verify the full pipeline end-to-end: define → create →
  convert → math → format.

  """

  use ExUnit.Case, async: false

  @moduletag :integration

  alias Localize.Unit
  alias Localize.Unit.Math
  alias Localize.Unit.CustomRegistry

  setup_all do
    CustomRegistry.clear()

    # Load GNU units from the bundled definitions file
    path = Application.app_dir(:unity, "priv/definitions.units")
    {:ok, _stats} = Unity.GnuUnitsImporter.import(path)

    on_exit(fn -> CustomRegistry.clear() end)
    :ok
  end

  # ══════════════════════════════════════════════════════════════════
  # Part 1: CLDR standard units — creation, conversion, math
  # ══════════════════════════════════════════════════════════════════

  describe "CLDR unit creation" do
    test "creates simple units" do
      assert {:ok, u} = Unit.new(100, "meter")
      assert u.value == 100
      assert u.name == "meter"
    end

    test "creates SI-prefixed units" do
      assert {:ok, u} = Unit.new(5, "kilometer")
      assert u.name == "kilometer"
    end

    test "creates compound units" do
      assert {:ok, u} = Unit.new(60, "mile-per-hour")
      assert u.name == "mile-per-hour"
    end

    test "creates power-prefixed units" do
      assert {:ok, u} = Unit.new(100, "square-meter")
      assert u.name == "square-meter"
    end
  end

  describe "CLDR unit conversion" do
    test "length: meters to feet" do
      {:ok, u} = Unit.new(1, "meter")
      {:ok, result} = Unit.convert(u, "foot")
      assert_in_delta result.value, 3.28084, 0.001
    end

    test "length: miles to kilometers" do
      {:ok, u} = Unit.new(1, "mile")
      {:ok, result} = Unit.convert(u, "kilometer")
      assert_in_delta result.value, 1.60934, 0.001
    end

    test "mass: kilograms to pounds" do
      {:ok, u} = Unit.new(1, "kilogram")
      {:ok, result} = Unit.convert(u, "pound")
      assert_in_delta result.value, 2.20462, 0.001
    end

    test "temperature: celsius to fahrenheit" do
      {:ok, u} = Unit.new(100, "celsius")
      {:ok, result} = Unit.convert(u, "fahrenheit")
      assert_in_delta result.value, 212.0, 0.01
    end

    test "volume: liters to gallons" do
      {:ok, u} = Unit.new(1, "liter")
      {:ok, result} = Unit.convert(u, "gallon")
      assert_in_delta result.value, 0.264172, 0.001
    end

    test "speed: km/h to m/s" do
      {:ok, u} = Unit.new(100, "kilometer-per-hour")
      {:ok, result} = Unit.convert(u, "meter-per-second")
      assert_in_delta result.value, 27.7778, 0.01
    end

    test "area: hectare to acre" do
      {:ok, u} = Unit.new(1, "hectare")
      {:ok, result} = Unit.convert(u, "acre")
      assert_in_delta result.value, 2.47105, 0.001
    end
  end

  describe "CLDR unit math" do
    test "add conformable units" do
      a = Unit.new!(1, "kilometer")
      b = Unit.new!(500, "meter")
      {:ok, result} = Math.add(a, b)
      assert result.name == "kilometer"
      assert_in_delta result.value, 1.5, 0.001
    end

    test "subtract conformable units" do
      a = Unit.new!(10, "kilogram")
      b = Unit.new!(3000, "gram")
      {:ok, result} = Math.sub(a, b)
      assert result.name == "kilogram"
      assert_in_delta result.value, 7.0, 0.001
    end

    test "multiply unit by scalar" do
      u = Unit.new!(5, "meter")
      {:ok, result} = Math.mult(u, 3)
      assert result.value == 15
      assert result.name == "meter"
    end

    test "multiply two units produces compound" do
      a = Unit.new!(10, "meter")
      b = Unit.new!(5, "second")
      {:ok, result} = Math.mult(a, b)
      assert result.name == "meter-second"
      assert result.value == 50
    end

    test "divide units produces per-unit" do
      a = Unit.new!(100, "meter")
      b = Unit.new!(10, "second")
      {:ok, result} = Math.div(a, b)
      assert result.name == "meter-per-second"
      assert_in_delta result.value, 10.0, 0.001
    end

    test "divide same units produces dimensionless scalar" do
      a = Unit.new!(6, "meter")
      b = Unit.new!(3, "meter")
      {:ok, result} = Math.div(a, b)
      # When all dimensions cancel, result is a bare number
      assert result == 2.0
    end

    test "negate unit" do
      u = Unit.new!(5, "meter")
      {:ok, result} = Math.negate(u)
      assert result.value == -5
    end

    test "invert unit" do
      u = Unit.new!(4, "meter-per-second")
      {:ok, result} = Math.invert(u)
      assert result.name == "second-per-meter"
      assert_in_delta result.value, 0.25, 0.001
    end

    test "abs of negative unit" do
      u = Unit.new!(-7, "kilogram")
      {:ok, result} = Math.abs(u)
      assert result.value == 7
    end

    test "round unit value" do
      u = Unit.new!(3.7, "meter")
      {:ok, result} = Math.round(u)
      assert result.value == 4
    end

    test "ceil unit value" do
      u = Unit.new!(3.2, "meter")
      {:ok, result} = Math.ceil(u)
      assert result.value == 4
    end

    test "floor unit value" do
      u = Unit.new!(3.7, "meter")
      {:ok, result} = Math.floor(u)
      assert result.value == 3
    end

    test "sqrt of square unit" do
      u = Unit.new!(9, "square-meter")
      {:ok, result} = Math.sqrt(u)
      assert result.name == "meter"
      assert_in_delta result.value, 3.0, 0.001
    end

    test "cbrt of cubic unit" do
      u = Unit.new!(27, "cubic-meter")
      {:ok, result} = Math.cbrt(u)
      assert result.name == "meter"
      assert_in_delta result.value, 3.0, 0.001
    end

    test "sqrt fails on odd-power unit" do
      u = Unit.new!(8, "cubic-meter")
      assert {:error, _} = Math.sqrt(u)
    end
  end

  describe "CLDR unit formatting" do
    test "formats in English" do
      {:ok, u} = Unit.new(3, "meter")
      {:ok, formatted} = Unit.to_string(u, locale: :en)
      assert formatted =~ "meter"
    end

    test "formats plural form" do
      {:ok, u} = Unit.new(5, "kilometer")
      {:ok, formatted} = Unit.to_string(u, locale: :en)
      assert formatted =~ "kilometer"
    end

    test "formats singular form" do
      {:ok, u} = Unit.new(1, "kilometer")
      {:ok, formatted} = Unit.to_string(u, locale: :en)
      assert formatted =~ "kilometer"
    end

    test "formats in German" do
      {:ok, u} = Unit.new(5, "kilometer")
      {:ok, formatted} = Unit.to_string(u, locale: :de)
      assert formatted =~ "Kilometer"
    end

    test "formats in short style" do
      {:ok, u} = Unit.new(5, "kilometer")
      {:ok, formatted} = Unit.to_string(u, locale: :en, format: :short)
      assert formatted =~ "km"
    end
  end

  # ══════════════════════════════════════════════════════════════════
  # Part 2: Custom units from GNU definitions — full lifecycle
  # ══════════════════════════════════════════════════════════════════

  describe "GNU custom unit creation" do
    test "creates a length unit" do
      assert {:ok, u} = Unit.new(1, "league")
      assert u.name == "league"
      assert u.value == 1
    end

    test "creates a force unit" do
      assert {:ok, u} = Unit.new(100, "dyne")
      assert u.name == "dyne"
    end

    test "creates an energy unit" do
      assert {:ok, u} = Unit.new(1, "btu")
      assert u.name == "btu"
    end

    test "creates a pressure unit" do
      assert {:ok, u} = Unit.new(760, "torr")
      assert u.name == "torr"
    end

    test "creates a duration unit" do
      assert {:ok, u} = Unit.new(1, "jiffy")
      assert u.name == "jiffy"
    end
  end

  describe "GNU custom unit conversion" do
    test "league to meter" do
      {:ok, u} = Unit.new(1, "league")
      {:ok, result} = Unit.convert(u, "meter")
      assert result.name == "meter"
      assert_in_delta result.value, 4828.032, 0.01
    end

    test "league to mile" do
      {:ok, u} = Unit.new(1, "league")
      {:ok, result} = Unit.convert(u, "mile")
      assert result.name == "mile"
      assert_in_delta result.value, 3.0, 0.001
    end

    test "dyne to newton" do
      {:ok, u} = Unit.new(100_000, "dyne")
      {:ok, result} = Unit.convert(u, "newton")
      assert result.name == "newton"
      assert_in_delta result.value, 1.0, 0.001
    end

    test "torr to pascal" do
      {:ok, u} = Unit.new(760, "torr")
      {:ok, result} = Unit.convert(u, "pascal")
      assert result.name == "pascal"
      assert_in_delta result.value, 101_325.0, 1.0
    end

    test "btu to joule" do
      {:ok, u} = Unit.new(1, "btu")
      {:ok, result} = Unit.convert(u, "joule")
      assert result.name == "joule"
      assert_in_delta result.value, 1055.056, 0.1
    end

    test "mach to meter per second" do
      {:ok, u} = Unit.new(1, "mach")
      {:ok, result} = Unit.convert(u, "meter-per-second")
      assert result.name == "meter-per-second"
      assert_in_delta result.value, 331.46, 0.1
    end

    test "jiffy to second" do
      {:ok, u} = Unit.new(100, "jiffy")
      {:ok, result} = Unit.convert(u, "second")
      assert result.name == "second"
      assert_in_delta result.value, 1.0, 0.001
    end

    test "custom unit to another custom unit" do
      {:ok, u} = Unit.new(1, "sthene")
      {:ok, result} = Unit.convert(u, "dyne")
      assert result.name == "dyne"
      assert_in_delta result.value, 1.0e8, 1000
    end

    test "custom unit to CLDR unit" do
      {:ok, u} = Unit.new(1, "ell")
      {:ok, result} = Unit.convert(u, "foot")
      assert result.name == "foot"
      assert_in_delta result.value, 3.75, 0.01
    end

    test "CLDR unit to custom unit" do
      {:ok, u} = Unit.new(1, "meter")
      {:ok, result} = Unit.convert(u, "ell")
      assert result.name == "ell"
      assert_in_delta result.value, 0.875, 0.01
    end
  end

  describe "GNU custom unit math" do
    test "add two custom length units" do
      a = Unit.new!(1, "league")
      b = Unit.new!(1, "ell")
      {:ok, result} = Math.add(a, b)
      assert result.name == "league"
      assert_in_delta result.value, 1.000237, 0.001
    end

    test "add custom and CLDR units" do
      a = Unit.new!(1, "league")
      b = Unit.new!(1000, "meter")
      {:ok, result} = Math.add(a, b)
      assert result.name == "league"
      assert_in_delta result.value, 1.2072, 0.001
    end

    test "multiply custom unit by scalar" do
      u = Unit.new!(5, "dyne")
      {:ok, result} = Math.mult(u, 10)
      assert result.value == 50
      assert result.name == "dyne"
    end

    test "divide custom unit by scalar" do
      u = Unit.new!(100, "torr")
      {:ok, result} = Math.div(u, 4)
      assert_in_delta result.value, 25.0, 0.001
      assert result.name == "torr"
    end

    test "negate custom unit" do
      u = Unit.new!(5, "btu")
      {:ok, result} = Math.negate(u)
      assert result.value == -5
    end

    test "abs of negative custom unit" do
      u = Unit.new!(-100, "dyne")
      {:ok, result} = Math.abs(u)
      assert result.value == 100
    end

    test "round custom unit" do
      u = Unit.new!(3.7, "torr")
      {:ok, result} = Math.round(u)
      assert result.value == 4
    end

    test "ceil custom unit" do
      u = Unit.new!(3.2, "jiffy")
      {:ok, result} = Math.ceil(u)
      assert result.value == 4
    end

    test "floor custom unit" do
      u = Unit.new!(3.7, "jiffy")
      {:ok, result} = Math.floor(u)
      assert result.value == 3
    end
  end

  describe "GNU custom unit formatting" do
    test "formats custom unit with display data" do
      {:ok, u} = Unit.new(5, "league")
      {:ok, formatted} = Unit.to_string(u, locale: :en)
      assert formatted =~ "league"
    end

    test "formats singular custom unit" do
      {:ok, u} = Unit.new(1, "league")
      {:ok, formatted} = Unit.to_string(u, locale: :en)
      assert formatted =~ "league"
      refute formatted =~ "leagues"
    end

    test "formats plural custom unit" do
      {:ok, u} = Unit.new(5, "league")
      {:ok, formatted} = Unit.to_string(u, locale: :en)
      assert formatted =~ "leagues"
    end

    test "formats custom unit with max_fractional_digits" do
      {:ok, u} = Unit.new(3.14159, "dyne")
      {:ok, formatted} = Unit.to_string(u, locale: :en, max_fractional_digits: 2)
      assert formatted =~ "3.14"
    end
  end

  # ══════════════════════════════════════════════════════════════════
  # Part 3: Multi-step operations mixing CLDR and custom units
  # ══════════════════════════════════════════════════════════════════

  describe "multi-step operations" do
    test "convert chain: custom → CLDR → custom" do
      # league → meter → ell
      {:ok, u} = Unit.new(1, "league")
      {:ok, meters} = Unit.convert(u, "meter")
      {:ok, ells} = Unit.convert(meters, "ell")
      assert ells.name == "ell"
      assert_in_delta ells.value, 4224.0, 1.0
    end

    test "arithmetic then convert" do
      a = Unit.new!(500, "torr")
      b = Unit.new!(260, "torr")
      {:ok, sum} = Math.add(a, b)
      {:ok, result} = Unit.convert(sum, "pascal")
      assert result.name == "pascal"
      assert_in_delta result.value, 101_325.0, 1.0
    end

    test "convert then arithmetic" do
      {:ok, u1} = Unit.new(1, "league")
      {:ok, u1_m} = Unit.convert(u1, "meter")
      u2 = Unit.new!(172, "meter")
      {:ok, total} = Math.add(u1_m, u2)
      {:ok, in_km} = Unit.convert(total, "kilometer")
      assert_in_delta in_km.value, 5.0, 0.01
    end

    test "multiply then convert compound" do
      mass = Unit.new!(100, "kilogram")
      accel = Unit.new!(9.80665, "meter-per-square-second")
      {:ok, force} = Math.mult(mass, accel)
      {:ok, in_dyne} = Unit.convert(force, "dyne")
      assert_in_delta in_dyne.value, 98_066_500, 100
    end
  end

  # ══════════════════════════════════════════════════════════════════
  # Part 4: Through the Unity expression evaluator
  # ══════════════════════════════════════════════════════════════════

  describe "Unity.eval with custom units" do
    test "simple conversion expression" do
      {:ok, result, _env} = Unity.eval("1 league to meter")
      assert_in_delta result.value, 4828.032, 0.01
    end

    test "arithmetic with custom units" do
      {:ok, result, _env} = Unity.eval("500 torr + 260 torr")
      assert result.name == "torr"
      assert_in_delta result.value, 760.0, 0.001
    end

    test "mixed CLDR and custom in arithmetic" do
      {:ok, result, _env} = Unity.eval("1 league + 1000 meter")
      assert result.name == "league"
    end

    test "custom unit in multiplication" do
      {:ok, result, _env} = Unity.eval("5 dyne * 3")
      assert result.name == "dyne"
      assert_in_delta result.value, 15.0, 0.001
    end

    test "custom unit conversion via eval" do
      {:ok, result, _env} = Unity.eval("100000 dyne to newton")
      assert_in_delta result.value, 1.0, 0.001
    end

    test "format custom unit result" do
      result = Unity.eval!("5 league")
      {:ok, formatted} = Unity.format(result)
      assert formatted =~ "league"
    end
  end

  # ══════════════════════════════════════════════════════════════════
  # Part 5: Edge cases and error handling
  # ══════════════════════════════════════════════════════════════════

  describe "error handling" do
    test "cannot convert between incompatible custom units" do
      {:ok, u} = Unit.new(1, "league")
      assert {:error, _} = Unit.convert(u, "torr")
    end

    test "cannot add incompatible custom units" do
      a = Unit.new!(1, "league")
      b = Unit.new!(1, "torr")
      assert {:error, _} = Math.add(a, b)
    end

    test "unknown custom unit returns error" do
      assert {:error, _} = Unit.new(1, "nonexistent_custom")
    end

    test "zero-valued custom unit works" do
      {:ok, u} = Unit.new(0, "league")
      assert u.value == 0
      {:ok, result} = Unit.convert(u, "meter")
      assert result.value == 0.0
    end

    test "negative custom unit converts correctly" do
      {:ok, u} = Unit.new(-5, "dyne")
      {:ok, result} = Unit.convert(u, "newton")
      assert result.value < 0
    end
  end
end
