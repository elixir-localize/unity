# Units

An Elixir unit conversion calculator inspired by the Unix `units` utility. Uses [Localize](https://github.com/elixir-localize/localize) as the primary engine for unit creation, conversion, arithmetic, and localized output.

## Features

* Parse and evaluate unit expressions: `3 meters to feet`, `60 mph to km/h`.
* Arithmetic on units: `12 ft + 3 in`, `100 kg * 9.8 m/s^2`.
* Built-in functions: `sqrt`, `cbrt`, `abs`, `round`, `ceil`, `floor`, trig, logarithms.
* Juxtaposition multiplication: `kg m / s^2` = `(kg * m) / s^2`, matching GNU `units` precedence.
* Rational numbers: `1|3 cup to mL`.
* Concatenated exponents: `cm3` = `cm^3`.
* Measurement system conversion: `100 meter to us`, `100 fahrenheit to metric`, `to preferred`, `to imperial`, `to SI`.
* Variables: `let distance = 42.195 km`, then reuse `distance / time`.
* Mixed-unit display: `3.756 hours to h;min;s` → `3 hours, 45 minutes, 21.6 seconds`.
* Locale-aware output: number and unit formatting via `Localize`.
* Interactive REPL with `_` (previous result), `help`, `list`, `info`, `conformable`, and `locale` commands.
* CLI for single-expression evaluation, piping, and scripting.

## Installation

Add `units` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:units, "~> 0.1.0"}
  ]
end
```

## Library usage

```elixir
iex> {:ok, result, _env} = Units.eval("3 meters to feet")
iex> result.value
9.84251968503937

iex> Units.format!(Units.eval!("60 mph to km/h"))
"96.561 kilometers per hour"

iex> Units.format!(Units.eval!("100 celsius to fahrenheit"))
"212 degrees Fahrenheit"

iex> {:ok, result, _env} = Units.eval("3.756 hours to h;min;s")
iex> Units.format!(result)
"3 hours, 45 minutes, 21.6 seconds"
```

### Variables

```elixir
iex> {:ok, _, env} = Units.eval("let distance = 42.195 km")
iex> {:ok, _, env} = Units.eval("let time = 2 hours", env)
iex> {:ok, result, _} = Units.eval("distance / time", env)
iex> result.name
"kilometer-per-hour"
```

### Measurement system conversion

```elixir
iex> Units.format!(Units.eval!("100 meter to us"))
"0.062137 miles"

iex> Units.format!(Units.eval!("100 fahrenheit to metric"))
"37.777778 degrees Celsius"

iex> Units.format!(Units.eval!("100 meter to imperial"))
"0.062137 miles"

# "preferred" uses the current locale's measurement system
iex> Localize.put_locale(:de)
iex> Units.format!(Units.eval!("100 fahrenheit to preferred"))
"37.777778 Grad Celsius"
```

### Locale-aware output

```elixir
iex> result = Units.eval!("1234.5 meter to kilometer")
iex> Units.format!(result, locale: :de)
"1,234 Kilometer"
iex> Units.format!(result, locale: :ja)
"1.234 キロメートル"
```

## Interactive REPL

```
$ mix run -e "Units.Repl.start()"
Units v0.1.0 — type "help" for commands, "quit" to exit

> 3 meters to feet
9.843 feet

> 60 mph to km/h
96.561 kilometers per hour

> 100 kg * 9.8 m/s^2
980 kilogram-meter-per-square-second

> 1 gallon to liters
3.785 liters

> 12 ft + 3 in to ft
12.25 feet

> sqrt(9 m^2)
3 meters

> _ to cm
300 centimeters

> 1|3 cup to mL
78.863 milliliters

> 3.756 hours to h;min;s
3 hours, 45 minutes, 21.6 seconds

> let distance = 42.195 km
42.195 kilometers

> let time = 2 hours
2 hours

> distance / time
21.098 kilometers per hour

> locale de
Locale set to :de

> 1234.5 meter to kilometer
1,234 Kilometer
```

## CLI (escript)

Build and install the escript:

```bash
mix escript.build
```

Usage:

```bash
# Interactive mode
./units

# Single conversion
./units "3 meters to feet"

# Two-argument conversion (GNU units style)
./units "3 meters" "feet"

# Verbose mode
./units -v "1 gallon" "liters"

# Terse mode (for scripts)
./units -t "100 celsius" "fahrenheit"

# Locale-aware output
./units --locale de "1234.5 meter to kilometer"

# Read from stdin
echo "3 meters" | ./units - feet

# Pipe-friendly
echo "3 meters to feet" | ./units

# List unit categories
./units --list

# List units in a category
./units --list length

# List conformable units
./units --conformable meter
```

## Expression syntax

| Syntax | Example | Description |
|---|---|---|
| Conversion | `3 meters to feet`, `3 m -> cm`, `3 m in cm` | Convert between units |
| Addition | `12 ft + 3 in` | Add compatible units |
| Subtraction | `10 km - 3 km` | Subtract compatible units |
| Multiplication | `100 kg * 9.8 m` | Multiply units or values |
| Division | `100 m / 10 s`, `5 miles per hour` | Divide units, `per` = `/` |
| Exponentiation | `m^2`, `s^-2`, `cm3` | Powers and concatenated exponents |
| Juxtaposition | `kg m / s^2` | Space = implicit `*`, higher precedence than `/` |
| Parentheses | `(3 + 4) m` | Grouping |
| Functions | `sqrt(9 m^2)`, `abs(-5 m)` | Built-in math functions |
| Rationals | `1\|3 cup` | Rational numbers (GNU `units` style) |
| Variables | `let x = 42 km` | Variable binding |
| Previous result | `_`, `_ to cm` | Refer to last REPL result |
| System target | `to metric`, `to us`, `to imperial`, `to SI` | Convert to measurement system |
| Preferred | `to preferred` | Convert to locale's preferred system |
| Mixed-unit | `3.756 hours to h;min;s` | Decompose into multiple units |

## Operator precedence (highest to lowest)

| Precedence | Operators | Description |
|---|---|---|
| 1 | `^`, concatenated exponent | `cm^3`, `m2` |
| 2 | juxtaposition (space) | `kg m` = `kg * m` |
| 3 | `*`, `/`, `per` | Explicit multiply/divide |
| 4 | `+`, `-` | Add/subtract (conformable units only) |
| 5 | `to`, `in`, `->` | Conversion (outermost) |

## Supported unit aliases

Over 150 common abbreviations are supported, including:

* **Length:** m, km, cm, mm, ft, in, yd, mi, nmi, ly

* **Mass:** g, kg, mg, lb, oz, t, st

* **Time:** s, ms, min, h, d, wk, yr

* **Temperature:** °C, °F, K, celsius, fahrenheit, kelvin

* **Speed:** mph, kph, mps, kn

* **Volume:** L, mL, gal, qt, pt, cup, tbsp, tsp, floz

* **Energy:** J, kJ, cal, kcal, kWh, eV, BTU

* **Power:** W, kW, MW, hp

* **Pressure:** Pa, kPa, atm, psi

* **Frequency:** Hz, kHz, MHz, GHz

* **Force:** N, kN, lbf

* **And more:** area, angle, digital, electric, light, radiation units

All CLDR unit names (meter, kilogram, second, etc.) and SI-prefixed forms (kilometer, milligram, gigahertz, etc.) are accepted directly.

## License

Apache-2.0
