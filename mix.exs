defmodule Funkspector.Mixfile do
  use Mix.Project

  def project do
    [
      app: :funkspector,
      version: "0.8.0",
      elixir: "~> 1.8.1",
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
    [applications: [:logger, :httpoison, :floki, :friendly]]
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
      {:hackney, "~> 1.15.2"},
      {:httpoison, "~> 1.6.2"},
      {:floki, "~> 0.20.0"},
      {:friendly, "~> 1.1.0"},
      {:mock, "~> 0.3.4", only: :test},
      {:ex_doc, ">= 0.19.0", only: :dev}
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
