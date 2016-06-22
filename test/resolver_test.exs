defmodule Funkspector.ResolverTest do
  use ExUnit.Case
  doctest Funkspector.Resolver

  import Mock
  import Rocket.MockedConnections
  import Funkspector.Resolver

  test "resolves URLs" do
    with_mock HTTPoison, [get: fn(url) -> redirect_from(url) end] do
      {:ok, "http://example.com/redirect/3", _} = resolve("http://example.com/redirect/1")
    end
  end

  test "keeps URLs that dont redirect" do
    with_mock HTTPoison, [get: fn(_url) -> successful_response end] do
      {:ok, "http://example.com/", _} = resolve("http://example.com/")
    end
  end

  test "respects max_redirects" do
    with_mock HTTPoison, [get: fn(url) -> redirect_from(url) end] do
      {:ok, "http://example.com/redirect/2", _} = resolve("http://example.com/redirect/1", 1)
    end

    with_mock HTTPoison, [get: fn(url) -> redirect_from(url) end] do
      {:ok, "http://example.com/redirect/1", _} = resolve("http://example.com/redirect/1", 0)
    end
  end

  test "returns :error if host does not exist" do
    with_mock HTTPoison, [get: fn(url) -> http_error_response(url) end] do
      {:error, "http://this_does_not_exist.com", %HTTPoison.Error{id: nil, reason: :nxdomain}} = resolve("http://this_does_not_exist.com")
    end
  end

  test "returns :error if host exists but page cant be found" do
    with_mock HTTPoison, [get: fn(_url) -> unsuccessful_response(404) end] do
      {:error, "https:/example.com/not_existent", _} = resolve("https:/example.com/not_existent")
    end
  end
end
