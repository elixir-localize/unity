# Changelog

## v0.1.0 (2026-04-11)

Initial release.

### Features

* NimbleParsec-based expression parser supporting integers, floats, rational numbers (`1|3`), unit names, arithmetic (`+`, `-`, `*`, `/`, `^`), `per`, conversion (`to`, `in`, `->`), parentheses, function calls, concatenated exponents (`cm3`), and juxtaposition multiplication (`kg m`).

* AST interpreter evaluating expressions against `Localize.Unit` and `Localize.Unit.Math`.

* Over 150 unit aliases mapping common abbreviations (m, km, ft, lb, mph, etc.) to CLDR unit identifiers, with fuzzy suggestions for unknown units via `String.jaro_distance/2`.

* Built-in functions: `sqrt`, `cbrt`, `abs`, `round`, `ceil`, `floor`, `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `ln`, `log`, `log2`, `exp`.

* Variable bindings via `let name = expression` with subsequent reference by name.

* `_` (underscore) references the previous REPL result for chained conversions.

* Mixed-unit decomposition: `3.756 hours to h;min;s` → `3 hours, 45 minutes, 21.6 seconds`.

* Locale-aware output via `Localize.Unit.to_string/2` and `Localize.Number.to_string/2`. REPL `locale` command and CLI `--locale` flag for runtime locale switching.

* Interactive REPL with `help`, `list`, `conformable`, `info`, and `locale` commands.

* CLI entry point supporting single-expression evaluation, two-argument GNU-style conversion, verbose (`-v`) and terse (`-t`) output modes, stdin piping, `--conformable`, and `--list`.

* Formatter with default, verbose, and terse output modes.

* User-friendly error messages with parse position indicators and fuzzy unit suggestions.
