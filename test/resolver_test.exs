defmodule Funkspector.ResolverTest do
  use ExUnit.Case

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

  test "returns error for server error status codes" do
    with_mock HTTPoison,
      get: fn _url, _headers, _options -> {:ok, %{status_code: 500, body: "error"}} end do
      {:error, "https://example.com/", _} = resolve("https://example.com/")
    end
  end

  test "returns error for 403 forbidden" do
    with_mock HTTPoison,
      get: fn _url, _headers, _options -> {:ok, %{status_code: 403, body: "forbidden"}} end do
      {:error, "https://example.com/secret", _} = resolve("https://example.com/secret")
    end
  end

  test "decompresses gzip-encoded responses" do
    with_mock HTTPoison, get: fn _url, _headers, _options -> gzip_response() end do
      {:ok, "https://example.com/", response} = resolve("https://example.com/")
      assert response.body == mocked_html()
    end
  end

  test "retries with TLSv1.2 on SSL closed error" do
    call_count = :counters.new(1, [:atomics])

    with_mock HTTPoison,
      get: fn _url, _headers, options ->
        :counters.add(call_count, 1, 1)
        count = :counters.get(call_count, 1)

        if count == 1 do
          # First call fails with SSL error
          ssl_closed_error()
        else
          # Retry with SSL option should include ssl version
          assert Keyword.get(options, :ssl) == [versions: [:"tlsv1.2"]]
          successful_response()
        end
      end do
      {:ok, "https://example.com/", _} = resolve("https://example.com/")
      assert :counters.get(call_count, 1) == 2
    end
  end

  test "returns error on SSL failure when already retried with ssl option" do
    with_mock HTTPoison,
      get: fn _url, _headers, _options ->
        ssl_closed_error()
      end do
      {:error, "https://example.com/", _} =
        resolve("https://example.com/", %{ssl: [versions: [:"tlsv1.2"]]})
    end
  end

  test "retries with TLSv1.2 on SSL handshake failure" do
    call_count = :counters.new(1, [:atomics])

    with_mock HTTPoison,
      get: fn _url, _headers, options ->
        :counters.add(call_count, 1, 1)
        count = :counters.get(call_count, 1)

        if count == 1 do
          ssl_handshake_error()
        else
          assert Keyword.get(options, :ssl) == [versions: [:"tlsv1.2"]]
          successful_response()
        end
      end do
      {:ok, "https://example.com/", _} = resolve("https://example.com/")
      assert :counters.get(call_count, 1) == 2
    end
  end

  test "stops following redirects after 5 hops" do
    with_mock HTTPoison, get: fn url, _headers, _options -> long_redirect_chain(url) end do
      # Starts at /chain/1, follows 5 hops (max_redirects decrements each time),
      # arriving at /chain/6 which returns a 200 response on the 5th redirect hop.
      {:ok, final_url, _} = resolve("http://example.com/chain/1")
      assert final_url == "http://example.com/chain/6"
    end
  end

  test "returns error for 1xx status codes" do
    with_mock HTTPoison,
      get: fn _url, _headers, _options -> {:ok, %{status_code: 100, body: ""}} end do
      {:error, "https://example.com/", _} = resolve("https://example.com/")
    end
  end

  # This fails with hackney greater than 1.21.0
  @tag :integration
  test "https://github.com/edgurgel/httpoison/issues/501 regression test" do
    assert {:ok, "https://www.freedomfromtorture.org/", %HTTPoison.Response{status_code: 200}} =
             resolve("https://www.freedomfromtorture.org/")
  end
end
