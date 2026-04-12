# Changelog

## v0.1.0 (2026-04-11)

Initial release.

### Features

* NimbleParsec-based expression parser supporting integers, floats, rational numbers (`1|3`), unit names, arithmetic (`+`, `-`, `*`, `/`, `^`, `**`), `per`, conversion (`to`, `in`, `->`), parentheses, function calls, concatenated exponents (`cm3`), and juxtaposition multiplication (`kg m`).

* AST interpreter evaluating expressions against `Localize.Unit` and `Localize.Unit.Math`.

* Over 150 unit aliases mapping common abbreviations (m, km, ft, lb, mph, etc.) to CLDR unit identifiers, with fuzzy suggestions for unknown units via `String.jaro_distance/2`.

* Built-in functions: `sqrt`, `cbrt`, `abs`, `round`, `ceil`, `floor`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `ln`, `log`, `log2`, `exp`.

* Measurement system conversion targets: `to metric`, `to us`, `to uk`, `to imperial`, `to SI`, `to preferred`. The `preferred` keyword selects the measurement system appropriate for the current locale's territory.

* Variable bindings via `let name = expression` with subsequent reference by name.

* `_` (underscore) references the previous REPL result for chained conversions.

* Mixed-unit decomposition: `3.756 hours to h;min;s` → `3 hours, 45 minutes, 21.6 seconds`.

* Locale-aware output via `Localize.Unit.to_string/2` and `Localize.Number.to_string/2`. REPL `locale` command and CLI `--locale` flag for runtime locale switching.

* Interactive REPL with `help`, `list`, `search`, `conformable`, `info`, and `locale` commands. Command history persisted to `~/.units_history`.

* CLI entry point supporting single-expression evaluation, two-argument GNU-style conversion, verbose (`-v`), terse (`-t`), exponential (`-e`), digits (`-d`), output-format (`-o`), strict (`-s`), and one-line (`-1`) modes, stdin piping, `--conformable`, and `--list`.

* Reciprocal conversion line shown by default for conversions (suppressed with `--strict` or `--one-line`).

* Formatter with default, verbose, and terse output modes.

* User-friendly error messages with parse position indicators and fuzzy unit suggestions.
