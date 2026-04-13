defmodule Units.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/elixir-localize/units"

  def project do
    [
      app: :eunits,
      version: @version,
      elixir: "~> 1.17",
      name: "Elixir Units",
      source_url: @source_url,
      docs: docs(),
      description: description(),
      package: package(),
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

  defp description do
    """
    An Elixir unit conversion calculator inspired by the Unix `units` utility.
    Parses and evaluates unit expressions with locale-aware output powered by Localize.
    """
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib priv .formatter.exs mix.exs README.md CHANGELOG.md LICENSE.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      formatters: ["html", "markdown"],
      extras: [
        "README.md",
        "CHANGELOG.md",
        "guides/conformance.md",
        "guides/importing_gnu_units_definitions.md"
      ],
      groups_for_extras: [Guides: ~r/guides\/.*/],
      source_ref: "v#{@version}"
    ]
  end

  defp deps do
    [
      {:localize, "~> 0.1"},
      {:nimble_parsec, "~> 1.0"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :release, runtime: false}
    ] ++ maybe_json_polyfill()
  end

  defp maybe_json_polyfill do
    if Code.ensure_loaded?(:json) do
      []
    else
      [{:json_polyfill, "~> 0.2 or ~> 1.0"}]
    end
  end
end
