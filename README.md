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
    {:unity, "~> 1.0"}
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

**As a REPL** — interactive calculator with tab completion and history, started from `iex -S mix`:

```elixir
iex> Unity.Repl.start()
```

The REPL renders its help and listings as markdown through [Marcli](https://hex.pm/packages/marcli) when your project includes `{:marcli, "~> 0.3"}`, and as plain text otherwise. Unity does not bring Marcli, or the MDEx NIF it depends on, into your project.

**As a CLI** — an escript for single expressions, scripts and an interactive session:

```bash
mix escript.install hex unity
```

```bash
unity "3 meters to feet"
unity -v "1 gallon" "liters"
echo "100 celsius to fahrenheit" | unity
unity
```

Given no expression on a terminal, `unity` starts the interactive session, with line editing, tab completion and history kept in `~/.unity_history`. The escript carries Localize's English data; any other locale, named with `--locale` or taken from the environment, is downloaded from the Localize CDN on first use and cached in the user cache directory (`~/.cache/localize` on Linux, `~/Library/Caches/localize` on macOS). To build the escript from a checkout, run `MIX_ENV=prod mix escript.build`.

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

`lightsecond` is one of the GNU Units definitions, so run
`Unity.GnuUnitsImporter.import/0` first to make it available:

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
