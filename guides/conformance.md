# GNU `units` Conformance Guide

This document describes how `Unity` (the Elixir library) compares with the [GNU `units`](https://www.gnu.org/software/units/) utility (v2.27). Features are grouped by category and rated as **Conforming**, **Partial**, **Different**, or **Not implemented**.

## Summary

| Category | Conforming | Partial | Different | Not implemented |
|---|---|---|---|---|
| Expression syntax | 11 | 1 | 1 | 0 |
| Built-in functions | 7 | 0 | 0 | 0 |
| Unit database | 0 | 2 | 1 | 0 |
| Interactive mode | 7 | 2 | 1 | 0 |
| CLI flags | 13 | 0 | 0 | 1 |
| Output formatting | 3 | 1 | 0 | 0 |
| Advanced features | 0 | 2 | 1 | 4 |
| **Total** | **41** | **8** | **4** | **5** |

## Expression syntax

### Conforming

* **Arithmetic operators** (`+`, `-`, `*`, `/`, `^`). All five standard operators work with the same meaning. `+` and `-` require conformable (same-dimension) units on both sides, matching GNU behaviour.

* **`**` as exponentiation**. Both `^` and `**` are accepted: `s^2` and `s**2` produce the same result, matching GNU.

* **Parentheses**. Parenthesized sub-expressions override precedence: `(3 + 4) * m`.

* **Juxtaposition multiplication**. Space between factors is implicit multiplication with higher precedence than `/`, matching the GNU rule that `kg m / s^2` = `(kg * m) / s^2` and `m / s s` = `m / (s * s)`.

* **`per` keyword**. `miles per hour` is equivalent to `miles / hour`.

* **Conversion operators**. `to` and `in` keywords, plus `->` as an arrow operator. GNU uses the two-prompt model ("You have:" / "You want:") rather than inline syntax, but when invoked non-interactively as `units "from" "to"` the effect is the same.

* **Rational numbers with `|`**. `1|3 cup` = one-third cup. The `|` operator is parsed at high precedence, consistent with GNU.

* **Concatenated exponents**. `cm3` is parsed as `cm^3` for known unit names with a single trailing digit, matching GNU behaviour.

* **Negative exponents**. `s^-2` and `s^(-2)` both work.

* **Hex, octal, and binary literals**. `0xFF`, `0o77`, `0b1010` for hexadecimal, octal, and binary number entry.

* **Underscore digit separators**. `1_000_000`, `0xFF_FF` for readable large numbers. Underscores are stripped during parsing.

### Partial

* **Operator precedence**. The five-level precedence hierarchy (`^` > juxtaposition > `*`/`/`/`per` > `+`/`-` > `to`/`in`/`->`) matches GNU for the common cases. However, GNU treats `|` (rational) as a separate highest-precedence operator so that `2|3^1|2` means `(2/3)^(1/2)`. Our parser consumes `|` during number literal parsing which handles simple cases but not exponent-embedded rationals like `2|3^1|2`.

### Different

* **Conversion syntax**. GNU uses a two-prompt interactive model ("You have:" / "You want:") and a two-argument CLI (`units "from" "to"`). We support both the two-argument CLI form and inline conversion syntax (`3 m to ft`, `3 m -> ft`, `3 m in ft`). The inline syntax is an extension not present in GNU.

## Built-in functions

### Conforming

* **`sqrt`**. Square root with dimension reduction: `sqrt(9 m^2)` = `3 m`. Requires even powers on all dimension components, matching GNU semantics.

* **`cuberoot` / `cbrt`**. Cube root with dimension reduction. We use the name `cbrt`; GNU uses `cuberoot`.

* **Trigonometric functions** (`sin`, `cos`, `tan`, `asin`, `acos`, `atan`). Operate on dimensionless/radian values, return plain numbers.

* **Hyperbolic functions** (`sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh`). Full set of hyperbolic trig functions on dimensionless values.

* **Logarithmic functions** (`ln`, `log`, `log2`). `ln` = natural log, `log` = base-10, `log2` = base-2. Same names and semantics as GNU.

* **`exp`**. Exponential function on dimensionless values.

Note: We also support `abs`, `round`, `ceil`, `floor`, `factorial`, `gamma`, `atan2`, `hypot`, `gcd`, `lcm`, `min`, `max`, `mod`, and `assert_eq` which are extensions beyond the standard GNU function set.

## Unit database

### Partial

* **Unit coverage**. GNU ships with approximately 3,600 named units covering SI, CGS, US customary, British Imperial, historical, chemical, astronomical, and esoteric units. We use the CLDR unit database via `Localize.Unit` as a foundation (~155 base unit types with full SI prefix support), augmented by the GNU Units importer which registers ~2,440 additional custom units, ~250 dimensionless constants as `let` bindings, and ~75 nonlinear special conversions (decibel scales, temperature functions, wire gauges, density hydrometers, photographic exposure, atmospheric models, etc.). Combined coverage is approximately 2,760 named units plus SI-prefixed variants. Remaining gaps are primarily music notation units (wholenote-based), currency/inflation functions (require external data), piecewise interpolation tables (plate/standard gauges), and ~340 definitions whose resolution chains depend on unimplemented resolver features.

* **SI prefixes on custom units**. SI prefixes (`milli-`, `kilo-`, `micro-`, etc.) and power prefixes (`square-`, `cubic-`, `pow4-`, etc.) are recognised on imported custom units. For example, after importing `lightsecond` from GNU definitions, `millilightsecond` and `kilolightsecond` work automatically.

### Different

* **Unit source**. GNU reads a plain-text definitions file (`/usr/share/units/definitions.units`) that users can extend. We derive unit knowledge from the Unicode CLDR database via `Localize.Unit`, extended by importing the GNU definitions file via `Unity.GnuUnitsImporter`. Unit names follow CLDR conventions (`meter`, `kilometer-per-hour`, `cubic-centimeter`) rather than GNU conventions (`meter`, `km/hr`, `cm^3`). The trade-off is locale-aware formatting in over 500 locales.

## Interactive mode (REPL)

### Conforming

* **Previous result with `_`**. The underscore references the last result, enabling chained conversions like `_ to cm`. Parsed as a proper variable in the AST, not string substitution.

* **`help` command**. Prints syntax help and available commands.

* **`list` command**. Lists known unit categories or units within a category.

* **`search` command**. `search text` finds all unit names and aliases whose names contain the given substring, matching GNU's `search` functionality.

* **`conformable` command**. Lists all units with the same dimension as a given unit. Analogous to typing `?` at the GNU "You want:" prompt.

* **`quit` / `exit`**. Exits the REPL. Ctrl-D (EOF) also works.

* **History file**. Command history is persisted across REPL sessions to `~/.unity_history/` using the Erlang shell's built-in history, analogous to GNU's `-H` flag. The REPL bootstraps the Erlang terminal driver via `shell:start_interactive/1` when run outside IEx, providing full line editing (arrow keys, Ctrl-A/E, etc.) and history navigation.

### Partial

* **Variables**. We support `let name = expression` for variable binding; GNU uses `_name = expression` (names must start with underscore). Our variables are evaluated at binding time and store the result; GNU variables store the text and re-evaluate each time they are referenced. Both approaches support subsequent use of the variable name in expressions.

### Different

* **`info` command**. We provide `info <unit>` which shows the unit's category, aliases, and conformable units. GNU instead shows the unit's full definition chain when you enter a unit at "You have:" and press Enter at "You want:".

### Conforming (partial)

* **Tab completion**. Unit names, function names, REPL commands, and custom unit names are completed on Tab. Common prefix expansion with multi-candidate listing. GNU units provides similar readline-based completion.

## CLI flags

### Conforming

* **`-v` / `--verbose`**. Verbose output showing `from = to` format.

* **`-t` / `--terse`**. Bare numeric result only, suitable for scripting.

* **`-q` / `--quiet`**. Suppresses prompts in interactive mode.

* **`-d` / `--digits`**. Controls the maximum number of fractional digits in output. Defaults to 6.

* **`-e` / `--exponential`**. Scientific notation output for numeric values.

* **`-o` / `--output-format`**. Erlang-compatible format string (e.g., `"%.8g"`) for precise control over numeric output. Format strings use Erlang's `:io_lib.format` conventions.

* **`-s` / `--strict`**. Suppresses reciprocal conversion lines.

* **`-1` / `--one-line`**. Shows only the forward conversion (no reciprocal line). Equivalent to `--strict` for our output format.

* **`--locale`**. Sets the formatting locale.

* **`--conformable`**. Lists all units conformable with the given unit.

* **`--list`**. Lists known units or categories.

* **`-f` / `--file`**. Load custom unit definition files (`.exs` format). Can be specified multiple times. GNU uses its own plain-text format; we use Elixir term files compatible with `Localize.Unit.load_custom_units/1`.

* **`--version` / `--help`**. Standard informational flags.

### Not implemented

* **`--units`**. Select CGS unit system (gauss, esu, emu, etc.). Out of scope.

## Output formatting

### Conforming

* **Default output**. Shows the converted value and unit name: `9.84252 feet`.

* **Terse output**. Shows only the numeric value, suitable for shell scripting.

* **Reciprocal conversion line**. Conversions show both the forward result and a reciprocal line (e.g., `/ 0.3048`), matching GNU's default two-line output. Suppressed with `--strict` or `--one-line`.

### Partial

* **Precision control**. GNU defaults to 8 significant digits and supports `-d N` for significant digits. We default to 6 fractional digits and `-d N` controls fractional digits (not significant digits). The distinction matters for very large or very small numbers.

## Advanced features

### Different

* **Locale-aware output**. GNU has minimal locale support (locale-conditional unit definitions, `UNITS_ENGLISH` environment variable for US vs. UK units). We provide full locale-aware number and unit name formatting via `Localize`, supporting over 500 locales with correct decimal separators, grouping, and translated unit names (e.g., "キロメートル" in Japanese, "Kilometer" in German). This is a significant extension beyond GNU.

### Partial

* **Custom unit definition files**. GNU reads a comprehensive plain-text definitions file and supports user overrides via `~/.units` and `-f` flags. We support custom unit definition files in Elixir `.exs` format, loadable via `Localize.Unit.load_custom_units/1` or the `-f` CLI flag. The `Unity.GnuUnitsImporter` module can parse and convert the GNU definitions file, importing ~2,440 units, ~250 dimensionless constants, and ~75 nonlinear conversions. User-defined units can also be registered at runtime via `Localize.Unit.define_unit/2`.

* **Non-linear unit conversions**. GNU supports ~113 nonlinear conversion functions defined by forward/inverse expression pairs. We implement ~75 of these as `:special` custom units with registered forward/inverse Elixir functions, covering temperature scales (`tempc`, `tempf`, `tempreaumur`), decibel/logarithmic scales (`decibel`, `dBm`, `dBW`, `dBV`, `dBSPL`, `neper`, `bel`, etc.), density hydrometers (`baume`, `twaddell`, `quevenne`, `pH`, `apidegree`), wire/shotgun gauges (`wiregauge`/`awg`, `screwgauge`, `shotgungauge`), shoe and ring sizes, photographic exposure scales (`ev100`, APEX values), atmospheric models (`stdatm-t`, `stdatm-p`, `airmass`), astronomical magnitudes (`vmag`, surface brightness), gauge pressure, and geometry helpers. These work both as function calls (`tempc(100)` → `373.15 kelvin`) and as unit conversions (`100 tempc to fahrenheit`). Not implemented: currency/inflation (~5, require external data), piecewise interpolation tables (~2), sugar/food science (~4), and functions that depend on unresolved GNU definitions.

### Not implemented

* **Currency conversion**. GNU includes currency exchange rates updated by an external script.

* **Piecewise linear units**. GNU supports interpolated lookup tables for plate gauge and standard gauge.

* **CGS unit systems**. GNU supports selecting between Gaussian, ESU, EMU, and Heaviside-Lorentz CGS systems via `--units`.

* **Unit definition checking** (`--check`). GNU can validate that all units in a definitions file reduce to primitive base units. Not applicable since we use the CLDR database rather than a definitions file.

## Extensions beyond GNU `units`

These features are present in our implementation but not in GNU `units`:

* **Inline conversion syntax**. `3 meters to feet`, `3 m -> cm`, `3 m in cm` — GNU requires separate "from" and "to" prompts or arguments.

* **Locale-aware unit names**. Output uses locale-appropriate unit names and number formatting via CLDR data. `1234.5 meter to kilometer` displays as `1,234 Kilometer` in German locale.

* **Mixed-unit decomposition syntax**. `3.756 hours to h;min;s` decomposes a value across multiple units and displays `3 hours, 45 minutes, 21.6 seconds`. GNU supports unit lists in output but uses a different mechanism.

* **Elixir library API**. `Unity.eval/2`, `Unity.format/2`, and the full parser/interpreter pipeline are available as a library for embedding in Elixir applications. GNU is a standalone command-line tool only.

* **Pipe/stdin support**. `echo "3 meters to feet" | units` reads expressions from stdin when not attached to a terminal.

* **`let` bindings**. Named variables with `let distance = 42.195 km` that persist across expressions within a session. The `bindings` REPL command displays all current variable bindings.

* **Date/time arithmetic**. `now()` returns the current UTC datetime, `datetime("2025-01-01T00:00:00Z")` parses ISO 8601 strings, `unixtime(0)` converts Unix timestamps. DateTime subtraction yields a duration in seconds; adding a duration to a DateTime yields a new DateTime. `timestamp(dt)` extracts the Unix timestamp, `today()` returns the current date.

* **Assertions**. `assert_eq(12 inch, 1 foot)` verifies two values are equal after unit conversion. An optional third argument specifies tolerance: `assert_eq(1 mile, 1.60934 km, 1 meter)`. Returns `true` on success or a descriptive error on failure.

* **Extended math functions**. `atan2(y, x)`, `hypot(a, b)`, `factorial(n)`, `gamma(n)`, `gcd(a, b)`, `lcm(a, b)`, `min(a, b)`, `max(a, b)`, `mod(a, b)`, and the full set of hyperbolic trig functions (`sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh`).

* **GNU Units importer**. `Unity.GnuUnitsImporter.import/1` parses the GNU `units` definition file and registers ~2,440 custom units, ~250 dimensionless constants as `let` bindings, and ~75 nonlinear conversion functions (temperature, decibel, gauges, density scales, photography, atmospheric, astronomy, etc.). Imported units support SI prefixes (`millilightsecond`, `kilofurlong`) and power prefixes (`square-smoot`). Nonlinear functions work both as function calls (`tempc(100)`) and as unit conversions (`100 tempc to fahrenheit`). See the [Importing GNU Units Definitions](importing_gnu_units_definitions.md) guide for details.
