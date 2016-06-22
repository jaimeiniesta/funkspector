# Funkspector

Web page inspector for Elixir.

[![Deps Status](https://beta.hexfaktor.org/badge/all/github/jaimeiniesta/funkspector.svg)](https://beta.hexfaktor.org/github/jaimeiniesta/funkspector)

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add funkspector to your list of dependencies in `mix.exs`:

        def deps do
          [{:funkspector, "~> 0.0.1"}]
        end

  2. Ensure funkspector is started before your application:

        def application do
          [applications: [:funkspector]]
        end
