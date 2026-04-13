# Importing GNU `units` Definitions

The `Unity.GnuUnitsImporter` module parses the GNU `units` definition file and registers as many units as possible via `Localize.Unit.define_unit/2`. This guide describes what gets imported, what gets skipped, and how to use the importer.

## Quick start

```elixir
# Import directly (registers units and returns constants)
{:ok, stats} = Unity.GnuUnitsImporter.import()
# stats.imported    => 2458 custom units registered
# stats.constants   => %{"dozen" => 12.0, "gross" => 144.0, ...}

# Use constants as let bindings in evaluation
{:ok, result, _env} = Unity.eval("dozen * 3 meters", stats.constants)

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

From the GNU definitions file (~8,400 lines, ~3,500 definitions), the importer resolves **2,830 entries** to SI primitives and produces **2,458 custom units** plus **250 dimensionless constants**.

### Imported units by category

| Category | Count | Examples |
|---|---|---|
| length | 488 | furlong, fathom, league, rod, chain, cable, span, cubit, ell |
| area | 387 | rood, hide, virgate, morgen, section, township, barn |
| volume | 285 | firkin, hogshead, butt, tun, peck, bushel, gill, minim |
| mass-density | 216 | wood densities, material densities, food densities |
| mass | 202 | grain, dram, slug, stone, hundredweight, pennyweight, scruple |
| specific-heat | 81 | specificheat_water, specificheat_air |
| duration | 83 | lustrum, millennium, jiffy, shake, siderealyear |
| pressure | 83 | torr, barye, pieze, mmHg, inHg, decibar |
| energy | 58 | erg, calorie, therm, btu, electronvolt, rydberg |
| areal-density | 55 | paper weights, fabric weights |
| volume-flow-rate | 28 | cusec, cumec, sverdrup, minersinch |
| power | 28 | horsepower, boilerhorsepower, airwatt |
| temperature | 21 | degcelsius, degfahrenheit, degranking, degreaumur |
| force | 20 | dyne, kip, poundal, sthene |
| ionizing-radiation | 19 | gray, rad, rem, banana_dose |
| illuminance | 18 | footcandle, phot, metercandle |
| angle | 18 | gradian, arcminute, arcsecond, centrad, mil |
| electric-current | 16 | abampere, statampere, biot |
| speed | 16 | mach, knot, admiraltyknot |
| electric-charge | 14 | abcoulomb, statcoulomb, faraday |
| magnetic-moment | 13 | bohr_magneton, nuclear_magneton |
| electric-resistance | 11 | abohm, statohm, intohm |
| voltage | 11 | abvolt, statvolt, intvolt |
| acceleration | 10 | galileo, gravity |
| luminance | 10 | nit, stilb, apostilb, lambert |
| radioactivity | 10 | curie, rutherford |
| solid-angle | 9 | spat, squaredegree |
| thermal-conductivity | 9 | fourier |
| magnetic-flux | 8 | maxwell, debye |
| other categories | ~140 | dynamic-viscosity, momentum, thermal-resistance, etc. |

### Dimensionless constants (250)

Dimensionless values are returned as a constants map suitable for use as `let` bindings in a Unity evaluation environment. Examples: `dozen` (12), `gross` (144), `score` (20), `billion` (1e9), `avogadro` (6.022e23), `alpha` (fine structure constant), `c_si` (speed of light).

### What a definition looks like

Each imported unit is stored with:

* The unit name in lowercase (e.g., `"furlong"`).

* The CLDR base unit it converts to (e.g., `"meter"`).

* A conversion factor (e.g., `201.168`).

* A category — either a standard CLDR category (e.g., `"length"`) or a derived category for SI quantities not covered by CLDR (e.g., `"specific-heat"`, `"volume-flow-rate"`).

* Simple English display patterns (singular and naive plural).

All imported custom units support SI prefixes (`millilightsecond`, `kilofurlong`) and power prefixes (`square-smoot`, `cubic-cubit`) automatically.

## What gets skipped

**122 resolved definitions** are skipped at the registration stage:

### CLDR collisions (76 units)

Units whose names already exist in the CLDR database. These are skipped to avoid overriding built-in Localize units with potentially different conversion factors.

Examples: `meter`, `watt`, `hertz`, `ohm`, `tesla`, `farad`, `coulomb`, `candela`, `lumen`, `acre`, `hectare`, `bar`, `atmosphere`, `slug`, `barrel`, `jigger`, `revolution`, `fortnight`.

### Invalid names (22 units)

Unit names that contain characters not allowed by the custom unit name pattern (must match `^[a-z][a-z0-9_-]*$`). These include bracket-suffixed GNU names (`grit_A[micron]`, `brwiregauge[in]`), comma-containing names (`lambda_C,mu`), and symbol aliases (`%`, `'`, `''`, `"`).

### Music notation units (16 units)

Units based on the GNU `wholenote` primitive (halfnote, quarternote, eighthnote, etc.) cannot be imported because `wholenote` is not an SI primitive and has no CLDR equivalent.

### Miscellaneous (8 units)

A small number of units fail for other reasons: 4 negative magnetic moment factors (`mu_e`, `mu_n`, `mu_h`, `mu_mu`), and 4 units using the GNU `event` primitive which has no CLDR mapping.

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

### Unresolvable chains (338 definitions)

Definitions that reference other units which themselves can't be resolved. This happens when a definition depends on a unit inside a skipped conditional block, a function definition, or another unresolvable unit. Common patterns include:

* Definitions referencing function results (`parsec = au / tan(arcsec)`, `earthradius_polar = (1-earthflattening) earthradius_equatorial`)

* Cultural/monetary units referencing other unresolved terms (`farthing = 1|4 oldpence`, `monkey = 500 quid`)

* Definitions using the `+` operator (`air_2015 = 78.08% nitrogen 2 + 20.95% oxygen 2 + ...`)

## How the importer works

### Three-pass architecture

**Pass 1 — Parse** (12ms): reads the file line by line, handling continuation lines (`\`), comments (`#`), and directives. Produces a map of primitives, prefixes, definitions, aliases, and function signatures.

**Pass 2 — Resolve** (18ms): recursively evaluates each definition's expression against the parsed data until it reduces to a numeric factor times known SI primitives. Uses memoization and cycle detection. Handles numbers, fractions (`1|7000`), identifiers, multiplication (juxtaposition and `*`), division (`/`), exponentiation (`^`), parentheses, and SI prefix expansion (`cm` → `centi` + `m`).

**Pass 3 — Register**: maps each resolved dimension to a CLDR base unit string and category, then either registers via `Localize.Unit.define_unit/2` or writes to an `.exs` file. Dimensionless entries are extracted separately as named constants. Compound base unit strings are built using CLDR component ordering (kilogram, meter, second, ampere, kelvin, mole, candela, steradian) to ensure correct category lookups. Categories are assigned from the CLDR `base_unit_to_quantity` mapping, with fallback to descriptive derived category names (e.g., `"specific-heat"`, `"volume-flow-rate"`) for SI quantities not covered by CLDR.

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
