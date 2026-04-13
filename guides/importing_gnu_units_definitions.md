# Importing GNU `units` Definitions

The `Unity.GnuUnitsImporter` module parses the GNU `units` definition file and registers as many units as possible via `Localize.Unit.define_unit/2`. This guide describes what gets imported, what gets skipped, and how to use the importer.

## Quick start

```elixir
# Import directly (registers units in the current BEAM node)
{:ok, stats} = Unity.GnuUnitsImporter.import()

# Or export to a .exs file for repeatable loading
{:ok, count} = Unity.GnuUnitsImporter.export("priv/gnu_units.exs")

# Load the exported file at application startup
Localize.Unit.load_custom_units("priv/gnu_units.exs")
```

The CLI also supports loading via the `-f` flag:

```bash
units -f priv/gnu_units.exs "3 furlongs to meters"
```

## What gets imported

From the GNU definitions file (~8,400 lines, ~3,500 definitions), the importer resolves **2,830 units** to SI primitives and registers **1,706** as Localize custom units.

### Imported by category

| Category | Count | Examples |
|---|---|---|
| length | 488 | furlong, fathom, league, rod, chain, cable, span, cubit, ell |
| area | 387 | rood, hide, virgate, morgen, section, township, barn |
| volume | 285 | firkin, hogshead, butt, tun, peck, bushel, gill, minim |
| mass | 202 | grain, dram, slug, stone, hundredweight, pennyweight, scruple |
| duration | 83 | fortnight, lustrum, millennium, jiffy, shake, siderealyear |
| pressure | 83 | torr, barye, pieze, mmHg, inHg, decibar |
| energy | 58 | erg, calorie, therm, btu, electronvolt, rydberg |
| power | 28 | horsepower, boilerhorsepower, airwatt |
| temperature | 21 | degcelsius, degfahrenheit, degranking, degreaumur |
| force | 20 | dyne, kip, poundal, sthene |
| angle | 18 | gradian, arcminute, arcsecond, centrad, mil |
| speed | 16 | mach, knot, admiraltyknot |
| acceleration | 10 | galileo, gravity |
| digital | 4 | byte (synonyms) |
| frequency | 3 | rpm, rps |

### What a definition looks like

Each imported unit is stored with:

* The unit name in lowercase (e.g., `"furlong"`)

* The CLDR base unit it converts to (e.g., `"meter"`)

* A conversion factor (e.g., `201.168`)

* A category (e.g., `"length"`)

* Simple English display patterns (singular and naive plural)

## What gets skipped

**1,124 definitions** are skipped for the following reasons:

### Unsupported CLDR categories (389 units)

GNU `units` knows about dimensions that don't have a matching CLDR unit category. These units resolve correctly to SI primitives but can't be assigned to a category that `Localize.Unit.define_unit/2` accepts.

| Dimension | Count | Examples |
|---|---|---|
| mass-density | 216 | wood densities, material densities |
| pressure-per-length | 21 | pressure gradients |
| ionizing-radiation | 19 | gray, sievert, rad, rem |
| illuminance | 18 | lux, footcandle, phot |
| electric-current | 16 | ampere variants |
| electric-charge | 14 | coulomb variants, faraday |
| electric-resistance | 11 | ohm variants |
| voltage | 11 | volt variants |
| radioactivity | 10 | becquerel, curie |
| solid-angle | 9 | steradian, spat |
| magnetic | 8 | weber, maxwell |
| other electric/magnetic | ~30 | capacitance, inductance, conductance |

### Dimensionless quantities (248 units)

Units that resolve to pure numbers with no physical dimension. These include mathematical constants, ratios, and counting units.

Examples: `pi`, `percent`, `dozen`, `gross`, `score`, `bakers_dozen`, `avogadro`, `alpha` (fine structure constant), paper/book sizes defined as ratios.

### CLDR collisions (76 units)

Units whose names already exist in the CLDR database. These are skipped to avoid overriding built-in Localize units with potentially different conversion factors.

Examples: `meter`, `watt`, `hertz`, `ohm`, `tesla`, `farad`, `coulomb`, `candela`, `lumen`, `acre`, `hectare`, `bar`, `atmosphere`, `slug`, `barrel`, `jigger`, `revolution`, `fortnight`.

### Invalid names (22 units)

Unit names that contain characters not allowed by the custom unit name pattern (must match `^[a-z][a-z0-9_-]*$`). These are typically uppercase abbreviations or names starting with special characters.

## What is NOT parsed

### Function definitions (113 skipped)

GNU `units` supports nonlinear conversion functions with forward and inverse expressions. These require an expression evaluator at runtime and cannot be represented as a simple `factor * base_unit` conversion.

Examples:

* Temperature scales: `tempC(x)`, `tempF(x)`, `tempR(x)`

* Wire gauges: `wiregauge(x)`, `brwiregauge(x)`

* Decibels: `dB(x)`, `Np(x)`

* Photographic: `EV100(x)`, `aperture(x)`

* Geometric: `circlearea(r)`, `spherevol(r)`

* Currency: `$in(x)`, `US$in(x)`

### Conditional blocks

Definitions inside `!var` / `!endvar`, `!locale` / `!endlocale`, and `!utf8` / `!endutf8` blocks are skipped entirely. This excludes:

* **CGS electromagnetic unit systems** (Gaussian, ESU, EMU, Heaviside-Lorentz): ~200 definitions

* **Natural/Planck/Hartree unit systems**: ~100 definitions

* **Locale-specific variants** (US vs. GB customary units): ~50 definitions

* **Unicode symbol aliases**: ~30 definitions

### Directives

`!include` (currency.units, cpi.units, elements.units), `!message`, `!unitlist`, `!set`, and `!prompt` directives are ignored.

### Unresolvable chains (338 units)

Definitions that reference other units which themselves can't be resolved. This happens when a definition depends on a unit inside a skipped conditional block, a function definition, or another unresolvable unit.

## How the importer works

### Three-pass architecture

**Pass 1 — Parse** (12ms): reads the file line by line, handling continuation lines (`\`), comments (`#`), and directives. Produces a map of primitives, prefixes, definitions, aliases, and function signatures.

**Pass 2 — Resolve** (18ms): recursively evaluates each definition's expression against the parsed data until it reduces to a numeric factor times known SI primitives. Uses memoization and cycle detection. Handles numbers, fractions (`1|7000`), identifiers, multiplication (juxtaposition and `*`), division (`/`), exponentiation (`^`), parentheses, and SI prefix expansion (`cm` → `centi` + `m`).

**Pass 3 — Register**: maps each resolved dimension to a CLDR base unit string and category, then either registers via `Localize.Unit.define_unit/2` or writes to an `.exs` file.

### GNU primitive → CLDR mapping

| GNU primitive | CLDR base unit |
|---|---|
| `s` | `second` |
| `m` | `meter` |
| `kg` | `kilogram` |
| `K` | `kelvin` |
| `A` | `ampere` |
| `mol` | `mole` |
| `cd` | `candela` |
| `radian` | `radian` |
| `sr` | `steradian` |
| `bit` | `bit` |

## Exported file format

The exported `.exs` file is a standard Elixir term file loadable by `Localize.Unit.load_custom_units/1`:

```elixir
[
  %{
    unit: "furlong",
    base_unit: "meter",
    factor: 201.168,
    category: "length",
    display: %{
      en: %{
        long: %{one: "{0} furlong", other: "{0} furlongs", display_name: "furlongs"}
      }
    }
  },
  %{
    unit: "fathom",
    base_unit: "meter",
    factor: 1.8288,
    category: "length",
    display: %{
      en: %{
        long: %{one: "{0} fathom", other: "{0} fathoms", display_name: "fathoms"}
      }
    }
  },
  ...
]
```

You can edit this file to add translations, fix plurals, or adjust conversion factors before loading.
