# GNU `units` Conformance Guide

This document describes how `Units` (the Elixir library) compares with the [GNU `units`](https://www.gnu.org/software/units/) utility (v2.27). Features are grouped by category and rated as **Conforming**, **Partial**, **Different**, or **Not implemented**.

## Summary

| Category | Conforming | Partial | Different | Not implemented |
|---|---|---|---|---|
| Expression syntax | 8 | 1 | 1 | 1 |
| Built-in functions | 6 | 0 | 0 | 0 |
| Unit database | 0 | 1 | 1 | 0 |
| Interactive mode | 5 | 1 | 1 | 3 |
| CLI flags | 7 | 0 | 0 | 8 |
| Output formatting | 2 | 1 | 0 | 1 |
| Advanced features | 0 | 0 | 1 | 6 |
| **Total** | **28** | **4** | **4** | **19** |

## Expression syntax

### Conforming

* **Arithmetic operators** (`+`, `-`, `*`, `/`, `^`). All five standard operators work with the same meaning. `+` and `-` require conformable (same-dimension) units on both sides, matching GNU behaviour.

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

### Not implemented

* **`**` as exponentiation**. GNU accepts both `^` and `**` for exponentiation. We only accept `^`.

## Built-in functions

### Conforming

* **`sqrt`**. Square root with dimension reduction: `sqrt(9 m^2)` = `3 m`. Requires even powers on all dimension components, matching GNU semantics.

* **`cuberoot` / `cbrt`**. Cube root with dimension reduction. We use the name `cbrt`; GNU uses `cuberoot`.

* **Trigonometric functions** (`sin`, `cos`, `tan`, `asin`, `acos`, `atan`). Operate on dimensionless/radian values, return plain numbers.

* **Logarithmic functions** (`ln`, `log`, `log2`). `ln` = natural log, `log` = base-10, `log2` = base-2. Same names and semantics as GNU.

* **`exp`**. Exponential function on dimensionless values.

Note: GNU also has `abs`, `round`, `ceil`, `floor` which we support as well, though these are extensions beyond the standard GNU function set.

## Unit database

### Partial

* **Unit coverage**. GNU ships with approximately 3,600 named units covering SI, CGS, US customary, British Imperial, historical, chemical, astronomical, and esoteric units. We use the CLDR unit database via `Localize.Unit`, which covers approximately 155 base unit types with full SI prefix support (generating thousands of prefixed variants like `kilometer`, `milligram`, `gigahertz`). Common scientific and everyday units are well covered. Obscure historical units (aeginamina, pottles, firkins) and domain-specific units (wire gauges, paper sizes, baking densities) are not present.

### Different

* **Unit source**. GNU reads a plain-text definitions file (`/usr/share/units/definitions.units`) that users can extend. We derive unit knowledge from the Unicode CLDR database via `Localize.Unit`. This means our unit names follow CLDR conventions (`meter`, `kilometer-per-hour`, `cubic-centimeter`) rather than GNU conventions (`meter`, `km/hr`, `cm^3`). The trade-off is fewer total units but guaranteed locale-aware formatting in over 500 locales.

## Interactive mode (REPL)

### Conforming

* **Previous result with `_`**. The underscore references the last result, enabling chained conversions like `_ to cm`. Parsed as a proper variable in the AST, not string substitution.

* **`help` command**. Prints syntax help and available commands.

* **`list` command**. Lists known unit categories or units within a category. Analogous to GNU's `search` command.

* **`conformable` command**. Lists all units with the same dimension as a given unit. Analogous to typing `?` at the GNU "You want:" prompt.

* **`quit` / `exit`**. Exits the REPL. Ctrl-D (EOF) also works.

### Partial

* **Variables**. We support `let name = expression` for variable binding; GNU uses `_name = expression` (names must start with underscore). Our variables are evaluated at binding time and store the result; GNU variables store the text and re-evaluate each time they are referenced. Both approaches support subsequent use of the variable name in expressions.

### Different

* **`info` command**. We provide `info <unit>` which shows the unit's category, aliases, and conformable units. GNU instead shows the unit's full definition chain when you enter a unit at "You have:" and press Enter at "You want:".

### Not implemented

* **Readline / tab completion**. GNU units compiles with readline support for tab completion of unit names and command history navigation. Our REPL uses Erlang's built-in `:io.get_line/1` which provides basic line editing but no tab completion of unit names.

* **History file**. GNU supports `-H filename` to persist readline history across sessions. We do not persist history.

* **`search` command**. GNU's `search text` finds all units whose names contain the given substring. Our `list` command shows units by category but does not support arbitrary substring search across all unit names.

## CLI flags

### Conforming

* **`-v` / `--verbose`**. Verbose output showing `from = to` format.

* **`-t` / `--terse`**. Bare numeric result only, suitable for scripting.

* **`-q` / `--quiet`**. Suppresses prompts in interactive mode.

* **`--locale`**. Sets the formatting locale.

* **`--conformable`**. Lists all units conformable with the given unit.

* **`--list`**. Lists known units or categories.

* **`--version` / `--help`**. Standard informational flags.

### Not implemented

* **`-d` / `--digits`**. Control number of significant digits in output.

* **`-e` / `--exponential`**. Scientific notation output.

* **`-o` / `--output-format`**. Printf-style output format string.

* **`-f` / `--file`**. Load custom unit definition files.

* **`-s` / `--strict`**. Suppress reciprocal conversions.

* **`-1` / `--one-line`**. Show only forward conversion (no reciprocal line).

* **`-c` / `--check`**. Validate unit definition files for consistency.

* **`--units`**. Select CGS unit system (gauss, esu, emu, etc.).

## Output formatting

### Conforming

* **Default output**. Shows the converted value and unit name: `9.84252 feet`.

* **Terse output**. Shows only the numeric value, suitable for shell scripting.

### Partial

* **Precision control**. GNU defaults to 8 significant digits and supports `-d N` for arbitrary precision. We default to 6 decimal places via `max_fractional_digits` and do not currently support user-configurable precision from the CLI.

### Not implemented

* **Reciprocal conversion line**. GNU shows both `* factor` and `/ factor` lines by default. We show only the forward conversion.

## Advanced features

### Different

* **Locale-aware output**. GNU has minimal locale support (locale-conditional unit definitions, `UNITS_ENGLISH` environment variable for US vs. UK units). We provide full locale-aware number and unit name formatting via `Localize`, supporting over 500 locales with correct decimal separators, grouping, and translated unit names (e.g., "キロメートル" in Japanese, "Kilometer" in German). This is a significant extension beyond GNU.

### Not implemented

* **Custom unit definition files**. GNU reads a comprehensive plain-text definitions file and supports user overrides via `~/.units` and `-f` flags. We use the CLDR database exclusively and do not support user-defined units.

* **Non-linear unit conversions**. GNU supports arbitrary non-linear conversions defined by forward/inverse expression pairs (temperature scales, wire gauges, dB scales, etc.). We support temperature conversion via `Localize.Unit.convert/2` but do not support user-defined non-linear functions.

* **Piecewise linear units**. GNU supports interpolated lookup tables for units like wire gauges. Not implemented.

* **Currency conversion**. GNU includes currency exchange rates updated by an external script. Not implemented.

* **CGS unit systems**. GNU supports selecting between Gaussian, ESU, EMU, and Heaviside-Lorentz CGS systems via `--units`. Not implemented.

* **Unit definition checking** (`--check`). GNU can validate that all units in a definitions file reduce to primitive base units. Not applicable since we use the CLDR database rather than a definitions file.

## Extensions beyond GNU `units`

These features are present in our implementation but not in GNU `units`:

* **Inline conversion syntax**. `3 meters to feet`, `3 m -> cm`, `3 m in cm` — GNU requires separate "from" and "to" prompts or arguments.

* **Locale-aware unit names**. Output uses locale-appropriate unit names and number formatting via CLDR data. `1234.5 meter to kilometer` displays as `1,234 Kilometer` in German locale.

* **Mixed-unit decomposition syntax**. `3.756 hours to h;min;s` decomposes a value across multiple units and displays `3 hours, 45 minutes, 21.6 seconds`. GNU supports unit lists in output but uses a different mechanism.

* **Elixir library API**. `Units.eval/2`, `Units.format/2`, and the full parser/interpreter pipeline are available as a library for embedding in Elixir applications. GNU is a standalone command-line tool only.

* **Pipe/stdin support**. `echo "3 meters to feet" | units` reads expressions from stdin when not attached to a terminal.

* **`let` bindings**. Named variables with `let distance = 42.195 km` that persist across expressions within a session.
