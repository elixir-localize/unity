defmodule Unity.Conversion.Astronomy do
  @moduledoc """
  Nonlinear conversions for astronomical magnitude and surface
  brightness scales.

  """

  # ── Visual magnitude ────────────────────────────────────────────

  # vmag(m) = 2.54e-6 lux * 10^(-0.4 * m) → lux (cd·sr/m² in SI)
  @vmag_ref 2.54e-6

  @doc "Visual magnitude to illuminance in lux."
  def vmag_forward(mag), do: @vmag_ref * :math.pow(10, -0.4 * mag)
  def vmag_inverse(lux), do: -2.5 * :math.log10(lux / @vmag_ref)

  # ── Surface brightness per solid angle ──────────────────────────

  # SB_degree(m) = vmag(m) / squaredegree → cd/m² (luminance)
  # SB_minute(m) = vmag(m) / squareminute → cd/m²
  # SB_second(m) = vmag(m) / squaresecond → cd/m²
  # SB_sr(m)     = vmag(m) / steradian    → cd/m²

  @squaredegree 3.0461741978670857e-4
  @squareminute 8.461594994075239e-8
  @squaresecond 2.3504430539097885e-11
  @steradian 1.0

  @doc "Surface brightness (mag/deg²) to luminance in cd/m²."
  def sb_degree_forward(mag), do: vmag_forward(mag) / @squaredegree
  def sb_degree_inverse(l), do: vmag_inverse(l * @squaredegree)

  @doc "Surface brightness (mag/arcmin²) to luminance in cd/m²."
  def sb_minute_forward(mag), do: vmag_forward(mag) / @squareminute
  def sb_minute_inverse(l), do: vmag_inverse(l * @squareminute)

  @doc "Surface brightness (mag/arcsec²) to luminance in cd/m²."
  def sb_second_forward(mag), do: vmag_forward(mag) / @squaresecond
  def sb_second_inverse(l), do: vmag_inverse(l * @squaresecond)

  @doc "Surface brightness (mag/sr) to luminance in cd/m²."
  def sb_sr_forward(mag), do: vmag_forward(mag) / @steradian
  def sb_sr_inverse(l), do: vmag_inverse(l * @steradian)
end
