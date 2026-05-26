defmodule Funkspector.Mixfile do
  use Mix.Project

  def project do
    [
      app: :funkspector,
      version: "2.0.0",
      elixir: "~> 1.17",
      description: "Web page inspector for Elixir",
      package: package(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      preferred_cli_env: [
        "test.all": :test,
        "test.httpoison": :test,
        "test.adapters": :test
      ]
    ]
  end

  # Custom mix aliases.
  #
  # * `mix test.all` — run the full suite, including integration tests that
  #   hit live URLs (httpbin.org, badssl.com, github.com, hex.pm, etc.).
  # * `mix test.httpoison` — run the full suite under the opt-in HTTPoison
  #   adapter by setting `FUNKSPECTOR_ADAPTER=httpoison`. The default
  #   adapter (Req) is used otherwise.
  # * `mix test.adapters` — run the suite under both adapters back to back,
  #   the matrix exercised by CI.
  defp aliases do
    [
      "test.all": [
        "test --include integration",
        "cmd FUNKSPECTOR_ADAPTER=httpoison mix test --include integration"
      ],
      "test.httpoison": ["cmd FUNKSPECTOR_ADAPTER=httpoison mix test"],
      "test.adapters": ["test", "test.httpoison"]
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
      # Default HTTP adapter (Finch/Mint, no hackney).
      {:req, "~> 0.5"},
      # Opt-in HTTP adapter. Hackney is pinned to 1.21 until
      # https://github.com/edgurgel/httpoison/issues/501 is fixed.
      # Both are marked `optional: true` so downstream consumers that
      # stick with the default Req adapter do not need to pull in hackney.
      {:hackney, "~> 1.21.0", optional: true},
      {:httpoison, "~> 2.3.0", optional: true},
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
