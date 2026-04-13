defmodule Unity.Conversion.Atmospheric do
  @moduledoc """
  Nonlinear conversions for atmospheric and geophysical functions.

  Includes standard atmosphere pressure and temperature profiles,
  geopotential height, gravitational acceleration by latitude,
  and air mass calculations.

  """

  # Standard atmosphere constants
  # K (sea-level temperature)
  @stdatm_t0 288.15
  # K/m (temperature lapse rate)
  @lapserate 0.0065
  # Pa (standard atmospheric pressure)
  @atm 101_325.0
  # m (Earth radius for US standard atmosphere)
  @earth_rad 6_356_766.0

  # g/R ratio used in barometric formula: g₀·M/(R·L)
  # polyndx = g/(lapserate R_air) - 1 ≈ 4.2559
  @polyndx 4.2559

  # ── Standard atmosphere temperature ──────────────────────────────

  # stdatmTH(h) = T0 - lapserate * h (geopotential height → temperature)
  # Valid for troposphere: h ∈ [-5000, 11000] m
  @doc "Geopotential height (m) to standard atmosphere temperature (K)."
  def stdatm_th_forward(h), do: @stdatm_t0 - @lapserate * h
  def stdatm_th_inverse(t), do: (@stdatm_t0 - t) / @lapserate

  # stdatmT(z) = stdatmTH(geop_ht(z)) — geometric altitude version
  @doc "Geometric altitude (m) to standard atmosphere temperature (K)."
  def stdatm_t_forward(z) do
    h = geopotential_height(z)
    stdatm_th_forward(h)
  end

  def stdatm_t_inverse(t) do
    h = stdatm_th_inverse(t)
    geometric_altitude(h)
  end

  # ── Standard atmosphere pressure ─────────────────────────────────

  # stdatmPH(h) = atm * (1 - L·h/T0)^(g/(L·R) - 1)
  @doc "Geopotential height (m) to standard atmosphere pressure (Pa)."
  def stdatm_ph_forward(h) do
    @atm * :math.pow(1 - @lapserate / @stdatm_t0 * h, @polyndx + 1)
  end

  def stdatm_ph_inverse(p) do
    @stdatm_t0 / @lapserate * (1 - :math.pow(p / @atm, 1 / (@polyndx + 1)))
  end

  # stdatmP(z) = stdatmPH(geop_ht(z)) — geometric altitude version
  @doc "Geometric altitude (m) to standard atmosphere pressure (Pa)."
  def stdatm_p_forward(z) do
    h = geopotential_height(z)
    stdatm_ph_forward(h)
  end

  def stdatm_p_inverse(p) do
    h = stdatm_ph_inverse(p)
    geometric_altitude(h)
  end

  # ── Geopotential height ─────────────────────────────────────────

  # geop_ht(z) = R·z / (R + z)
  @doc "Geometric altitude (m) to geopotential height (m)."
  def geopotential_forward(z), do: @earth_rad * z / (@earth_rad + z)
  def geopotential_inverse(h), do: @earth_rad * h / (@earth_rad - h)

  defp geopotential_height(z), do: geopotential_forward(z)
  defp geometric_altitude(h), do: geopotential_inverse(h)

  # ── Gravitational acceleration by latitude ──────────────────────

  # g_phi(lat) = 9.80616 * (1 - 0.0026373·cos(2φ) + 0.0000059·cos²(2φ)) m/s²
  @doc "Latitude (degrees) to local gravitational acceleration (m/s²)."
  def g_phi_forward(lat_deg) do
    lat = lat_deg * :math.pi() / 180
    9.80616 * (1 - 0.0026373 * :math.cos(2 * lat) + 0.0000059 * :math.pow(:math.cos(2 * lat), 2))
  end

  # g_phi is not cleanly invertible (cosine is periodic), return the latitude unchanged.
  def g_phi_inverse(g), do: g

  # ── Effective Earth radius ──────────────────────────────────────

  # earthradius_eff(lat) — effective radius for atmospheric refraction
  @doc "Latitude (degrees) to effective Earth radius (m)."
  def earthradius_eff_forward(lat_deg) do
    lat = lat_deg * :math.pi() / 180

    numerator =
      2 * 9.780356 *
        (1 + 0.0052885 * :math.pow(:math.sin(lat), 2) -
           0.0000059 * :math.pow(:math.sin(2 * lat), 2))

    denominator = 3.085462e-6 + 2.27e-9 * :math.cos(2 * lat) - 2.0e-12 * :math.cos(4 * lat)
    numerator / denominator
  end

  def earthradius_eff_inverse(r), do: r

  # ── Air mass ────────────────────────────────────────────────────

  # airmass(alt) = 1 / (sin(alt) + 0.50572·(alt/degree + 6.07995)^-1.6364)
  # Kasten & Young (1989) formula
  @doc "Solar altitude (degrees) to relative air mass (dimensionless)."
  def airmass_forward(alt_deg) do
    alt_rad = alt_deg * :math.pi() / 180
    1 / (:math.sin(alt_rad) + 0.50572 * :math.pow(alt_deg + 6.07995, -1.6364))
  end

  def airmass_inverse(am), do: am

  # airmassz(zenith) — same but measured from zenith
  @doc "Solar zenith angle (degrees) to relative air mass (dimensionless)."
  def airmassz_forward(zenith_deg) do
    zen_rad = zenith_deg * :math.pi() / 180
    1 / (:math.cos(zen_rad) + 0.50572 * :math.pow(96.07995 - zenith_deg, -1.6364))
  end

  def airmassz_inverse(am), do: am

  # ── Atmospheric transmission ────────────────────────────────────

  @extinction_coeff 0.21

  @doc "Solar altitude (degrees) to atmospheric transmission fraction."
  def atm_transmission_forward(alt_deg) do
    :math.exp(-@extinction_coeff * airmass_forward(alt_deg))
  end

  def atm_transmission_inverse(t), do: t

  @doc "Solar zenith angle (degrees) to atmospheric transmission fraction."
  def atm_transmissionz_forward(zenith_deg) do
    :math.exp(-@extinction_coeff * airmassz_forward(zenith_deg))
  end

  def atm_transmissionz_inverse(t), do: t

  # ── Gauge pressure ──────────────────────────────────────────────

  @doc "Gauge reading (Pa) to absolute pressure (Pa)."
  def gaugepressure_forward(x), do: x + @atm
  def gaugepressure_inverse(p), do: p - @atm

  # psig: gauge reading in psi → absolute pressure in Pa
  @psi 6894.75729316836

  @doc "Gauge reading (psi) to absolute pressure (Pa)."
  def psig_forward(x), do: x * @psi + @atm
  def psig_inverse(p), do: (p - @atm) / @psi
end
