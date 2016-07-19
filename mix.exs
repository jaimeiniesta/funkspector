defmodule Funkspector.Mixfile do
  use Mix.Project

  def project do
    [app: :funkspector,
     version: "0.1.0",
     elixir: "~> 1.3",
     description: "Web page inspector for Elixir",
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :httpoison]]
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
      { :httpoison, "~> 0.9" },
      { :floki,     "~> 0.9" },
      { :quinn,     "~> 0.0.4" },
      { :mock,      "~> 0.1", only: :test},
      { :ex_doc,    ">= 0.0.0", only: :dev }
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
