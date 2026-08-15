defmodule Unity.Aliases do
  @moduledoc """
  Maps user-friendly unit abbreviations and common names to CLDR unit identifiers
  recognized by `Localize.Unit`.

  The alias table is built at compile time from a hand-curated abbreviation map
  plus a plural for every CLDR unit, derived by `Unity.Aliases.Plural`. Deriving
  the plurals rather than listing them keeps the table in step with the unit
  data: every unit that resolves in the singular also resolves in the plural,
  and a unit added to CLDR gets its plural without an edit here.

  Resolution tries, in order, the hand-written aliases, the name as a CLDR unit
  name, the derived plurals, and `Localize.Unit.new/1`. A name that still does
  not resolve is retried through the spelling rules in `Unity.Aliases.Plural`,
  which cover forms too numerous to enumerate — the plural of an SI-prefixed
  unit such as `milliseconds`, and British spellings such as `millilitres`.

  A retried spelling is accepted only if it is itself a known unit, so an
  ordinary English word is never promoted to a unit.

  """

  @aliases %{
    # Length
    "m" => "meter",
    "km" => "kilometer",
    "cm" => "centimeter",
    "mm" => "millimeter",
    "µm" => "micrometer",
    "um" => "micrometer",
    "nm" => "nanometer",
    "ft" => "foot",
    "in" => "inch",
    "yd" => "yard",
    "mi" => "mile",
    "nmi" => "nautical-mile",
    "au" => "astronomical-unit",
    "ly" => "light-year",
    "pc" => "parsec",

    # Mass
    "g" => "gram",
    "kg" => "kilogram",
    "mg" => "milligram",
    "µg" => "microgram",
    "ug" => "microgram",
    "lb" => "pound",
    "lbs" => "pound",
    "oz" => "ounce",
    "t" => "tonne",
    "st" => "stone",

    # Time
    "s" => "second",
    "sec" => "second",
    "secs" => "second",
    "ms" => "millisecond",
    "µs" => "microsecond",
    "us" => "microsecond",
    "ns" => "nanosecond",
    "min" => "minute",
    "mins" => "minute",
    "h" => "hour",
    "hr" => "hour",
    "hrs" => "hour",
    "d" => "day",
    "wk" => "week",
    "yr" => "year",
    "yrs" => "year",

    # Temperature
    "°C" => "celsius",
    "°F" => "fahrenheit",
    "K" => "kelvin",
    "degC" => "celsius",
    "degF" => "fahrenheit",
    "degR" => "rankine",

    # Speed
    "mph" => "mile-per-hour",
    "kph" => "kilometer-per-hour",
    "kmh" => "kilometer-per-hour",
    "mps" => "meter-per-second",
    "kn" => "knot",
    "c" => "light-speed",

    # Volume
    "L" => "liter",
    "l" => "liter",
    "mL" => "milliliter",
    "ml" => "milliliter",
    "dL" => "deciliter",
    "dl" => "deciliter",
    "cL" => "centiliter",
    "cl" => "centiliter",
    "kL" => "kiloliter",
    "kl" => "kiloliter",
    "gal" => "gallon",
    "qt" => "quart",
    "pt" => "pint",
    "tbsp" => "tablespoon",
    "tsp" => "teaspoon",
    "floz" => "fluid-ounce",
    "bbl" => "barrel",

    # Area
    "ha" => "hectare",
    "ac" => "acre",
    "sqm" => "square-meter",
    "sqft" => "square-foot",
    "sqkm" => "square-kilometer",
    "sqmi" => "square-mile",
    "sqin" => "square-inch",
    "sqyd" => "square-yard",

    # Energy
    "J" => "joule",
    "kJ" => "kilojoule",
    "MJ" => "megajoule",
    "cal" => "calorie",
    "kcal" => "foodcalorie",
    "Cal" => "foodcalorie",
    "Wh" => "watt-hour",
    "kWh" => "kilowatt-hour",
    "MWh" => "megawatt-hour",
    "eV" => "electronvolt",
    "BTU" => "british-thermal-unit",
    "btu" => "british-thermal-unit",
    "therm" => "therm-us",

    # Power
    "W" => "watt",
    "kW" => "kilowatt",
    "MW" => "megawatt",
    "GW" => "gigawatt",
    "hp" => "horsepower",

    # Pressure
    "Pa" => "pascal",
    "kPa" => "kilopascal",
    "MPa" => "megapascal",
    "hPa" => "hectopascal",
    "atm" => "atmosphere",
    "psi" => "pound-force-per-square-inch",

    # Frequency
    "Hz" => "hertz",
    "kHz" => "kilohertz",
    "MHz" => "megahertz",
    "GHz" => "gigahertz",

    # Force
    "N" => "newton",
    "kN" => "kilonewton",
    "lbf" => "pound-force",
    "kgf" => "kilogram-force",

    # Electric
    "A" => "ampere",
    "V" => "volt",
    "mA" => "milliampere",
    "kV" => "kilovolt",
    "F" => "farad",
    "Ω" => "ohm",
    "S" => "siemens",
    "C" => "coulomb",
    "H" => "henry",
    "T" => "tesla",
    "Wb" => "weber",

    # Radiation
    "Bq" => "becquerel",
    "Gy" => "gray",
    "Sv" => "sievert",

    # Light
    "lm" => "lumen",
    "lx" => "lux",
    "cd" => "candela",

    # Angle
    "deg" => "degree",
    "°" => "degree",
    "rad" => "radian",
    "rev" => "revolution",

    # Digital
    "B" => "byte",
    "kB" => "kilobyte",
    "MB" => "megabyte",
    "GB" => "gigabyte",
    "gb" => "gigabyte",
    "TB" => "terabyte",
    "b" => "bit",
    "kb" => "kilobit",
    "Mb" => "megabit",
    "Gb" => "gigabit",

    # Concentration
    "ppm" => "part-per-million",

    # Misc
    "px" => "pixel",
    "ct" => "carat"
  }

  # Plural forms are not listed above. They are derived from the CLDR unit list
  # by `@derived_plurals` below, and SI-prefixed and British spellings are
  # normalised at resolution time, so `months`, `centuries`, `milliseconds` and
  # `millilitres` all resolve without an entry here. Add an alias above only
  # for an abbreviation or a spelling no rule produces.

  @all_known_names_set Localize.Unit.known_units_by_category()
                       |> Enum.flat_map(fn {_category, names} -> names end)
                       |> MapSet.new()

  @all_known_names_list MapSet.to_list(@all_known_names_set)

  # A plural alias for every CLDR unit that has a distinct English plural, so
  # that anything resolving in the singular also resolves in the plural. A
  # derived plural never displaces a real unit name or a hand-written alias;
  # both take precedence, and the guards below keep it that way if CLDR later
  # adds a unit whose name collides with some other unit's plural.
  @derived_plurals for cldr_name <- @all_known_names_list,
                       plural <- Unity.Aliases.Plural.plural(cldr_name),
                       not MapSet.member?(@all_known_names_set, plural),
                       not is_map_key(@aliases, plural),
                       into: %{},
                       do: {plural, cldr_name}

  @doc """
  Resolves a user-provided unit name to a CLDR unit identifier.

  Tries the alias table first, then the name as a CLDR unit name, then the
  derived plural table. A name that still does not resolve is retried through
  the spelling rules in `Unity.Aliases.Plural`, which cover the plural of an
  SI-prefixed unit such as `milliseconds` and British spellings such as
  `millilitres`. Returns `{:ok, cldr_name}` or `{:error, :unknown_unit}`.

  A retried spelling is only accepted if it is itself a known unit, so an
  ordinary word is never promoted to a unit: `bricks` proposes `brick`, which
  is not a unit, and the call returns an error.

  ### Arguments

  * `name` - a string unit name or abbreviation.

  ### Returns

  * `{:ok, cldr_name}` if the name resolves to a known unit.

  * `{:error, :unknown_unit}` if the name cannot be resolved.

  ### Examples

      iex> Unity.Aliases.resolve("km")
      {:ok, "kilometer"}

      iex> Unity.Aliases.resolve("meter")
      {:ok, "meter"}

      iex> Unity.Aliases.resolve("months")
      {:ok, "month"}

      iex> Unity.Aliases.resolve("milliseconds")
      {:ok, "millisecond"}

      iex> Unity.Aliases.resolve("frobnicator")
      {:error, :unknown_unit}

  """
  @spec resolve(term()) :: {:ok, String.t()} | {:error, :unknown_unit}
  def resolve(name) when is_binary(name) do
    with :error <- lookup(name),
         :error <- lookup_respelled(name) do
      {:error, :unknown_unit}
    end
  end

  def resolve(_name) do
    {:error, :unknown_unit}
  end

  defp lookup(name) do
    cond do
      cldr_name = Map.get(@aliases, name) -> {:ok, cldr_name}
      MapSet.member?(@all_known_names_set, name) -> {:ok, name}
      cldr_name = Map.get(@derived_plurals, name) -> {:ok, cldr_name}
      true -> try_as_cldr_name(name)
    end
  end

  defp lookup_respelled(name) do
    name
    |> Unity.Aliases.Plural.candidates()
    |> Enum.find_value(:error, fn candidate ->
      case lookup(candidate) do
        {:ok, cldr_name} -> {:ok, cldr_name}
        :error -> nil
      end
    end)
  end

  @doc """
  Returns a list of all known alias names.

  Includes the hand-written abbreviations and the plurals derived from the CLDR
  unit list, but not the spellings normalised at resolution time, which are not
  an enumerable set.

  """
  @spec known_aliases() :: [String.t()]
  def known_aliases do
    Map.keys(@aliases) ++ Map.keys(@derived_plurals)
  end

  @doc """
  Returns all known unit names (both aliases and CLDR base names).

  """
  @spec all_known_names() :: [String.t()]
  def all_known_names do
    @all_known_names_list
  end

  @doc """
  Finds the closest matching unit names for a given unknown name using
  Jaro distance for fuzzy matching.

  ### Arguments

  * `name` - the unknown unit name to match against.

  * `options` - keyword list of options.

  ### Options

  * `:max_results` - maximum number of suggestions to return. Defaults to 5.

  * `:threshold` - minimum Jaro distance to include. Defaults to 0.7.

  ### Returns

  A list of `{cldr_name, distance}` tuples, sorted by distance descending.

  """
  @spec suggest(String.t(), keyword()) :: [{String.t(), float()}]
  def suggest(name, options \\ []) do
    max_results = Keyword.get(options, :max_results, 5)
    threshold = Keyword.get(options, :threshold, 0.7)

    all_names = known_aliases() ++ @all_known_names_list

    all_names
    |> Enum.map(fn known -> {known, String.jaro_distance(name, known)} end)
    |> Enum.filter(fn {_known, distance} -> distance >= threshold end)
    |> Enum.sort_by(fn {_known, distance} -> distance end, :desc)
    |> Enum.uniq_by(fn {known, _distance} -> resolve_to_cldr(known) end)
    |> Enum.take(max_results)
  end

  defp resolve_to_cldr(name) do
    Map.get(@aliases, name) || Map.get(@derived_plurals, name) || name
  end

  defp try_as_cldr_name(name) do
    case Localize.Unit.new(name) do
      {:ok, _unit} -> {:ok, name}
      {:error, _} -> :error
    end
  end
end
