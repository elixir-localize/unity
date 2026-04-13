defmodule Unity.Conversion.Photography do
  @moduledoc """
  Nonlinear conversions for photographic exposure scales.

  APEX system values (Av, Tv, Sv, Bv, Iv) and EV100/IV100 scales
  relate logarithmic exposure settings to physical quantities.

  """

  # Constants from GNU units definitions
  # N_speed = 0.32 cd·s·sr/m² (ISO 100 luminance-to-exposure constant)
  @n_speed 0.32
  # C_illum = 224 s⁻¹ (illuminance constant for ISO 100)
  @c_illum 224.0

  # s100 = 100 m²/(cd·s·sr) and k1250 relate to ISO speed

  # ── EV100 (exposure value at ISO 100) ───────────────────────────

  # ev100(x) = 2^x * k1250 / s100
  # k1250 = 12.5, s100 relates to ISO 100 speed
  # Simplified: ev100 produces cd/m² (luminance)
  # ev100(x) = 2^x * 12.5 / 100 = 2^x * 0.125 cd/m²
  @ev100_ref 0.125

  @doc "EV100 to luminance in cd/m²."
  def ev100_forward(x), do: :math.pow(2, x) * @ev100_ref
  def ev100_inverse(l), do: :math.log2(l / @ev100_ref)

  # ── IV100 (illuminance value at ISO 100) ─────────────────────────

  # iv100(x) = 2^x * c250 / s100 → lux
  # c250 = 250, s100 = 100 → 2^x * 2.5 lux
  @iv100_ref 2.5

  @doc "IV100 to illuminance in lux (cd·sr/m²)."
  def iv100_forward(x), do: :math.pow(2, x) * @iv100_ref
  def iv100_inverse(lux), do: :math.log2(lux / @iv100_ref)

  # ── Av (aperture value) ─────────────────────────────────────────

  # Av = log2(f-number²) → f-number = 2^(Av/2)
  # Dimensionless.
  @doc "APEX aperture value to f-number (dimensionless ratio)."
  def av_forward(x), do: :math.pow(2, x / 2)
  def av_inverse(f), do: 2 * :math.log2(f)

  # ── Tv (time value) ─────────────────────────────────────────────

  # Tv = -log2(exposure_time) → time = 2^(-Tv) seconds
  @doc "APEX time value to exposure time in seconds."
  def tv_forward(t), do: :math.pow(2, -t)
  def tv_inverse(s), do: -:math.log2(s)

  # ── Sv (speed value / ISO sensitivity) ──────────────────────────

  # Sv = log2(N_speed * S / lx·s) where S is ISO speed
  # Forward: Sv → ISO speed (dimensionless)
  # Sv(x) = 2^x / (N_speed/lx·s)
  # N_speed in appropriate units gives dimensionless result
  @doc "APEX speed value to ISO arithmetic speed (dimensionless)."
  def sv_forward(x), do: :math.pow(2, x) / @n_speed
  def sv_inverse(s), do: :math.log2(@n_speed * s)

  # ── Bv (brightness/luminance value) ─────────────────────────────

  # Bv(x) = 2^x * K_lum * N_speed → cd/m² (luminance)
  # K_lum ≈ 12.5 (luminance constant)
  @k_lum 12.5
  @bv_ref @k_lum * @n_speed

  @doc "APEX brightness value to luminance in cd/m²."
  def bv_forward(x), do: :math.pow(2, x) * @bv_ref
  def bv_inverse(l), do: :math.log2(l / @bv_ref)

  # ── Iv (illuminance value) ──────────────────────────────────────

  # Iv(x) = 2^x * C_illum * N_speed → lux
  @iv_ref @c_illum * @n_speed

  @doc "APEX illuminance value to illuminance in cd·sr/m²."
  def iv_forward(x), do: :math.pow(2, x) * @iv_ref
  def iv_inverse(lux), do: :math.log2(lux / @iv_ref)

  # ── Sdeg / Sdin (DIN speed) ─────────────────────────────────────

  # Sdeg(x) = 10^((S-1)/10) → dimensionless
  @doc "DIN speed degrees to linear speed (dimensionless)."
  def sdeg_forward(s), do: :math.pow(10, (s - 1) / 10)
  def sdeg_inverse(r), do: 1 + 10 * :math.log10(r)

  # ── f-number (identity — included for completeness) ─────────────

  @doc "f-number (identity, dimensionless)."
  def fnumber_forward(x), do: x * 1.0
  def fnumber_inverse(x), do: x * 1.0

  # ── Numerical aperture ──────────────────────────────────────────

  # NA(x) = 0.5 / x (dimensionless)
  @doc "Numerical aperture to f-number equivalent (dimensionless)."
  def na_forward(x), do: 0.5 / x
  def na_inverse(r), do: 0.5 / r
end
