# GNU `units` Conformance Guide

This document describes how `Unity` (the Elixir library) compares with the [GNU `units`](https://www.gnu.org/software/units/) utility (v2.27). Features are grouped by category and rated as **Conforming**, **Partial**, **Different**, or **Not implemented**.

## Summary

| Category | Conforming | Partial | Different | Not implemented |
|---|---|---|---|---|
| Expression syntax | 9 | 1 | 1 | 0 |
| Built-in functions | 6 | 0 | 0 | 0 |
| Unit database | 0 | 1 | 1 | 0 |
| Interactive mode | 7 | 1 | 1 | 1 |
| CLI flags | 13 | 0 | 0 | 2 |
| Output formatting | 3 | 1 | 0 | 0 |
| Advanced features | 0 | 0 | 1 | 6 |
| **Total** | **38** | **4** | **4** | **9** |

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

### Partial

* **Operator precedence**. The five-level precedence hierarchy (`^` > juxtaposition > `*`/`/`/`per` > `+`/`-` > `to`/`in`/`->`) matches GNU for the common cases. However, GNU treats `|` (rational) as a separate highest-precedence operator so that `2|3^1|2` means `(2/3)^(1/2)`. Our parser consumes `|` during number literal parsing which handles simple cases but not exponent-embedded rationals like `2|3^1|2`.

### Different

* **Conversion syntax**. GNU uses a two-prompt interactive model ("You have:" / "You want:") and a two-argument CLI (`units "from" "to"`). We support both the two-argument CLI form and inline conversion syntax (`3 m to ft`, `3 m -> ft`, `3 m in ft`). The inline syntax is an extension not present in GNU.

## Built-in functions

### Conforming

* **`sqrt`**. Square root with dimension reduction: `sqrt(9 m^2)` = `3 m`. Requires even powers on all dimension components, matching GNU semantics.

* **`cuberoot` / `cbrt`**. Cube root with dimension reduction. We use the name `cbrt`; GNU uses `cuberoot`.

* **Trigonometric functions** (`sin`, `cos`, `tan`, `asin`, `acos`, `atan`). Operate on dimensionless/radian values, return plain numbers.

* **Logarithmic functions** (`ln`, `log`, `log2`). `ln` = natural log, `log` = base-10, `log2` = base-2. Same names and semantics as GNU.

* **`exp`**. Exponential function on dimensionless values.

Note: We also support `abs`, `round`, `ceil`, `floor` which are extensions beyond the standard GNU function set.

## Unit database

### Partial

* **Unit coverage**. GNU ships with approximately 3,600 named units covering SI, CGS, US customary, British Imperial, historical, chemical, astronomical, and esoteric units. We use the CLDR unit database via `Localize.Unit`, which covers approximately 155 base unit types with full SI prefix support (generating thousands of prefixed variants like `kilometer`, `milligram`, `gigahertz`). Common scientific and everyday units are well covered. Obscure historical units (aeginamina, pottles, firkins) and domain-specific units (wire gauges, paper sizes, baking densities) are not present.

### Different

* **Unit source**. GNU reads a plain-text definitions file (`/usr/share/units/definitions.units`) that users can extend. We derive unit knowledge from the Unicode CLDR database via `Localize.Unit`. This means our unit names follow CLDR conventions (`meter`, `kilometer-per-hour`, `cubic-centimeter`) rather than GNU conventions (`meter`, `km/hr`, `cm^3`). The trade-off is fewer total units but guaranteed locale-aware formatting in over 500 locales.

## Interactive mode (REPL)

### Conforming

* **Previous result with `_`**. The underscore references the last result, enabling chained conversions like `_ to cm`. Parsed as a proper variable in the AST, not string substitution.

* **`help` command**. Prints syntax help and available commands.

* **`list` command**. Lists known unit categories or units within a category.

* **`search` command**. `search text` finds all unit names and aliases whose names contain the given substring, matching GNU's `search` functionality.

* **`conformable` command**. Lists all units with the same dimension as a given unit. Analogous to typing `?` at the GNU "You want:" prompt.

* **`quit` / `exit`**. Exits the REPL. Ctrl-D (EOF) also works.

* **History file**. Command history is persisted to `~/.units_history` across REPL sessions via `:group_history`, analogous to GNU's `-H` flag.

### Partial

* **Variables**. We support `let name = expression` for variable binding; GNU uses `_name = expression` (names must start with underscore). Our variables are evaluated at binding time and store the result; GNU variables store the text and re-evaluate each time they are referenced. Both approaches support subsequent use of the variable name in expressions.

### Different

* **`info` command**. We provide `info <unit>` which shows the unit's category, aliases, and conformable units. GNU instead shows the unit's full definition chain when you enter a unit at "You have:" and press Enter at "You want:".

### Not implemented

* **Readline / tab completion**. GNU units compiles with readline support for tab completion of unit names and command history navigation. Our REPL uses Erlang's built-in line editor which provides basic line editing and history navigation but no tab completion of unit names.

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

* **`--version` / `--help`**. Standard informational flags.

### Not implemented

* **`-f` / `--file`**. Load custom unit definition files. Not applicable since we use the CLDR database rather than a definitions file.

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

### Not implemented

* **Custom unit definition files**. GNU reads a comprehensive plain-text definitions file and supports user overrides via `~/.units` and `-f` flags. We use the CLDR database exclusively and do not support user-defined units.

* **Non-linear unit conversions**. GNU supports arbitrary non-linear conversions defined by forward/inverse expression pairs (temperature scales, wire gauges, dB scales, etc.). We support temperature conversion via `Localize.Unit.convert/2` but do not support user-defined non-linear functions.

* **Piecewise linear units**. GNU supports interpolated lookup tables for units like wire gauges.

* **Currency conversion**. GNU includes currency exchange rates updated by an external script.

* **CGS unit systems**. GNU supports selecting between Gaussian, ESU, EMU, and Heaviside-Lorentz CGS systems via `--units`.

* **Unit definition checking** (`--check`). GNU can validate that all units in a definitions file reduce to primitive base units. Not applicable since we use the CLDR database rather than a definitions file.

## Extensions beyond GNU `units`

These features are present in our implementation but not in GNU `units`:

* **Inline conversion syntax**. `3 meters to feet`, `3 m -> cm`, `3 m in cm` — GNU requires separate "from" and "to" prompts or arguments.

* **Locale-aware unit names**. Output uses locale-appropriate unit names and number formatting via CLDR data. `1234.5 meter to kilometer` displays as `1,234 Kilometer` in German locale.

* **Mixed-unit decomposition syntax**. `3.756 hours to h;min;s` decomposes a value across multiple units and displays `3 hours, 45 minutes, 21.6 seconds`. GNU supports unit lists in output but uses a different mechanism.

* **Elixir library API**. `Unity.eval/2`, `Unity.format/2`, and the full parser/interpreter pipeline are available as a library for embedding in Elixir applications. GNU is a standalone command-line tool only.

* **Pipe/stdin support**. `echo "3 meters to feet" | units` reads expressions from stdin when not attached to a terminal.

* **`let` bindings**. Named variables with `let distance = 42.195 km` that persist across expressions within a session.
