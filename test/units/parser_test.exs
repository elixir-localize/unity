defmodule Units.ParserTest do
  use ExUnit.Case, async: true

  alias Units.Parser

  describe "number literals" do
    test "integer" do
      assert {:ok, {:number, 42}} = Parser.parse("42")
    end

    test "negative integer" do
      assert {:ok, {:number, -5}} = Parser.parse("-5")
    end

    test "float" do
      assert {:ok, {:number, 3.14}} = Parser.parse("3.14")
    end

    test "negative float" do
      assert {:ok, {:number, -2.5}} = Parser.parse("-2.5")
    end

    test "scientific notation" do
      assert {:ok, {:number, 314.0}} = Parser.parse("3.14e2")
    end

    test "scientific notation with negative exponent" do
      assert {:ok, {:number, 0.00314}} = Parser.parse("3.14e-3")
    end

    test "rational number" do
      assert {:ok, {:quantity, value, {:unit_name, "cup"}}} = Parser.parse("1|3 cup")
      assert_in_delta value, 1 / 3, 1.0e-10
    end

    test "rational number with zero denominator" do
      assert {:ok, {:error, :division_by_zero}} = Parser.parse("1|0")
    end
  end

  describe "unit names" do
    test "simple unit name" do
      assert {:ok, {:unit_name, "meters"}} = Parser.parse("meters")
    end

    test "unit name with hyphen" do
      assert {:ok, {:unit_name, "mile-per-hour"}} = Parser.parse("mile-per-hour")
    end

    test "concatenated exponent" do
      assert {:ok, {:power, {:unit_name, "cm"}, {:number, 3}}} = Parser.parse("cm3")
    end

    test "concatenated exponent on known unit" do
      assert {:ok, {:power, {:unit_name, "m"}, {:number, 2}}} = Parser.parse("m2")
    end
  end

  describe "quantities" do
    test "integer quantity" do
      assert {:ok, {:quantity, 3, {:unit_name, "meters"}}} = Parser.parse("3 meters")
    end

    test "float quantity" do
      assert {:ok, {:quantity, 3.5, {:unit_name, "km"}}} = Parser.parse("3.5 km")
    end

    test "negative quantity" do
      assert {:ok, {:quantity, -5, {:unit_name, "m"}}} = Parser.parse("-5 m")
    end

    test "quantity with no space" do
      assert {:ok, {:quantity, 100, {:unit_name, "kg"}}} = Parser.parse("100 kg")
    end
  end

  describe "conversion" do
    test "to keyword" do
      assert {:ok, {:convert, {:quantity, 3, {:unit_name, "meters"}}, {:unit_name, "feet"}}} =
               Parser.parse("3 meters to feet")
    end

    test "in keyword" do
      assert {:ok, {:convert, {:quantity, 3, {:unit_name, "meters"}}, {:unit_name, "feet"}}} =
               Parser.parse("3 meters in feet")
    end

    test "arrow operator" do
      assert {:ok, {:convert, {:quantity, 3, {:unit_name, "m"}}, {:unit_name, "cm"}}} =
               Parser.parse("3 m -> cm")
    end
  end

  describe "arithmetic" do
    test "addition" do
      assert {:ok, {:add, {:quantity, 3, {:unit_name, "m"}}, {:quantity, 5, {:unit_name, "m"}}}} =
               Parser.parse("3 m + 5 m")
    end

    test "subtraction" do
      assert {:ok, {:sub, {:quantity, 10, {:unit_name, "m"}}, {:quantity, 3, {:unit_name, "m"}}}} =
               Parser.parse("10 m - 3 m")
    end

    test "multiplication" do
      assert {:ok,
              {:mult, {:quantity, 100, {:unit_name, "kg"}}, {:quantity, 9.8, {:unit_name, "m"}}}} =
               Parser.parse("100 kg * 9.8 m")
    end

    test "division" do
      assert {:ok,
              {:div, {:quantity, 100, {:unit_name, "m"}}, {:quantity, 10, {:unit_name, "s"}}}} =
               Parser.parse("100 m / 10 s")
    end

    test "per keyword" do
      assert {:ok, {:div, {:quantity, 5, {:unit_name, "miles"}}, {:unit_name, "hour"}}} =
               Parser.parse("5 miles per hour")
    end

    test "exponentiation" do
      assert {:ok, {:power, {:unit_name, "s"}, {:number, 2}}} = Parser.parse("s^2")
    end

    test "negative exponent" do
      assert {:ok, {:power, {:unit_name, "s"}, {:number, -2}}} = Parser.parse("s^-2")
    end
  end

  describe "operator precedence" do
    test "multiplication before addition" do
      # 3 m + 2 m * 4 should parse as 3 m + (2 m * 4)
      # But actually at the term level: * binds tighter than +
      assert {:ok,
              {:add, {:quantity, 3, {:unit_name, "m"}},
               {:mult, {:quantity, 2, {:unit_name, "m"}}, {:number, 4}}}} =
               Parser.parse("3 m + 2 m * 4")
    end

    test "division in compound unit" do
      # 100 kg * 9.8 m / s^2
      assert {:ok, ast} = Parser.parse("100 kg * 9.8 m / s^2")

      assert {:div,
              {:mult, {:quantity, 100, {:unit_name, "kg"}}, {:quantity, 9.8, {:unit_name, "m"}}},
              {:power, {:unit_name, "s"}, {:number, 2}}} = ast
    end

    test "conversion is outermost" do
      assert {:ok, {:convert, {:add, left, right}, target}} =
               Parser.parse("12 ft + 3 in to ft")

      assert {:quantity, 12, {:unit_name, "ft"}} = left
      assert {:quantity, 3, {:unit_name, "in"}} = right
      assert {:unit_name, "ft"} = target
    end
  end

  describe "parentheses" do
    test "parenthesized arithmetic" do
      assert {:ok, {:add, {:number, 3}, {:number, 4}}} =
               Parser.parse("(3 + 4)")
    end

    test "parenthesized expression with explicit multiplication" do
      assert {:ok, {:mult, {:add, {:number, 3}, {:number, 4}}, {:unit_name, "m"}}} =
               Parser.parse("(3 + 4) * m")
    end
  end

  describe "function calls" do
    test "sqrt" do
      assert {:ok, {:function, "sqrt", [arg]}} = Parser.parse("sqrt(9)")
      assert {:number, 9} = arg
    end

    test "sqrt with unit expression" do
      assert {:ok, {:function, "sqrt", [arg]}} = Parser.parse("sqrt(9 m^2)")
      assert {:power, {:quantity, 9, {:unit_name, "m"}}, {:number, 2}} = arg
    end

    test "abs" do
      assert {:ok, {:function, "abs", [{:quantity, -5, {:unit_name, "m"}}]}} =
               Parser.parse("abs(-5 m)")
    end
  end

  describe "let bindings" do
    test "simple let binding" do
      assert {:ok, {:let, "x", {:quantity, 3, {:unit_name, "m"}}}} =
               Parser.parse("let x = 3 m")
    end
  end

  describe "parse errors" do
    test "returns error for empty input" do
      assert {:error, _message} = Parser.parse("")
    end

    test "parse! raises on invalid input" do
      assert_raise ArgumentError, fn ->
        Parser.parse!("")
      end
    end
  end
end
