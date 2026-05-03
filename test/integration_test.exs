defmodule Funkspector.IntegrationTest do
  @moduledoc """
  Integration tests that hit live URLs.

  Excluded by default. Run with:

      mix test --include integration
  """

  use ExUnit.Case

  @moduletag :integration

  doctest Funkspector
  doctest Funkspector.Resolver
end
