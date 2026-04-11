defmodule Units.Aliases do
  @moduledoc """
  Maps user-friendly unit abbreviations and common names to CLDR unit identifiers
  recognized by `Localize.Unit`.

  The alias table is built at compile time from a hand-curated abbreviation map.
  Resolution tries the alias table first, then falls back to passing the name
  directly to `Localize.Unit.new/1` to see if it is already a valid CLDR name.

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
    "feet" => "foot",
    "in" => "inch",
    "inches" => "inch",
    "yd" => "yard",
    "yards" => "yard",
    "mi" => "mile",
    "miles" => "mile",
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
    "pounds" => "pound",
    "oz" => "ounce",
    "ounces" => "ounce",
    "t" => "tonne",
    "tons" => "ton",
    "tonnes" => "tonne",
    "st" => "stone",

    # Time
    "s" => "second",
    "sec" => "second",
    "secs" => "second",
    "seconds" => "second",
    "ms" => "millisecond",
    "µs" => "microsecond",
    "us" => "microsecond",
    "ns" => "nanosecond",
    "min" => "minute",
    "mins" => "minute",
    "minutes" => "minute",
    "h" => "hour",
    "hr" => "hour",
    "hrs" => "hour",
    "hours" => "hour",
    "d" => "day",
    "days" => "day",
    "wk" => "week",
    "weeks" => "week",
    "yr" => "year",
    "yrs" => "year",
    "years" => "year",

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
    "knots" => "knot",
    "c" => "light-speed",

    # Volume
    "L" => "liter",
    "l" => "liter",
    "liters" => "liter",
    "litres" => "liter",
    "mL" => "milliliter",
    "ml" => "milliliter",
    "dL" => "deciliter",
    "dl" => "deciliter",
    "cL" => "centiliter",
    "cl" => "centiliter",
    "kL" => "kiloliter",
    "kl" => "kiloliter",
    "gal" => "gallon",
    "gallons" => "gallon",
    "qt" => "quart",
    "pt" => "pint",
    "cups" => "cup",
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
    "ohm" => "ohm",
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
    "TB" => "terabyte",
    "b" => "bit",
    "kb" => "kilobit",
    "Mb" => "megabit",
    "Gb" => "gigabit",

    # Concentration
    "ppm" => "part-per-million",

    # Misc
    "px" => "pixel",
    "ct" => "carat",

    # Plural forms for common base units
    "meters" => "meter",
    "kilometres" => "kilometer",
    "kilometers" => "kilometer",
    "centimeters" => "centimeter",
    "centimetres" => "centimeter",
    "millimeters" => "millimeter",
    "millimetres" => "millimeter",
    "grams" => "gram",
    "kilograms" => "kilogram",
    "joules" => "joule",
    "watts" => "watt",
    "newtons" => "newton",
    "pascals" => "pascal",
    "amperes" => "ampere",
    "volts" => "volt",
    "hertz" => "hertz",
    "foot" => "foot",
    "inch" => "inch"
  }

  @all_known_names Localize.Unit.known_units_by_category()
                   |> Enum.flat_map(fn {_category, names} -> names end)
                   |> MapSet.new()

  @doc """
  Resolves a user-provided unit name to a CLDR unit identifier.

  Tries the alias table first, then checks if the name is already a valid
  CLDR unit name. Returns `{:ok, cldr_name}` or `{:error, :unknown_unit}`.

  ### Arguments

  * `name` - a string unit name or abbreviation.

  ### Returns

  * `{:ok, cldr_name}` if the name resolves to a known unit.

  * `{:error, :unknown_unit}` if the name cannot be resolved.

  ### Examples

      iex> Units.Aliases.resolve("km")
      {:ok, "kilometer"}

      iex> Units.Aliases.resolve("meter")
      {:ok, "meter"}

      iex> Units.Aliases.resolve("frobnicator")
      {:error, :unknown_unit}

  """
  @spec resolve(String.t()) :: {:ok, String.t()} | {:error, :unknown_unit}
  def resolve(name) do
    case Map.get(@aliases, name) do
      nil ->
        if MapSet.member?(@all_known_names, name) do
          {:ok, name}
        else
          try_as_cldr_name(name)
        end

      cldr_name ->
        {:ok, cldr_name}
    end
  end

  @doc """
  Returns a list of all known alias names (the keys of the alias table).

  """
  @spec known_aliases() :: [String.t()]
  def known_aliases do
    Map.keys(@aliases)
  end

  @doc """
  Returns all known unit names (both aliases and CLDR base names).

  """
  @spec all_known_names() :: MapSet.t()
  def all_known_names do
    @all_known_names
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

    all_names = Map.keys(@aliases) ++ MapSet.to_list(@all_known_names)

    all_names
    |> Enum.map(fn known -> {known, String.jaro_distance(name, known)} end)
    |> Enum.filter(fn {_known, distance} -> distance >= threshold end)
    |> Enum.sort_by(fn {_known, distance} -> distance end, :desc)
    |> Enum.uniq_by(fn {known, _distance} -> resolve_to_cldr(known) end)
    |> Enum.take(max_results)
  end

  defp resolve_to_cldr(name) do
    Map.get(@aliases, name, name)
  end

  defp try_as_cldr_name(name) do
    case Localize.Unit.new(name) do
      {:ok, _unit} -> {:ok, name}
      {:error, _} -> {:error, :unknown_unit}
    end
  end
end
