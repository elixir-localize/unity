# Changelog

## v0.5.0 (2026-04-13)

### Enhancements

* Added 20 new math functions: hyperbolic trig (`sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh`), two-argument functions (`atan2`, `hypot`, `gcd`, `lcm`, `min`, `max`, `mod`), and `factorial`/`gamma`.

* Hex (`0xFF`), octal (`0o77`), and binary (`0b1010`) number literals. Underscore digit separators (`1_000_000`, `0xFF_FF`) in all number formats.

* Tab completion for unit names, function names, REPL commands, and custom unit names.

* Date/time arithmetic: `now()`, `today()`, `datetime("2025-01-01T00:00:00Z")`, `unixtime(n)`, `timestamp(dt)`. DateTime subtraction yields duration; DateTime ± duration yields DateTime.

* String literal support in expressions (`"..."`) for function arguments.

* Zero-argument function calls (`now()`, `today()`).

* `assert_eq(a, b)` and `assert_eq(a, b, tolerance)` for verifying unit equivalences with automatic conversion and optional tolerance.

* Introspection functions: `unit_of(expr)`, `value_of(expr)`, `is_dimensionless(expr)`.

* Percentage functions: `increase_by(val, pct)`, `decrease_by(val, pct)`, `percentage_change(from, to)`. Work on both plain numbers and units.

* Variables with trailing digits (e.g., `t1`) now resolve correctly from the environment before falling back to concatenated-exponent parsing.

## v0.4.0 (2026-04-13)

### Enhancements

* Added 75 nonlinear (`:special`) conversion functions covering temperature scales (`tempc`, `tempf`, `tempreaumur`), decibel/logarithmic scales (`decibel`, `dBm`, `dBW`, `dBV`, `dBSPL`, `neper`, `bel`, `musicalcent`, `bril`), density hydrometers (`baume`, `twaddell`, `quevenne`, `pH`, `apidegree`), wire/screw/shotgun gauges, shoe and ring sizes, photographic exposure (EV100, APEX values), atmospheric models, astronomical magnitudes, gauge pressure, and geometry/network helpers.

* Special conversions work both as function calls (`tempc(100)` → `373.15 kelvin`) and as unit conversions (`100 tempc to fahrenheit` → `212 fahrenheit`).

* Refactored Beaufort scale from hardcoded logic to the general `:special` conversion mechanism.

* Total GNU Units coverage: ~2,440 linear units + 250 constants + 75 special conversions = ~2,760 used.

## v0.3.0 (2026-04-13)

### Bug Fixes

* Batch load custom units to avoid `:persistent_term` churn.

## v0.2.0 (2026-04-13)

### Bug Fixes

* REPL now has full line editing and history when started via `mix run -e "Unity.Repl.start()"`. Bootstraps the Erlang terminal driver via `shell:start_interactive/1` when not running under IEx. History is persisted to `~/.unity_history/`.

### Enhancements

* GNU Units importer now imports ~2,460 custom units (was ~1,700) and extracts ~250 dimensionless constants as `let` bindings.

* Added support for all CLDR unit categories including mass-density, voltage, electric-charge, illuminance, radioactivity, and other derived SI quantities.

* Added derived category mappings for compound SI quantities not in CLDR (specific-heat, volume-flow-rate, areal-density, thermal-conductivity, dynamic-viscosity, etc.).

* CLDR compound base unit strings now use correct component ordering (kilogram, meter, second, ampere, kelvin, ...) matching the CLDR `base_unit_to_quantity` keys.

* Added `bindings` REPL command to display current variable bindings.

* `import/1` now returns a `:constants` map of dimensionless values suitable for use as evaluation environment bindings.

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
