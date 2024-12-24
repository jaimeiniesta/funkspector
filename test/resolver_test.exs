defmodule Funkspector.ResolverTest do
  use ExUnit.Case
  doctest Funkspector.Resolver

  import Mock
  import FunkspectorTest.MockedConnections
  import Funkspector.Resolver

  @invalid_urls [
    "Warning: Element name h2<audio< cannot be represented as XML 1.0.",
    nil,
    "   ",
    25
  ]

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

  test "returns error if host does not exist" do
    with_mock HTTPoison, get: fn _url, _headers, _options -> http_error_response() end do
      {:error, "http://this_does_not_exist.com", %HTTPoison.Error{id: nil, reason: :nxdomain}} =
        resolve("http://this_does_not_exist.com")
    end
  end

  test "returns error if host exists but page cant be found" do
    with_mock HTTPoison, get: fn _url, _headers, _options -> unsuccessful_response(404) end do
      {:error, "https://example.com/not_existent", _} =
        resolve("https://example.com/not_existent")
    end
  end

  test "returns error for HTTP Status 300 multiple choices" do
    with_mock HTTPoison, get: fn _url, _headers, _options -> multiple_choices_response() end do
      {:error, "https://example.com/multiple_choices",
       %{
         headers: [{"Content-length", "0"}, {"Content-length", "0"}],
         status_code: 300
       }} = resolve("https://example.com/multiple_choices")
    end
  end

  test "returns error if URL is invalid" do
    for url <- @invalid_urls do
      assert resolve(url) == {:error, url, :invalid_url}
    end
  end

  test "includes basic auth header when basic_auth option is provided" do
    with_mock HTTPoison,
      get: fn _url, headers, _options ->
        assert {"Authorization", "Basic dXNlcjpwYXNz"} in headers
        successful_response()
      end do
      {:ok, "http://example.com/", _} =
        resolve("http://example.com/", %{basic_auth: {"user", "pass"}})
    end
  end

  test "includes custom user agent when user_agent option is provided" do
    with_mock HTTPoison,
      get: fn _url, headers, _options ->
        assert {"User-Agent", "Custom Bot 1.0"} in headers
        successful_response()
      end do
      {:ok, "http://example.com/", _} =
        resolve("http://example.com/", %{user_agent: "Custom Bot 1.0"})
    end
  end

  test "includes user agent and basic auth when both are provided" do
    with_mock HTTPoison,
      get: fn _url, headers, _options ->
        assert {"User-Agent", "Custom Bot 1.0"} in headers
        assert {"Authorization", "Basic dXNlcjpwYXNz"} in headers
        successful_response()
      end do
      {:ok, "http://example.com/", _} =
        resolve("http://example.com/", %{
          user_agent: "Custom Bot 1.0",
          basic_auth: {"user", "pass"}
        })
    end
  end
end
