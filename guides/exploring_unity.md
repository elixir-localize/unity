# Exploring Unity

This guide walks through Unity's features with hands-on examples — from basic conversions to GNU Units imports, nonlinear scales, date arithmetic, and localized output.

## Getting started

Unity can be used three ways: as an Elixir library, an interactive REPL, or a command-line tool.

### As a library

```elixir
iex> {:ok, result, _env} = Unity.eval("3 meters to feet")
iex> result.value
9.84251968503937

iex> Unity.format!(Unity.eval!("60 mph to km/h"))
"96.56064 kilometers per hour"
```

The `eval/2` function returns `{:ok, result, environment}` where `result` is a `Localize.Unit` struct (or a plain number) and `environment` carries variable bindings forward.

### As a REPL

```
$ iex -S mix
iex> Unity.Repl.start()
Unity v0.5.0 — type "help" for commands, "quit" to exit

> 3 meters to feet
9.84252 feet

> _ to inches
118.11024 inches
```

The REPL provides tab completion for unit names and functions, command history across sessions, and full line editing (arrow keys, Ctrl-A/E, etc.).

### As a CLI

Build the escript with `mix escript.build`, then:

```bash
# Single conversion
./unity "3 meters to feet"

# Two-argument style (like GNU units)
./unity "3 meters" "feet"

# Verbose output (shows from = to)
./unity -v "1 gallon" "liters"

# Terse output (just the number, for scripting)
./unity -t "100 celsius" "fahrenheit"

# Pipe from stdin
echo "3 meters to feet" | ./unity

# List unit categories
./unity --list

# Find conformable units
./unity --conformable meter
```

## Expressions

### Arithmetic with units

Addition and subtraction require conformable (same-dimension) units. The result uses the first operand's unit:

```
> 12 ft + 3 in
12.25 feet

> 10 km - 3000 meters
7 kilometers
```

Multiplication and division create compound units:

```
> 100 kg * 9.8 m/s^2
980 kilogram-meter-per-square-second

> 100 miles / 2 hours
50 miles per hour
```

Juxtaposition (space between factors) is implicit multiplication with higher precedence than `/`, matching GNU `units` behaviour:

```
> kg m / s^2
1 kilogram-meter-per-square-second
```

### Number formats

```
> 1|3 cup to mL
78.862746 milliliters

> 0xFF
255

> 0b1010
10

> 1_000_000 meters to km
1,000 kilometers
```

Rational numbers use the `|` operator (`1|3` = one-third). Hex (`0xFF`), octal (`0o77`), and binary (`0b1010`) literals are supported. Underscores can separate digit groups for readability.

### Variables

```
> let distance = 42.195 km
42.195 kilometers

> let time = 2 hours + 5 minutes + 30 seconds
2.091667 hours

> distance / time
20.172414 kilometers per hour

> bindings
  _ = 20.172414 kilometers per hour
  distance = 42.195 kilometers
  time = 2.091667 hours
```

Variables persist across expressions within a session. The special variable `_` always holds the previous result.

### Conversion

Three conversion syntaxes are supported:

```
> 100 celsius to fahrenheit
212 degrees Fahrenheit

> 100 celsius -> fahrenheit
212 degrees Fahrenheit

> 100 celsius in fahrenheit
212 degrees Fahrenheit
```

### Mixed-unit decomposition

Semicolons in the target decompose a value across multiple units:

```
> 3.756 hours to h;min;s
3 hours, 45 minutes, 21.6 seconds

> 1.7 meters to ft;in
5 feet, 6.929134 inches
```

### Measurement systems

Convert to a locale's preferred unit system:

```
> 100 meter to us
0.062137 miles

> 100 fahrenheit to metric
37.777778 degrees Celsius

> 100 meter to imperial
0.062137 miles
```

The `to preferred` target uses the current locale's measurement system:

```
> locale de
Locale set to :de

> 100 fahrenheit to preferred
37,777778 Grad Celsius
```

## Unit names and aliases

Unity accepts CLDR unit names (`meter`, `kilogram`, `second`), over 150 common abbreviations, and SI-prefixed forms.

### Common aliases

| Alias | Unit |
|---|---|
| `m`, `km`, `cm`, `mm` | meter, kilometer, centimeter, millimeter |
| `ft`, `in`, `yd`, `mi` | foot, inch, yard, mile |
| `kg`, `g`, `lb`, `oz` | kilogram, gram, pound, ounce |
| `s`, `ms`, `min`, `h` | second, millisecond, minute, hour |
| `°C`, `°F`, `K` | celsius, fahrenheit, kelvin |
| `mph`, `kph`, `kn` | mile-per-hour, kilometer-per-hour, knot |
| `L`, `mL`, `gal`, `cup` | liter, milliliter, gallon, cup |
| `J`, `kJ`, `cal`, `kWh` | joule, kilojoule, calorie, kilowatt-hour |
| `W`, `kW`, `hp` | watt, kilowatt, horsepower |
| `Pa`, `atm`, `psi` | pascal, atmosphere, pound-per-square-inch |
| `Hz`, `kHz`, `MHz` | hertz, kilohertz, megahertz |
| `N`, `lbf` | newton, pound-force |

Unknown names produce fuzzy suggestions:

```
> 3 feets to meters
  unknown unit: "feets"
  Did you mean: "feet", "foot", "meter"?
```

### SI prefixes on custom units

After importing GNU Units definitions, SI prefixes work on custom units automatically:

```
> 1 lightsecond to km
299,792.458 kilometers

> 1 millilightsecond to meters
299,792.458 meters

> 1 kilofurlong to miles
124.274238 miles
```

Power prefixes also work:

```
> 5 square-smoot to square-meter
14.4806 square meters
```

## Functions

### Dimension-aware functions

These operate on units and adjust dimensions accordingly:

```
> sqrt(9 m^2)
3 meters

> cbrt(27 cubic-meter)
3 meters

> abs(-5 kg)
5 kilograms

> round(3.756 hours)
4 hours
```

`sqrt` requires even powers on all dimensions; `cbrt` requires powers divisible by 3.

### Dimensionless functions

Trigonometric, hyperbolic, and logarithmic functions require dimensionless input (angles or ratios):

```
> sin(90 degree)
1

> cos(0 radian)
1

> sinh(1)
1.175201

> ln(100 percent)
-4.60517
```

Passing a dimensioned value is an error:

```
> sin(3 meters)
  sin requires a dimensionless value, got unit with base: meter
```

### Two-argument functions

```
> atan2(1, 1)
0.785398

> hypot(3, 4)
5

> gcd(12, 8)
4

> lcm(4, 6)
12

> min(3, 7)
3

> max(3, 7)
7

> mod(10, 3)
1

> factorial(10)
3628800
```

### Introspection

```
> unit_of(9.8 m/s^2)
meter-per-square-second

> value_of(42 kg)
42

> is_dimensionless(45 degree)
true

> is_dimensionless(3 meters)
false
```

### Percentages

```
> increase_by(100 meters, 15)
115 meters

> decrease_by(1000 kg, 5)
950 kilograms

> percentage_change(50 km, 75 km)
50
```

### Date and time

```
> now()
2026-04-13T18:30:00.000000Z

> let launch = datetime("2025-03-15T09:00:00Z")
2025-03-15T09:00:00Z

> now() - launch
34300200 seconds

> _ to days
396.99306 days

> launch + 365 days
2026-03-15T09:00:00Z

> unixtime(0)
1970-01-01T00:00:00Z

> timestamp(launch)
1742029200

> today()
2026-04-13
```

### Assertions

Verify unit equivalences, useful for teaching and spot-checking:

```
> assert_eq(12 inch, 1 foot)
true

> assert_eq(1 mile, 1.60934 km, 1 meter)
true

> assert_eq(1 meter, 1 foot)
  assertion failed: 1 meter != 1 foot
```

The optional third argument is a tolerance.

## Importing GNU Units

The `Unity.GnuUnitsImporter` parses the GNU `units` definition file and registers ~2,760 entries: ~2,440 linear units, ~250 dimensionless constants, and ~75 nonlinear conversion functions.

```elixir
iex> {:ok, stats} = Unity.GnuUnitsImporter.import()
iex> stats.imported
2438
iex> map_size(stats.constants)
250
```

After importing, thousands of additional units become available:

```
> 3 furlongs to meters
603.504 meters

> 1 fathom to feet
6 feet

> 1 stone to kg
6.350293 kilograms

> 1 troy-ounce to grams
31.103477 grams
```

### Nonlinear conversions

Imported functions work both as function calls and as unit conversions:

```
> tempc(100)
373.15 kelvin

> 100 tempc to fahrenheit
212 fahrenheit

> dbm(0)
0.001 kilogram-square-meter-per-cubic-second

> wiregauge(12)
0.002053 meter

> baume(10)
1,074.074074 kilogram-per-cubic-meter

> ph(7)
0.0001 item-per-cubic-meter
```

### Constants as bindings

Dimensionless constants are returned as a map suitable for `let` bindings:

```elixir
iex> {:ok, stats} = Unity.GnuUnitsImporter.import()
iex> {:ok, result, _} = Unity.eval("dozen * 3 meters", stats.constants)
iex> result.value
36.0
```

In the REPL, pass constants as the initial environment:

```
> gross kg
144 kilograms

> avogadro
6.02214076e23
```

### Exporting for repeatable loading

```elixir
# Export to a file for use without re-parsing
{:ok, count} = Unity.GnuUnitsImporter.export("priv/gnu_units.exs")

# Load at application startup
Localize.Unit.load_custom_units("priv/gnu_units.exs")
```

The CLI supports loading via the `-f` flag:

```bash
./unity -f priv/gnu_units.exs "3 furlongs to meters"
```

## Localization

Unity produces locale-aware output via Localize's CLDR data. Number formatting, unit names, and plural forms adapt to the locale.

### Switching locales

In the REPL:

```
> 1234.5 meter to kilometer
1.2345 kilometers

> locale de
Locale set to :de

> 1234.5 meter to kilometer
1,2345 Kilometer

> locale ja
Locale set to :ja

> 1234.5 meter to kilometer
1.2345 キロメートル

> locale fr
Locale set to :fr

> 2.5 kilogram
2,5 kilogrammes
```

From the CLI:

```bash
./unity --locale de "1234.5 meter to kilometer"
# 1,2345 Kilometer
```

From the library:

```elixir
iex> result = Unity.eval!("2.5 kilogram")
iex> Unity.format!(result, locale: :de)
"2,5 Kilogramm"
iex> Unity.format!(result, locale: :ja)
"2.5 キログラム"
```

### Plural-aware formatting

CLDR formatting automatically selects the correct plural form:

```
> 1 kilometer
1 kilometer

> 2 kilometer
2 kilometers

> locale de
Locale set to :de

> 1 kilometer
1 Kilometer

> 2 kilometer
2 Kilometer
```

(German doesn't pluralise "Kilometer" — CLDR handles this correctly.)

### Output formats

```bash
# Default: value and unit name
./unity "3 meters to feet"
# 9.84252 feet

# Verbose: shows from = to
./unity -v "3 meters to feet"
# 3 meters = 9.84252 feet

# Terse: bare number only
./unity -t "3 meters to feet"
# 9.84252

# Control precision
./unity -d 2 "3 meters to feet"
# 9.84 feet

# Scientific notation
./unity -e "1 lightyear to km"
# 9.460730e12 kilometers

# Printf-style format
./unity -o "%.10g" "pi radians to degrees"
```

## REPL commands

| Command | Description |
|---|---|
| `help` | Show syntax help and available commands |
| `bindings` | Show current variable bindings |
| `list` | List unit categories |
| `list length` | List units in a category |
| `search text` | Search unit names containing text |
| `conformable meter` | List units convertible with meter |
| `info meter` | Show unit info, aliases, and conformable units |
| `locale de` | Switch display locale |
| `quit` / `exit` | Exit the REPL |

Tab completion works for unit names, function names, and commands.

## Operator precedence

From highest to lowest:

| Precedence | Operators |
|---|---|
| 1 | `^`, `**`, concatenated exponent (`cm3`) |
| 2 | juxtaposition (space = implicit `*`) |
| 3 | `*`, `/`, `per` |
| 4 | `+`, `-` |
| 5 | `to`, `in`, `->` (conversion) |
