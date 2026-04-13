defmodule Unity.Conversion.Gauge do
  @moduledoc """
  Nonlinear conversions for wire gauges, screw gauges, and shotgun gauges.

  """

  # ── American Wire Gauge (AWG) ───────────────────────────────────

  # wiregauge(g) = (1/200) * 92^((36 - g) / 39) inches → meters
  @inch 0.0254

  @doc "AWG gauge number to wire diameter in meters."
  def wiregauge_forward(g) do
    1.0 / 200.0 * :math.pow(92, (36 - g) / 39) * @inch
  end

  @doc "Wire diameter in meters to AWG gauge number."
  def wiregauge_inverse(m) do
    36 - 39 * :math.log(200 * m / @inch) / :math.log(92)
  end

  # ── Screw gauge ─────────────────────────────────────────────────

  # screwgauge(g) = (0.06 + 0.013 * g) inches → meters
  @doc "Screw gauge number to diameter in meters."
  def screwgauge_forward(g), do: (0.06 + 0.013 * g) * @inch

  @doc "Diameter in meters to screw gauge number."
  def screwgauge_inverse(m), do: (m / @inch - 0.06) / 0.013

  # ── Shotgun gauge ───────────────────────────────────────────────

  # shotgungauge(ga) = 2 * radius of a sphere whose volume = 1 lb / (ga * leaddensity)
  # Volume of sphere = 4/3 π r³, so r = (3V / 4π)^(1/3)
  # V = pound / (ga * leaddensity)
  @pound 0.45359237
  @lead_density 11340.0
  @pi :math.pi()

  @doc "Shotgun gauge number to bore diameter in meters."
  def shotgungauge_forward(ga) do
    volume = @pound / (ga * @lead_density)
    radius = :math.pow(3 * volume / (4 * @pi), 1 / 3)
    2 * radius
  end

  @doc "Bore diameter in meters to shotgun gauge number."
  def shotgungauge_inverse(diameter) do
    radius = diameter / 2
    volume = 4.0 / 3.0 * @pi * :math.pow(radius, 3)
    @pound / (volume * @lead_density)
  end
end
