defmodule Unity.Conversion.Sizing do
  @moduledoc """
  Nonlinear conversions for shoe sizes, ring sizes, and scoop sizes.

  """

  # ── US shoe sizes ───────────────────────────────────────────────

  # shoesize(n) = offset + n * delta (in meters)
  # delta = 1 barleycorn / 3 ≈ 0.008467 m
  @delta 0.008466666666666667

  @men_offset 0.20955000000000001
  @women_offset 0.16298333333333334
  @boys_offset 0.06985000000000001
  @girls_offset 0.04445

  @doc "US men's shoe size to foot length in meters."
  def shoesize_men_forward(n), do: @men_offset + n * @delta
  def shoesize_men_inverse(m), do: (m - @men_offset) / @delta

  @doc "US women's shoe size to foot length in meters."
  def shoesize_women_forward(n), do: @women_offset + n * @delta
  def shoesize_women_inverse(m), do: (m - @women_offset) / @delta

  @doc "US boys' shoe size to foot length in meters."
  def shoesize_boys_forward(n), do: @boys_offset + n * @delta
  def shoesize_boys_inverse(m), do: (m - @boys_offset) / @delta

  @doc "US girls' shoe size to foot length in meters."
  def shoesize_girls_forward(n), do: @girls_offset + n * @delta
  def shoesize_girls_inverse(m), do: (m - @girls_offset) / @delta

  # ── Ring sizes ──────────────────────────────────────────────────

  @inch 0.0254

  # US ring size: circumference = (1.4216 + 0.1018 * n) inches → meters
  @doc "US ring size to circumference in meters."
  def ringsize_forward(n), do: (1.4216 + 0.1018 * n) * @inch
  def ringsize_inverse(m), do: (m / @inch - 1.4216) / 0.1018

  # Japanese ring size: circumference = (38/3 + n/3) * π mm → meters
  @mm 0.001
  @pi :math.pi()

  @doc "Japanese ring size to circumference in meters."
  def jpringsize_forward(n), do: (38.0 / 3.0 + n / 3.0) * @pi * @mm
  def jpringsize_inverse(m), do: 3.0 * m / (@pi * @mm) - 38.0

  # EU ring size: circumference = (n + 40) mm → meters
  @doc "EU ring size to circumference in meters."
  def euringsize_forward(n), do: (n + 40) * @mm
  def euringsize_inverse(m), do: m / @mm - 40

  # ── Scoop size ──────────────────────────────────────────────────

  # scoop(n) = 32 US fl oz / n → cubic meters
  @usfloz 2.957352956250001e-5
  @scoop_volume 32.0 * @usfloz

  @doc "Scoop number to volume in cubic meters."
  def scoop_forward(n), do: @scoop_volume / n
  def scoop_inverse(m3), do: @scoop_volume / m3
end
