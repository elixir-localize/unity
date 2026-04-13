defmodule Unity.Conversion.Decibel do
  @moduledoc """
  Nonlinear conversions for decibel, neper, bel, and related
  logarithmic scales.

  Each variant is parameterised by a reference level and whether the
  quantity is power-like (direct dB) or amplitude-like (half-dB, since
  power = amplitude²).

  """

  # ── Core logarithmic scales ──────────────────────────────────────

  @doc "Decibel: 10^(x/10) (dimensionless power ratio)."
  def decibel_forward(x), do: :math.pow(10, x / 10)
  def decibel_inverse(r), do: 10 * :math.log10(r)

  @doc "Bel: 10^x (dimensionless power ratio)."
  def bel_forward(x), do: :math.pow(10, x)
  def bel_inverse(r), do: :math.log10(r)

  @doc "Neper: e^x (dimensionless amplitude ratio)."
  def neper_forward(x), do: :math.exp(x)
  def neper_inverse(r), do: :math.log(r)

  @doc "Centineper: e^(x/100)."
  def centineper_forward(x), do: :math.exp(x / 100)
  def centineper_inverse(r), do: 100 * :math.log(r)

  @doc "Neper (power): Np(2x), i.e. e^(2x) for power quantities."
  def neper_power_forward(x), do: :math.exp(2 * x)
  def neper_power_inverse(r), do: :math.log(r) / 2

  @doc "Decibel amplitude: 10^(x/20) (amplitude ratio)."
  def db_amplitude_forward(x), do: :math.pow(10, x / 20)
  def db_amplitude_inverse(r), do: 20 * :math.log10(r)

  # ── Power-referenced dB (forward = 10^(x/10) * reference) ───────

  # dBW: reference = 1 W
  @watt 1.0
  def dbw_forward(x), do: :math.pow(10, x / 10) * @watt
  def dbw_inverse(w), do: 10 * :math.log10(w / @watt)

  # dBm / dBmW: reference = 1 mW
  @milliwatt 1.0e-3
  def dbm_forward(x), do: :math.pow(10, x / 10) * @milliwatt
  def dbm_inverse(w), do: 10 * :math.log10(w / @milliwatt)

  # dBk: reference = 1 kW
  @kilowatt 1.0e3
  def dbk_forward(x), do: :math.pow(10, x / 10) * @kilowatt
  def dbk_inverse(w), do: 10 * :math.log10(w / @kilowatt)

  # dBf: reference = 1 fW
  @femtowatt 1.0e-15
  def dbf_forward(x), do: :math.pow(10, x / 10) * @femtowatt
  def dbf_inverse(w), do: 10 * :math.log10(w / @femtowatt)

  # dBJ: reference = 1 J (energy, same SI base as W·s but registered as power)
  @joule 1.0
  def dbj_forward(x), do: :math.pow(10, x / 10) * @joule
  def dbj_inverse(j), do: 10 * :math.log10(j / @joule)

  # dBSWL: reference = 1e-12 W (sound power level)
  @swl_ref 1.0e-12
  def dbswl_forward(x), do: :math.pow(10, x / 10) * @swl_ref
  def dbswl_inverse(w), do: 10 * :math.log10(w / @swl_ref)

  # dBSIL: reference = 1e-12 W/m² (sound intensity level)
  @sil_ref 1.0e-12
  def dbsil_forward(x), do: :math.pow(10, x / 10) * @sil_ref
  def dbsil_inverse(i), do: 10 * :math.log10(i / @sil_ref)

  # ── Amplitude-referenced dB (forward = 10^(x/20) * reference) ───

  # dBV: reference = 1 V
  @volt 1.0
  def dbv_forward(x), do: :math.pow(10, x / 20) * @volt
  def dbv_inverse(v), do: 20 * :math.log10(v / @volt)

  # dBmV: reference = 1 mV
  @millivolt 1.0e-3
  def dbmv_forward(x), do: :math.pow(10, x / 20) * @millivolt
  def dbmv_inverse(v), do: 20 * :math.log10(v / @millivolt)

  # dBuV / dBμV: reference = 1 µV
  @microvolt 1.0e-6
  def dbuv_forward(x), do: :math.pow(10, x / 20) * @microvolt
  def dbuv_inverse(v), do: 20 * :math.log10(v / @microvolt)

  # dBu: reference = sqrt(1 mW × 600 Ω) ≈ 0.7746 V
  @dbu_ref :math.sqrt(1.0e-3 * 600)
  def dbu_forward(x), do: :math.pow(10, x / 20) * @dbu_ref
  def dbu_inverse(v), do: 20 * :math.log10(v / @dbu_ref)

  # dBA: reference = 1 A
  @ampere 1.0
  def dba_forward(x), do: :math.pow(10, x / 20) * @ampere
  def dba_inverse(a), do: 20 * :math.log10(a / @ampere)

  # dBmA: reference = 1 mA
  @milliampere 1.0e-3
  def dbma_forward(x), do: :math.pow(10, x / 20) * @milliampere
  def dbma_inverse(a), do: 20 * :math.log10(a / @milliampere)

  # dBuA / dBμA: reference = 1 µA
  @microampere 1.0e-6
  def dbua_forward(x), do: :math.pow(10, x / 20) * @microampere
  def dbua_inverse(a), do: 20 * :math.log10(a / @microampere)

  # dBSPL: reference = 20 µPa (sound pressure level)
  @spl_ref 20.0e-6
  def dbspl_forward(x), do: :math.pow(10, x / 20) * @spl_ref
  def dbspl_inverse(pa), do: 20 * :math.log10(pa / @spl_ref)

  # ── Musical cent ─────────────────────────────────────────────────

  # musicalcent: semitone^(x/100), where semitone = 2^(1/12)
  @semitone :math.pow(2, 1 / 12)
  @log_semitone :math.log10(@semitone)
  def musicalcent_forward(x), do: :math.pow(@semitone, x / 100)
  def musicalcent_inverse(r), do: 100 * :math.log10(r) / @log_semitone

  # ── Bril (brightness) ───────────────────────────────────────────

  # bril: 2^(x - 100) lamberts (unit of luminance)
  # lambert = 1/π cd/cm² ≈ 3183.1 cd/m²
  @lambert 3183.098861837907
  def bril_forward(x), do: :math.pow(2, x - 100) * @lambert
  def bril_inverse(l), do: :math.log2(l / @lambert) + 100
end
