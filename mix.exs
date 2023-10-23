defmodule Funkspector.Mixfile do
  use Mix.Project

  def project do
    [
      app: :funkspector,
      version: "1.0.0",
      elixir: "~> 1.14",
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
    [applications: [:logger, :httpoison, :floki, :sweet_xml]]
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
      {:hackney, "~> 1.20.1"},
      {:httpoison, "~> 2.1.0"},
      {:floki, "~> 0.35.1"},
      {:sweet_xml, "~> 0.7.4"},
      {:mock, "~> 0.3.8", only: :test},
      {:ex_doc, ">= 0.30.9", only: :dev},
      {:credo, "~> 1.7.1", only: :dev}
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
