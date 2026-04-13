defmodule Unity.Conversion.Density do
  @moduledoc """
  Nonlinear conversions for density scales: Baumé, Twaddell,
  Quevenne, API degree, and pH.

  Forward functions convert from the scale reading to the base SI unit.
  Inverse functions convert from the base SI unit back to the scale reading.

  """

  # ── Baumé hydrometer ────────────────────────────────────────────

  # baume(d) = (145 / (145 + -d)) g/cm³ → kg/m³
  # For liquids heavier than water (the common convention).
  @baumeconst 145.0
  @g_per_cm3_to_kg_per_m3 1000.0

  @doc "Baumé degrees to kg/m³."
  def baume_forward(d) do
    @baumeconst / (@baumeconst + -d) * @g_per_cm3_to_kg_per_m3
  end

  @doc "kg/m³ to Baumé degrees."
  def baume_inverse(rho) do
    g_cm3 = rho / @g_per_cm3_to_kg_per_m3
    @baumeconst - @baumeconst / g_cm3
  end

  # ── Twaddell hydrometer ─────────────────────────────────────────

  # twaddell(x) = (1 + 0.005x) g/cm³ → kg/m³
  @doc "Twaddell degrees to kg/m³."
  def twaddell_forward(x), do: (1 + 0.005 * x) * @g_per_cm3_to_kg_per_m3

  @doc "kg/m³ to Twaddell degrees."
  def twaddell_inverse(rho), do: 200 * (rho / @g_per_cm3_to_kg_per_m3 - 1)

  # ── Quevenne lactometer ─────────────────────────────────────────

  # quevenne(x) = (1 + 0.001x) g/cm³ → kg/m³
  @doc "Quevenne degrees to kg/m³."
  def quevenne_forward(x), do: (1 + 0.001 * x) * @g_per_cm3_to_kg_per_m3

  @doc "kg/m³ to Quevenne degrees."
  def quevenne_inverse(rho), do: 1000 * (rho / @g_per_cm3_to_kg_per_m3 - 1)

  # ── API degree (petroleum) ──────────────────────────────────────

  # apidegree(x) = 141.5 / (x + 131.5) g/cm³ → kg/m³
  @doc "API degrees to kg/m³."
  def apidegree_forward(x), do: 141.5 / (x + 131.5) * @g_per_cm3_to_kg_per_m3

  @doc "kg/m³ to API degrees."
  def apidegree_inverse(rho) do
    g_cm3 = rho / @g_per_cm3_to_kg_per_m3
    141.5 / g_cm3 - 131.5
  end

  # ── pH (acidity) ────────────────────────────────────────────────

  # pH(x) = 10^(-x) mol/liter → mol/m³ (1 mol/L = 1000 mol/m³)
  @mol_per_liter_to_mol_per_m3 1000.0

  @doc "pH to mol/m³ (hydrogen ion concentration)."
  def ph_forward(x), do: :math.pow(10, -x) * @mol_per_liter_to_mol_per_m3

  @doc "mol/m³ to pH."
  def ph_inverse(conc), do: -:math.log10(conc / @mol_per_liter_to_mol_per_m3)
end
