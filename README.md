# Unity

An Elixir unit conversion calculator inspired by the Unix [`units`](https://www.gnu.org/software/units/) utility. Powered by [Localize](https://github.com/elixir-localize/localize) for unit conversion, arithmetic, and locale-aware output in 500+ locales.

## Quick taste

```
> 3 meters to feet
9.84252 feet

> 100 kg * 9.8 m/s^2
980 kilogram-meter-per-square-second

> 1|3 cup to mL
78.862746 milliliters

> 3.756 hours to h;min;s
3 hours, 45 minutes, 21.6 seconds

> sqrt(9 m^2)
3 meters

> locale de
Locale set to :de

> 1234,5 meter to kilometer
1,2345 Kilometer
```

## Installation

Add `unity` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:unity, "~> 0.5"}
  ]
end
```

## Three ways to use it

**As a library** — embed unit evaluation in any Elixir application:

```elixir
iex> {:ok, result, _env} = Unity.eval("3 meters to feet")
iex> result.value
9.84251968503937
```

**As a REPL** — interactive calculator with tab completion and history:

```bash
$ iex -S mix
iex> Unity.Repl.start()
```

**As a CLI** — single-expression evaluation and scripting:

```bash
$ mix escript.build
$ ./unity "3 meters to feet"
$ ./unity -v "1 gallon" "liters"
$ echo "100 celsius to fahrenheit" | ./unity
```

## What's included

* 155 CLDR base units with full SI prefix support (thousands of prefixed variants).
* ~2,440 additional units imported from GNU Units (furlong, fathom, smoot, lightsecond, ...).
* ~75 nonlinear conversions (decibel scales, temperature functions, wire gauges, density hydrometers, photographic exposure, atmospheric models, astronomical magnitudes).
* ~250 dimensionless constants (dozen, gross, avogadro, speed of light, ...).
* 36 built-in math functions including trig, hyperbolic, logarithmic, factorial, gcd/lcm.
* Date/time arithmetic, percentage calculations, unit introspection, and assertions.
* Locale-aware output in 500+ locales via CLDR.

See the [Exploring Unity](https://hexdocs.pm/unity/exploring_unity.html) guide for a detailed walkthrough with examples, or the [GNU Units Conformance](https://hexdocs.pm/unity/conformance.html) guide for a feature-by-feature comparison.

## A fun example from history

See https://www.ibiblio.org/harris/500milemail.html.

```
> 3 millilightsecond to mile
558.847191 miles
```

## References

* [GNU units](https://www.gnu.org/software/units/) — the inspiration for Unity.
* [Numbat](https://github.com/sharkdp/numbat) — a statically typed programming language for scientific computations with first-class physical units.
* [Localize](https://github.com/elixir-localize/localize) — CLDR-based internationalization for Elixir (powers Unity's unit engine).

## License

Apache 2.0 (See LICENSE.md)
