defmodule Unity.Conversion.Temperature do
  @moduledoc """
  Nonlinear forward/inverse conversions for GNU Units temperature
  scales (`tempC`, `tempF`, `tempreaumur`).

  Each function pair converts between a temperature scale reading
  and kelvin. The forward function takes a scale value and returns
  kelvin; the inverse takes kelvin and returns the scale value.

  These are registered as `:special` custom units so that both
  `tempC(100)` (function call) and `100 tempc to kelvin` (unit
  conversion) work through the same mechanism.

  """

  @stdtemp 273.15

  @doc "Celsius to kelvin."
  @spec celsius_forward(number()) :: float()
  def celsius_forward(x), do: x + @stdtemp

  @doc "Kelvin to Celsius."
  @spec celsius_inverse(number()) :: float()
  def celsius_inverse(k), do: k - @stdtemp

  @doc "Fahrenheit to kelvin."
  @spec fahrenheit_forward(number()) :: float()
  def fahrenheit_forward(x), do: (x - 32) * 5 / 9 + @stdtemp

  @doc "Kelvin to Fahrenheit."
  @spec fahrenheit_inverse(number()) :: float()
  def fahrenheit_inverse(k), do: (k - @stdtemp) * 9 / 5 + 32

  @doc "Réaumur to kelvin."
  @spec reaumur_forward(number()) :: float()
  def reaumur_forward(x), do: x * 5 / 4 + @stdtemp

  @doc "Kelvin to Réaumur."
  @spec reaumur_inverse(number()) :: float()
  def reaumur_inverse(k), do: (k - @stdtemp) * 4 / 5
end
