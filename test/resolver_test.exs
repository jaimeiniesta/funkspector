defmodule Funkspector.ResolverTest do
  use ExUnit.Case
  doctest Funkspector.Resolver

  import Mock
  import Rocket.MockedConnections
  import Funkspector.Resolver

  test "resolves URLs" do
    with_mock HTTPoison, get: fn url, _headers, _options -> redirect_from(url) end do
      {:ok, "http://example.com/redirect/3", _} = resolve("http://example.com/redirect/1")
    end
  end

  test "follows relative redirections" do
    with_mock HTTPoison, get: fn url, _headers, _options -> redirect_from(url) end do
      {:ok, "http://example.com/redirect/3", _} = resolve("http://example.com/redirect/relative")
    end
  end

  test "keeps URLs that dont redirect" do
    with_mock HTTPoison, get: fn _url, _headers, _options -> successful_response() end do
      {:ok, "http://example.com/", _} = resolve("http://example.com/")
    end
  end

  test "follows lowercase location key" do
    with_mock HTTPoison, get: fn url, _headers, _options -> redirect_from(url) end do
      {:ok, "http://example.com/redirect/3", _} =
        resolve("http://example.com/redirect/lowercase-location")
    end
  end

  test "returns :error if host does not exist" do
    with_mock HTTPoison, get: fn url, _headers, _options -> http_error_response(url) end do
      {:error, "http://this_does_not_exist.com", %HTTPoison.Error{id: nil, reason: :nxdomain}} =
        resolve("http://this_does_not_exist.com")
    end
  end

  test "returns :error if host exists but page cant be found" do
    with_mock HTTPoison, get: fn _url, _headers, _options -> unsuccessful_response(404) end do
      {:error, "https:/example.com/not_existent", _} = resolve("https:/example.com/not_existent")
    end
  end
end
