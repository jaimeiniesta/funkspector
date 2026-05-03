defmodule Funkspector.DocsTest do
  @moduledoc """
  Runs doctests from modules whose `@doc` examples use live URLs.

  The `@doc` blocks in `Funkspector` and `Funkspector.Resolver` contain
  examples that hit real URLs (e.g. `http://github.com`), so they require
  network access. This module runs those doctests behind the `:integration`
  tag so they are excluded from the default `mix test` run.

  This lets us keep realistic examples in the module documentation without
  breaking offline or CI test runs.

  Excluded by default. Run with:

      mix test --include integration
  """

  use ExUnit.Case

  @moduletag :integration

  doctest Funkspector
  doctest Funkspector.Resolver
end
