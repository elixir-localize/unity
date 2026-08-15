defmodule Unity.AliasesTest do
  use ExUnit.Case, async: true

  # `Unity.Aliases` is already doctested from `unity_test.exs`; declaring it
  # here too would run every one of its doctests twice.
  doctest Unity.Aliases.Plural

  alias Unity.Aliases
  alias Unity.Aliases.Plural

  describe "plural resolution" do
    test "resolves the plural of every calendar unit" do
      # `months` was the reported gap: `month` resolved, `months` did not.
      for {plural, singular} <- [
            {"seconds", "second"},
            {"minutes", "minute"},
            {"hours", "hour"},
            {"days", "day"},
            {"weeks", "week"},
            {"fortnights", "fortnight"},
            {"months", "month"},
            {"quarters", "quarter"},
            {"years", "year"},
            {"decades", "decade"},
            {"centuries", "century"},
            {"nights", "night"}
          ] do
        assert Aliases.resolve(plural) == {:ok, singular}
      end
    end

    test "resolves the plural of the -person duration variants" do
      assert Aliases.resolve("days-person") == {:ok, "day-person"}
      assert Aliases.resolve("weeks-person") == {:ok, "week-person"}
      assert Aliases.resolve("months-person") == {:ok, "month-person"}
      assert Aliases.resolve("years-person") == {:ok, "year-person"}
    end

    test "every known CLDR unit resolves in both singular and plural" do
      # The guarantee the derived table exists to provide. Written as a sweep
      # over the unit list rather than a fixed set of examples so that a unit
      # added to CLDR is covered without editing this test.
      asymmetric =
        for cldr_name <- Aliases.all_known_names(),
            plural <- Plural.plural(cldr_name),
            Aliases.resolve(plural) != {:ok, cldr_name} do
          {cldr_name, plural, Aliases.resolve(plural)}
        end

      assert asymmetric == []
    end

    test "pluralises the head noun of a hyphenated name, not a qualifier" do
      assert Aliases.resolve("light-years") == {:ok, "light-year"}
      assert Aliases.resolve("nautical-miles") == {:ok, "nautical-mile"}
      assert Aliases.resolve("fluid-ounces") == {:ok, "fluid-ounce"}
      assert Aliases.resolve("fluid-ounces-imperial") == {:ok, "fluid-ounce-imperial"}
      assert Aliases.resolve("british-thermal-units-it") == {:ok, "british-thermal-unit-it"}
      assert Aliases.resolve("cups-jp") == {:ok, "cup-jp"}
      assert Aliases.resolve("therms-us") == {:ok, "therm-us"}
      assert Aliases.resolve("ounces-troy") == {:ok, "ounce-troy"}
    end

    test "applies -es, -ies and irregular plurals" do
      assert Aliases.resolve("inches") == {:ok, "inch"}
      assert Aliases.resolve("pinches") == {:ok, "pinch"}
      assert Aliases.resolve("earth-masses") == {:ok, "earth-mass"}
      assert Aliases.resolve("centuries") == {:ok, "century"}
      assert Aliases.resolve("henries") == {:ok, "henry"}
      assert Aliases.resolve("feet") == {:ok, "foot"}
      assert Aliases.resolve("solar-radii") == {:ok, "solar-radius"}
    end

    test "keeps a -y preceded by a vowel regular" do
      assert Aliases.resolve("days") == {:ok, "day"}
      assert Aliases.resolve("grays") == {:ok, "gray"}
    end

    test "units whose plural equals their singular still resolve" do
      assert Aliases.resolve("hertz") == {:ok, "hertz"}
      assert Aliases.resolve("siemens") == {:ok, "siemens"}
      assert Aliases.resolve("lux") == {:ok, "lux"}
    end
  end

  describe "SI-prefixed and respelled forms" do
    test "resolves the plural of an SI-prefixed unit" do
      # Not in the derived table — prefix x unit is too large to enumerate, so
      # these are normalised at resolution time.
      assert Aliases.resolve("milliseconds") == {:ok, "millisecond"}
      assert Aliases.resolve("microseconds") == {:ok, "microsecond"}
      assert Aliases.resolve("kilojoules") == {:ok, "kilojoule"}
      assert Aliases.resolve("megabytes") == {:ok, "megabyte"}
      assert Aliases.resolve("kilowatts") == {:ok, "kilowatt"}
      assert Aliases.resolve("milligrams") == {:ok, "milligram"}
    end

    test "resolves British spellings in both singular and plural" do
      # Before this, only the plurals were listed: `kilometres` resolved but
      # `kilometre` did not, and neither `metre` nor `metres` did.
      assert Aliases.resolve("metre") == {:ok, "meter"}
      assert Aliases.resolve("metres") == {:ok, "meter"}
      assert Aliases.resolve("kilometre") == {:ok, "kilometer"}
      assert Aliases.resolve("kilometres") == {:ok, "kilometer"}
      assert Aliases.resolve("centimetre") == {:ok, "centimeter"}
      assert Aliases.resolve("millimetres") == {:ok, "millimeter"}
      assert Aliases.resolve("litre") == {:ok, "liter"}
      assert Aliases.resolve("litres") == {:ok, "liter"}
      assert Aliases.resolve("millilitres") == {:ok, "milliliter"}
    end
  end

  describe "resolution does not over-reach" do
    test "an ordinary English word is not promoted to a unit" do
      # The reason resolution proposes candidate spellings and confirms each
      # one, rather than stripping a trailing `s` and retrying.
      for word <- ~w(bricks hotels widgets frobnicators tables invoices sessions) do
        assert Aliases.resolve(word) == {:error, :unknown_unit}
      end
    end

    test "a derived plural never displaces a real unit or a hand-written alias" do
      for cldr_name <- Aliases.all_known_names() do
        assert Aliases.resolve(cldr_name) == {:ok, cldr_name}
      end

      for {alias_name, expected} <- [
            {"m", "meter"},
            {"s", "second"},
            {"t", "tonne"},
            {"c", "light-speed"},
            {"lbs", "pound"},
            {"mins", "minute"},
            {"hrs", "hour"},
            {"secs", "second"},
            {"yrs", "year"}
          ] do
        assert Aliases.resolve(alias_name) == {:ok, expected}
      end
    end

    test "every reported alias resolves" do
      unresolved =
        for name <- Aliases.known_aliases(), match?({:error, _}, Aliases.resolve(name)), do: name

      assert unresolved == []
    end

    test "does not raise on empty or non-string input" do
      assert Aliases.resolve("") == {:error, :unknown_unit}
      assert Aliases.resolve(nil) == {:error, :unknown_unit}
      assert Aliases.resolve(:month) == {:error, :unknown_unit}
      assert Aliases.resolve(42) == {:error, :unknown_unit}
      assert Aliases.resolve(%{}) == {:error, :unknown_unit}
    end
  end

  describe "arithmetic through the evaluator" do
    test "a plural calendar unit is usable as a quantity" do
      assert {:ok, result, _env} = Unity.eval("2 years to months")
      assert result.name == "month"
      assert result.value == 24.0

      assert {:ok, result, _env} = Unity.eval("18 months to quarters")
      assert result.name == "quarter"
      assert result.value == 6.0

      assert {:ok, result, _env} = Unity.eval("3 weeks to days")
      assert result.name == "day"
      assert result.value == 21.0
    end

    test "the plural does not make a unit convertible that the singular is not" do
      # CLDR keeps `duration`, `year-duration` and `night-duration` apart
      # because a month is not a fixed number of days. Resolving the plural
      # changes which names are recognised, not which units convert.
      assert {:error, message} = Unity.eval("3 months to days")
      assert message =~ "not convertible"
      assert {:error, _message} = Unity.eval("3 month to days")
    end
  end
end
