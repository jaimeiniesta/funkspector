defmodule Funkspector.Mixfile do
  use Mix.Project

  def project do
    [
      app: :funkspector,
      version: "1.4.0",
      elixir: "~> 1.17",
      description: "Web page inspector for Elixir",
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:hackney, "~> 1.25.0"},
      {:httpoison, "~> 2.2.1"},
      {:floki, "~> 0.37.0"},
      {:sweet_xml, "~> 0.7.5"},
      {:mock, "~> 0.3.9", only: :test},
      {:ex_doc, ">= 0.36.0", only: :dev, runtime: false},
      {:credo, "~> 1.7.10", only: [:dev, :test], runtime: false}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Jaime Iniesta"],
      links: %{"GitHub" => "https://github.com/jaimeiniesta/funkspector"}
    ]
  end
end
