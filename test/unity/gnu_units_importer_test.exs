defmodule Unity.GnuUnitsImporterTest do
  use ExUnit.Case, async: false

  alias Unity.GnuUnitsImporter
  alias Unity.GnuUnitsImporter.{Parser, Resolver, Registrar}
  alias Localize.Unit.CustomRegistry

  setup do
    CustomRegistry.clear()
    on_exit(fn -> CustomRegistry.clear() end)
  end

  # ── Parser tests ──

  describe "Parser.parse_content/1" do
    test "parses primitive declarations" do
      content = "s !\nm !\nradian !dimensionless"
      parsed = Parser.parse_content(content)
      assert parsed.primitives["s"] == :base
      assert parsed.primitives["m"] == :base
      assert parsed.primitives["radian"] == :dimensionless
    end

    test "parses prefix definitions" do
      content = "kilo- 1e3\ncenti- 1e-2\nc- centi"
      parsed = Parser.parse_content(content)
      assert parsed.prefixes["kilo"] == "1e3"
      assert parsed.prefixes["centi"] == "1e-2"
      assert parsed.prefixes["c"] == "centi"
    end

    test "parses simple definitions" do
      content = "inch 2.54 cm\nfoot 12 inch"
      parsed = Parser.parse_content(content)
      assert parsed.definitions["inch"] == "2.54 cm"
      assert parsed.definitions["foot"] == "12 inch"
    end

    test "parses alias definitions" do
      content = "feet foot\nmeter m"
      parsed = Parser.parse_content(content)
      assert parsed.aliases["feet"] == "foot"
      assert parsed.aliases["meter"] == "m"
    end

    test "skips function definitions" do
      content = "tempC(x) units=[1;K] x K + 273.15"
      parsed = Parser.parse_content(content)
      assert map_size(parsed.definitions) == 0
      assert Map.has_key?(parsed.functions, "tempC")
    end

    test "handles line continuations" do
      content = "longdef foo \\\n  bar baz"
      parsed = Parser.parse_content(content)
      assert String.contains?(parsed.definitions["longdef"], "bar baz")
    end

    test "strips comments" do
      content = "inch 2.54 cm  # exact definition"
      parsed = Parser.parse_content(content)
      assert parsed.definitions["inch"] == "2.54 cm"
    end

    test "skips conditional blocks" do
      content = """
      m !
      !var UNITS_SYSTEM esu
      statcoulomb sqrt(dyne) cm
      !endvar
      foot 0.3048 m
      """

      parsed = Parser.parse_content(content)
      refute Map.has_key?(parsed.definitions, "statcoulomb")
      assert Map.has_key?(parsed.definitions, "foot")
    end

    test "parses fractional definitions" do
      content = "grain 1|7000 pound"
      parsed = Parser.parse_content(content)
      assert parsed.definitions["grain"] == "1|7000 pound"
    end
  end

  # ── Resolver tests ──

  describe "Resolver.resolve_all/1" do
    test "resolves simple chain" do
      parsed =
        Parser.parse_content("""
        m !
        inch 0.0254 m
        foot 12 inch
        """)

      {:ok, resolved} = Resolver.resolve_all(parsed)
      assert_in_delta elem(resolved["foot"], 0), 0.3048, 0.0001
      assert resolved["foot"] |> elem(1) == %{"m" => 1}
    end

    test "resolves compound units" do
      parsed =
        Parser.parse_content("""
        s !
        m !
        kg !
        newton kg m / s^2
        """)

      {:ok, resolved} = Resolver.resolve_all(parsed)
      {factor, dims} = resolved["newton"]
      assert_in_delta factor, 1.0, 0.001
      assert dims == %{"kg" => 1, "m" => 1, "s" => -2}
    end

    test "resolves prefix expansion" do
      parsed =
        Parser.parse_content("""
        m !
        centi- 1e-2
        c- centi
        inch 2.54 cm
        """)

      {:ok, resolved} = Resolver.resolve_all(parsed)
      assert_in_delta elem(resolved["inch"], 0), 0.0254, 0.0001
    end

    test "resolves fractions" do
      parsed =
        Parser.parse_content("""
        kg !
        pound 0.45359237 kg
        grain 1|7000 pound
        """)

      {:ok, resolved} = Resolver.resolve_all(parsed)
      assert_in_delta elem(resolved["grain"], 0), 6.4799e-5, 1.0e-7
    end

    test "resolves negative numbers" do
      parsed =
        Parser.parse_content("""
        s !
        test -2.5 s
        """)

      {:ok, resolved} = Resolver.resolve_all(parsed)
      assert_in_delta elem(resolved["test"], 0), -2.5, 0.001
    end

    test "resolves aliases" do
      parsed =
        Parser.parse_content("""
        m !
        foot 0.3048 m
        feet foot
        """)

      {:ok, resolved} = Resolver.resolve_all(parsed)
      assert_in_delta elem(resolved["feet"], 0), 0.3048, 0.0001
    end

    test "handles circular references gracefully" do
      parsed =
        Parser.parse_content("""
        a b
        b a
        """)

      {:ok, resolved} = Resolver.resolve_all(parsed)
      assert map_size(resolved) == 0
    end
  end

  # ── Registrar tests ──

  describe "Registrar.to_definition_list/1" do
    test "produces valid definition maps" do
      parsed =
        Parser.parse_content("""
        m !
        kg !
        s !
        smoot 1.7018 m
        cubit 0.4572 m
        """)

      {:ok, resolved} = Resolver.resolve_all(parsed)
      defs = Registrar.to_definition_list(resolved)

      assert length(defs) == 2

      smoot_def = Enum.find(defs, &(&1.unit == "smoot"))
      assert smoot_def.base_unit == "meter"
      assert smoot_def.category == "length"
      assert_in_delta smoot_def.factor, 1.7018, 0.001
      assert smoot_def.display.en.long.one == "{0} smoot"
      assert smoot_def.display.en.long.other == "{0} smoots"
    end

    test "skips dimensionless results" do
      parsed =
        Parser.parse_content("""
        pi 3.14159
        """)

      {:ok, resolved} = Resolver.resolve_all(parsed)
      defs = Registrar.to_definition_list(resolved)
      assert defs == []
    end
  end

  # ── Integration tests ──

  describe "GnuUnitsImporter.import/1" do
    @tag :integration
    test "imports from system definitions file" do
      case GnuUnitsImporter.import() do
        {:ok, stats} ->
          assert stats.imported > 1000
          assert stats.skipped > 0

          # Verify some imported units work
          result = Unity.eval!("3 furlong to meter")
          assert_in_delta result.value, 603.504, 0.01

          result = Unity.eval!("1 slug to kg")
          assert_in_delta result.value, 14.5939, 0.01

        {:error, reason} ->
          # Skip if GNU units not installed
          IO.puts("Skipping: #{reason}")
      end
    end
  end

  describe "GnuUnitsImporter.export/1" do
    @tag :integration
    test "exports and loads round-trip" do
      path = Path.join(System.tmp_dir!(), "test_gnu_units.exs")

      case GnuUnitsImporter.export(path) do
        {:ok, count} ->
          assert count > 1000

          # Load the exported file
          {:ok, loaded} = Localize.Unit.load_custom_units(path)
          assert loaded == count

          File.rm(path)

        {:error, reason} ->
          IO.puts("Skipping: #{reason}")
      end
    end
  end
end
