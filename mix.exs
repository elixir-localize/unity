defmodule Units.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :units,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp escript do
    [main_module: Units.CLI]
  end

  defp deps do
    [
      {:localize, path: "../localize"},
      {:nimble_parsec, "~> 1.0"}
    ]
  end
end
