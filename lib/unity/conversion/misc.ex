defmodule Unity.Conversion.Misc do
  @moduledoc """
  Miscellaneous nonlinear conversions: geometry helpers, network
  subnet calculations, and other standalone functions.

  """

  @pi :math.pi()

  # ── Geometry ────────────────────────────────────────────────────

  @doc "Radius (m) to circle area (m²)."
  def circlearea_forward(r), do: @pi * r * r
  def circlearea_inverse(a), do: :math.sqrt(a / @pi)

  @doc "Radius (m) to sphere volume (m³)."
  def spherevolume_forward(r), do: 4.0 / 3.0 * @pi * :math.pow(r, 3)
  def spherevolume_inverse(v), do: :math.pow(v / (4.0 / 3.0 * @pi), 1 / 3)

  @doc "Value to its square (dimensionless)."
  def square_forward(x), do: x * x
  def square_inverse(x), do: :math.sqrt(x)

  # ── Network ─────────────────────────────────────────────────────

  @doc "IPv4 prefix length to subnet size (number of addresses)."
  def ipv4subnetsize_forward(prefix_len), do: :math.pow(2, 32 - prefix_len)
  def ipv4subnetsize_inverse(size), do: 32 - :math.log2(size)

  @doc "IPv6 prefix length to subnet size (number of addresses)."
  def ipv6subnetsize_forward(prefix_len), do: :math.pow(2, 128 - prefix_len)
  def ipv6subnetsize_inverse(size), do: 128 - :math.log2(size)
end
