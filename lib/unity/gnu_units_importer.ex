defmodule Unity.GnuUnitsImporter do
  @moduledoc """
  Imports unit definitions from a GNU `units` definition file into
  the Localize custom unit registry.

  Supports simple linear conversions, fractional definitions, compound
  expressions, and aliases. Function definitions (nonlinear conversions),
  conditional blocks, and directives are skipped.

  ## Usage

      # Import from the system default location
      {:ok, stats} = Unity.GnuUnitsImporter.import()

      # Import from a specific file
      {:ok, stats} = Unity.GnuUnitsImporter.import("/path/to/definitions.units")

      # Export to a .exs file for use with Localize.Unit.load_custom_units/1
      {:ok, count} = Unity.GnuUnitsImporter.export("priv/gnu_units.exs")

      # Parse without registering (for inspection)
      {:ok, parsed} = Unity.GnuUnitsImporter.parse("/path/to/definitions.units")

  """

  alias Unity.GnuUnitsImporter.{Parser, Resolver, Registrar}

  @bundled_path Application.app_dir(:unity, "priv/definitions.units")

  @system_paths [
    "/opt/homebrew/share/units/definitions.units",
    "/usr/share/units/definitions.units",
    "/usr/local/share/units/definitions.units"
  ]

  @doc """
  Imports GNU unit definitions and registers them via `Localize.Unit.define_unit/2`.

  ### Arguments

  * `path` — path to the definitions file. If omitted, uses the
    bundled file shipped with this library.

  ### Returns

  * `{:ok, stats}` where stats is a map with `:imported`, `:skipped`,
    `:errors`, and `:constants` keys. The `:constants` map contains
    dimensionless values (e.g., `"dozen" => 12.0`) suitable for use
    as `let` bindings in a Unity evaluation environment.

  * `{:error, reason}` if the file cannot be found or parsed.

  """
  @spec import(String.t() | nil) :: {:ok, map()} | {:error, String.t()}
  def import(path \\ nil) do
    with {:ok, file_path} <- find_file(path),
         {:ok, parsed} <- Parser.parse_file(file_path),
         {:ok, resolved} <- Resolver.resolve_all(parsed) do
      stats = Registrar.register_all(resolved)
      constants = Registrar.constants(resolved)
      register_special_conversions()
      {:ok, Map.put(stats, :constants, constants)}
    end
  end

  @temp Unity.Conversion.Temperature
  @db Unity.Conversion.Decibel
  @dens Unity.Conversion.Density
  @gauge Unity.Conversion.Gauge
  @size Unity.Conversion.Sizing
  @photo Unity.Conversion.Photography
  @atmo Unity.Conversion.Atmospheric
  @astro Unity.Conversion.Astronomy
  @misc Unity.Conversion.Misc

  # Base unit strings for compound SI dimensions
  @watt_base "kilogram-square-meter-per-cubic-second"
  @volt_base "kilogram-square-meter-per-cubic-second-ampere"
  @pascal_base "kilogram-per-meter-square-second"
  @lux_base "candela-per-square-meter"
  @luminance_base "candela-per-square-meter"
  @density_base "kilogram-per-cubic-meter"
  @energy_base "kilogram-square-meter-per-square-second"

  defp register_special_conversions do
    special_units = [
      # ── Temperature ──
      {"tempc", "kelvin", "temperature", @temp, :celsius_forward, :celsius_inverse},
      {"tempf", "kelvin", "temperature", @temp, :fahrenheit_forward, :fahrenheit_inverse},
      {"tempreaumur", "kelvin", "temperature", @temp, :reaumur_forward, :reaumur_inverse},
      {"tempcelsius", "kelvin", "temperature", @temp, :celsius_forward, :celsius_inverse},
      {"tempfahrenheit", "kelvin", "temperature", @temp, :fahrenheit_forward,
       :fahrenheit_inverse},

      # ── Decibel / logarithmic ──
      {"decibel", "part", "concentr", @db, :decibel_forward, :decibel_inverse},
      {"bel", "part", "concentr", @db, :bel_forward, :bel_inverse},
      {"neper", "part", "concentr", @db, :neper_forward, :neper_inverse},
      {"centineper", "part", "concentr", @db, :centineper_forward, :centineper_inverse},
      {"neper-power", "part", "concentr", @db, :neper_power_forward, :neper_power_inverse},
      {"db-amplitude", "part", "concentr", @db, :db_amplitude_forward, :db_amplitude_inverse},
      {"dbw", @watt_base, "power", @db, :dbw_forward, :dbw_inverse},
      {"dbm", @watt_base, "power", @db, :dbm_forward, :dbm_inverse},
      {"dbmw", @watt_base, "power", @db, :dbm_forward, :dbm_inverse},
      {"dbk", @watt_base, "power", @db, :dbk_forward, :dbk_inverse},
      {"dbf", @watt_base, "power", @db, :dbf_forward, :dbf_inverse},
      {"dbj", @energy_base, "energy", @db, :dbj_forward, :dbj_inverse},
      {"dbswl", @watt_base, "power", @db, :dbswl_forward, :dbswl_inverse},
      {"dbsil", @watt_base, "radiant-flux-density", @db, :dbsil_forward, :dbsil_inverse},
      {"dbv", @volt_base, "voltage", @db, :dbv_forward, :dbv_inverse},
      {"dbmv", @volt_base, "voltage", @db, :dbmv_forward, :dbmv_inverse},
      {"dbuv", @volt_base, "voltage", @db, :dbuv_forward, :dbuv_inverse},
      {"dbu", @volt_base, "voltage", @db, :dbu_forward, :dbu_inverse},
      {"dbv-legacy", @volt_base, "voltage", @db, :dbu_forward, :dbu_inverse},
      {"dba", "ampere", "electric-current", @db, :dba_forward, :dba_inverse},
      {"dbma", "ampere", "electric-current", @db, :dbma_forward, :dbma_inverse},
      {"dbua", "ampere", "electric-current", @db, :dbua_forward, :dbua_inverse},
      {"dbspl", @pascal_base, "pressure", @db, :dbspl_forward, :dbspl_inverse},
      {"musicalcent", "part", "concentr", @db, :musicalcent_forward, :musicalcent_inverse},
      {"bril", @luminance_base, "luminance", @db, :bril_forward, :bril_inverse},

      # ── Density scales ──
      {"baume", @density_base, "mass-density", @dens, :baume_forward, :baume_inverse},
      {"twaddell", @density_base, "mass-density", @dens, :twaddell_forward, :twaddell_inverse},
      {"quevenne", @density_base, "mass-density", @dens, :quevenne_forward, :quevenne_inverse},
      {"apidegree", @density_base, "mass-density", @dens, :apidegree_forward, :apidegree_inverse},
      {"ph", "item-per-cubic-meter", "concentration", @dens, :ph_forward, :ph_inverse},

      # ── Gauges ──
      {"wiregauge", "meter", "length", @gauge, :wiregauge_forward, :wiregauge_inverse},
      {"awg", "meter", "length", @gauge, :wiregauge_forward, :wiregauge_inverse},
      {"screwgauge", "meter", "length", @gauge, :screwgauge_forward, :screwgauge_inverse},
      {"shotgungauge", "meter", "length", @gauge, :shotgungauge_forward, :shotgungauge_inverse},

      # ── Sizing ──
      {"shoesize-men", "meter", "length", @size, :shoesize_men_forward, :shoesize_men_inverse},
      {"shoesize-women", "meter", "length", @size, :shoesize_women_forward,
       :shoesize_women_inverse},
      {"shoesize-boys", "meter", "length", @size, :shoesize_boys_forward, :shoesize_boys_inverse},
      {"shoesize-girls", "meter", "length", @size, :shoesize_girls_forward,
       :shoesize_girls_inverse},
      {"ringsize", "meter", "length", @size, :ringsize_forward, :ringsize_inverse},
      {"jpringsize", "meter", "length", @size, :jpringsize_forward, :jpringsize_inverse},
      {"euringsize", "meter", "length", @size, :euringsize_forward, :euringsize_inverse},
      {"scoop", "cubic-meter", "volume", @size, :scoop_forward, :scoop_inverse},

      # ── Photography / optics ──
      {"ev100", @luminance_base, "luminance", @photo, :ev100_forward, :ev100_inverse},
      {"iv100", @lux_base, "illuminance", @photo, :iv100_forward, :iv100_inverse},
      {"av-apex", "part", "concentr", @photo, :av_forward, :av_inverse},
      {"tv-apex", "second", "duration", @photo, :tv_forward, :tv_inverse},
      {"sv-apex", "part", "concentr", @photo, :sv_forward, :sv_inverse},
      {"bv-apex", @luminance_base, "luminance", @photo, :bv_forward, :bv_inverse},
      {"iv-apex", @lux_base, "illuminance", @photo, :iv_forward, :iv_inverse},
      {"sdeg", "part", "concentr", @photo, :sdeg_forward, :sdeg_inverse},
      {"fnumber", "part", "concentr", @photo, :fnumber_forward, :fnumber_inverse},
      {"numericalaperture", "part", "concentr", @photo, :na_forward, :na_inverse},

      # ── Atmospheric / geophysical ──
      {"stdatm-th", "kelvin", "temperature", @atmo, :stdatm_th_forward, :stdatm_th_inverse},
      {"stdatm-t", "kelvin", "temperature", @atmo, :stdatm_t_forward, :stdatm_t_inverse},
      {"stdatm-ph", @pascal_base, "pressure", @atmo, :stdatm_ph_forward, :stdatm_ph_inverse},
      {"stdatm-p", @pascal_base, "pressure", @atmo, :stdatm_p_forward, :stdatm_p_inverse},
      {"geopotential", "meter", "length", @atmo, :geopotential_forward, :geopotential_inverse},
      {"gaugepressure", @pascal_base, "pressure", @atmo, :gaugepressure_forward,
       :gaugepressure_inverse},
      {"psig", @pascal_base, "pressure", @atmo, :psig_forward, :psig_inverse},
      {"airmass", "part", "concentr", @atmo, :airmass_forward, :airmass_inverse},
      {"airmassz", "part", "concentr", @atmo, :airmassz_forward, :airmassz_inverse},

      # ── Astronomy ──
      {"vmag", @lux_base, "illuminance", @astro, :vmag_forward, :vmag_inverse},
      {"sb-degree", @luminance_base, "luminance", @astro, :sb_degree_forward, :sb_degree_inverse},
      {"sb-minute", @luminance_base, "luminance", @astro, :sb_minute_forward, :sb_minute_inverse},
      {"sb-second", @luminance_base, "luminance", @astro, :sb_second_forward, :sb_second_inverse},
      {"sb-sr", @luminance_base, "luminance", @astro, :sb_sr_forward, :sb_sr_inverse},

      # ── Geometry / network / misc ──
      {"circlearea", "square-meter", "area", @misc, :circlearea_forward, :circlearea_inverse},
      {"spherevolume", "cubic-meter", "volume", @misc, :spherevolume_forward,
       :spherevolume_inverse},
      {"ipv4subnetsize", "part", "concentr", @misc, :ipv4subnetsize_forward,
       :ipv4subnetsize_inverse},
      {"ipv6subnetsize", "part", "concentr", @misc, :ipv6subnetsize_forward,
       :ipv6subnetsize_inverse}
    ]

    Enum.each(special_units, fn {name, base_unit, category, module, fwd, inv} ->
      Localize.Unit.define_unit(name, %{
        base_unit: base_unit,
        factor: :special,
        category: category,
        forward: {module, fwd},
        inverse: {module, inv}
      })
    end)
  end

  @doc """
  Exports resolved GNU unit definitions to an `.exs` file compatible
  with `Localize.Unit.load_custom_units/1`.

  This allows generating the definitions once, inspecting or editing
  the output, and loading it at application startup without re-parsing
  the GNU file.

  ### Arguments

  * `output_path` — path for the output `.exs` file.

  * `input_path` — path to the GNU definitions file. If omitted,
    uses the bundled file shipped with this library.

  ### Returns

  * `{:ok, count}` with the number of definitions exported.

  * `{:error, reason}` on failure.

  """
  @spec export(String.t(), String.t() | nil) :: {:ok, non_neg_integer()} | {:error, String.t()}
  def export(output_path, input_path \\ nil) do
    with {:ok, file_path} <- find_file(input_path),
         {:ok, parsed} <- Parser.parse_file(file_path),
         {:ok, resolved} <- Resolver.resolve_all(parsed) do
      definitions = Registrar.to_definition_list(resolved)
      content = inspect(definitions, limit: :infinity, pretty: true, width: 100)
      File.write!(Path.expand(output_path), content <> "\n")
      {:ok, length(definitions)}
    end
  end

  @doc """
  Parses a GNU units definition file without registering or exporting.

  Useful for inspecting the parsed and resolved data.

  ### Arguments

  * `path` — path to the definitions file. If omitted, uses the
    bundled file shipped with this library.

  ### Returns

  * `{:ok, %{parsed: parsed, resolved: resolved}}` with the raw data.

  * `{:error, reason}` on failure.

  """
  @spec parse(String.t() | nil) :: {:ok, map()} | {:error, String.t()}
  def parse(path \\ nil) do
    with {:ok, file_path} <- find_file(path),
         {:ok, parsed} <- Parser.parse_file(file_path),
         {:ok, resolved} <- Resolver.resolve_all(parsed) do
      {:ok, %{parsed: parsed, resolved: resolved}}
    end
  end

  defp find_file(nil) do
    # Prefer the bundled file shipped with this library.
    # Fall back to system-installed GNU units if the bundled file is missing.
    all_paths = [@bundled_path | @system_paths]

    case Enum.find(all_paths, &File.exists?/1) do
      nil ->
        {:error, "GNU units definition file not found. Searched: #{Enum.join(all_paths, ", ")}"}

      path ->
        {:ok, path}
    end
  end

  defp find_file(path) do
    expanded = Path.expand(path)

    if File.exists?(expanded) do
      {:ok, expanded}
    else
      {:error, "file not found: #{expanded}"}
    end
  end
end
