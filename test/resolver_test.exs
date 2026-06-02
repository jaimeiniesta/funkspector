defmodule Funkspector.ResolverTest do
  use ExUnit.Case

  import Mock
  import FunkspectorTest.MockedConnections
  import Funkspector.Resolver

  alias Funkspector.{Response, Error}

  @adapter current_adapter()

  @invalid_urls [
    "Warning: Element name h2<audio< cannot be represented as XML 1.0.",
    nil,
    "   ",
    25
  ]

  test "resolves URLs" do
    with_mock @adapter, get: fn url, _opts -> redirect_from(url) end do
      {:ok, "http://example.com/redirect/3", _} = resolve("http://example.com/redirect/1")
    end
  end

  test "follows relative redirections" do
    with_mock @adapter, get: fn url, _opts -> redirect_from(url) end do
      {:ok, "http://example.com/redirect/3", _} = resolve("http://example.com/redirect/relative")
    end
  end

  test "keeps URLs that dont redirect" do
    with_mock @adapter, get: fn _url, _opts -> successful_response() end do
      {:ok, "http://example.com/", _} = resolve("http://example.com/")
    end
  end

  test "follows lowercase location key" do
    with_mock @adapter, get: fn url, _opts -> redirect_from(url) end do
      {:ok, "http://example.com/redirect/3", _} =
        resolve("http://example.com/redirect/lowercase-location")
    end
  end

  test "returns error if host does not exist" do
    with_mock @adapter, get: fn _url, _opts -> http_error_response() end do
      {:error, "http://this_does_not_exist.com", %Error{reason: :nxdomain}} =
        resolve("http://this_does_not_exist.com")
    end
  end

  test "returns error if host exists but page cant be found" do
    with_mock @adapter, get: fn _url, _opts -> unsuccessful_response(404) end do
      {:error, "https://example.com/not_existent", _} =
        resolve("https://example.com/not_existent")
    end
  end

  test "returns error for HTTP Status 300 multiple choices" do
    with_mock @adapter, get: fn _url, _opts -> multiple_choices_response() end do
      {:error, "https://example.com/multiple_choices",
       %Response{
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
    with_mock @adapter,
      get: fn _url, opts ->
        assert opts[:basic_auth] == {"user", "pass"}
        successful_response()
      end do
      {:ok, "http://example.com/", _} =
        resolve("http://example.com/", %{basic_auth: {"user", "pass"}})
    end
  end

  test "includes custom user agent when user_agent option is provided" do
    with_mock @adapter,
      get: fn _url, opts ->
        assert opts[:user_agent] == "Custom Bot 1.0"
        successful_response()
      end do
      {:ok, "http://example.com/", _} =
        resolve("http://example.com/", %{user_agent: "Custom Bot 1.0"})
    end
  end

  test "includes user agent and basic auth when both are provided" do
    with_mock @adapter,
      get: fn _url, opts ->
        assert opts[:user_agent] == "Custom Bot 1.0"
        assert opts[:basic_auth] == {"user", "pass"}
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
    with_mock @adapter,
      get: fn _url, _opts -> {:ok, %Response{status_code: 500, headers: [], body: "error"}} end do
      {:error, "https://example.com/", _} = resolve("https://example.com/")
    end
  end

  test "returns error for 403 forbidden" do
    with_mock @adapter,
      get: fn _url, _opts ->
        {:ok, %Response{status_code: 403, headers: [], body: "forbidden"}}
      end do
      {:error, "https://example.com/secret", _} = resolve("https://example.com/secret")
    end
  end

  test "decompresses gzip-encoded responses" do
    with_mock @adapter, get: fn _url, _opts -> gzip_response() end do
      {:ok, "https://example.com/", response} = resolve("https://example.com/")
      assert response.body == mocked_html()
    end
  end

  test "aborts gzip decompression that would exceed max_body_size" do
    with_mock @adapter, get: fn _url, _opts -> gzip_response() end do
      assert {:error, "https://example.com/", %Error{reason: :body_too_large}} =
               resolve("https://example.com/", %{max_body_size: 10})
    end
  end

  test "retries with TLSv1.2 on SSL closed error" do
    call_count = :counters.new(1, [:atomics])

    with_mock @adapter,
      get: fn _url, opts ->
        :counters.add(call_count, 1, 1)
        count = :counters.get(call_count, 1)

        if count == 1 do
          # First call fails with SSL error
          ssl_closed_error()
        else
          # Retry with SSL option should include ssl version
          assert opts[:ssl] == [versions: [:"tlsv1.2"]]
          successful_response()
        end
      end do
      {:ok, "https://example.com/", _} = resolve("https://example.com/")
      assert :counters.get(call_count, 1) == 2
    end
  end

  test "returns error on SSL failure when already retried with ssl option" do
    with_mock @adapter,
      get: fn _url, _opts ->
        ssl_closed_error()
      end do
      {:error, "https://example.com/", _} =
        resolve("https://example.com/", %{ssl: [versions: [:"tlsv1.2"]]})
    end
  end

  test "retries with TLSv1.2 on SSL handshake failure" do
    call_count = :counters.new(1, [:atomics])

    with_mock @adapter,
      get: fn _url, opts ->
        :counters.add(call_count, 1, 1)
        count = :counters.get(call_count, 1)

        if count == 1 do
          ssl_handshake_error()
        else
          assert opts[:ssl] == [versions: [:"tlsv1.2"]]
          successful_response()
        end
      end do
      {:ok, "https://example.com/", _} = resolve("https://example.com/")
      assert :counters.get(call_count, 1) == 2
    end
  end

  test "stops following redirects after 5 hops" do
    with_mock @adapter, get: fn url, _opts -> long_redirect_chain(url) end do
      # Starts at /chain/1, follows 5 hops (max_redirects decrements each time),
      # arriving at /chain/6 which returns a 200 response on the 5th redirect hop.
      {:ok, final_url, _} = resolve("http://example.com/chain/1")
      assert final_url == "http://example.com/chain/6"
    end
  end

  test "returns error for 1xx status codes" do
    with_mock @adapter,
      get: fn _url, _opts -> {:ok, %Response{status_code: 100, headers: [], body: ""}} end do
      {:error, "https://example.com/", _} = resolve("https://example.com/")
    end
  end

  test "returns an error tuple for a 3xx response without a Location header" do
    with_mock @adapter,
      get: fn _url, _opts ->
        {:ok, %Response{status_code: 301, headers: [{"Content-Type", "text/html"}], body: ""}}
      end do
      assert {:error, "http://example.com/", %Response{status_code: 301}} =
               resolve("http://example.com/")
    end
  end

  test "returns an error tuple for a 304 with no Location instead of crashing" do
    with_mock @adapter,
      get: fn _url, _opts -> {:ok, %Response{status_code: 304, headers: [], body: ""}} end do
      assert {:error, "http://example.com/", %Response{status_code: 304}} =
               resolve("http://example.com/")
    end
  end

  test "follows redirects whose Location header uses non-standard casing" do
    with_mock @adapter,
      get: fn url, _opts ->
        case url do
          "http://example.com/1" ->
            redirection_response("LOCATION", "http://example.com/2")

          "http://example.com/2" ->
            successful_response()
        end
      end do
      {:ok, "http://example.com/2", _} = resolve("http://example.com/1")
    end
  end

  test "returns a too_many_redirects error on an endless redirect chain" do
    with_mock @adapter, get: fn url, _opts -> redirection_response("Location", url <> "x") end do
      assert {:error, _url, :too_many_redirects} = resolve("http://example.com/")
    end
  end

  test "fetches the final resource at the redirect limit" do
    with_mock @adapter, get: fn url, _opts -> long_redirect_chain(url) end do
      assert {:ok, "http://example.com/chain/6", %Response{status_code: 200}} =
               resolve("http://example.com/chain/1")
    end
  end

  test "strips basic_auth when a redirect crosses origin" do
    test_pid = self()

    with_mock @adapter,
      get: fn url, opts ->
        send(test_pid, {:got, url, opts[:basic_auth]})

        case url do
          "http://a.example.com/" -> redirection_response("Location", "http://b.example.com/")
          "http://b.example.com/" -> successful_response()
        end
      end do
      {:ok, "http://b.example.com/", _} =
        resolve("http://a.example.com/", %{basic_auth: {"user", "pass"}})

      assert_received {:got, "http://a.example.com/", {"user", "pass"}}
      assert_received {:got, "http://b.example.com/", nil}
    end
  end

  test "keeps basic_auth across a same-origin redirect" do
    test_pid = self()

    with_mock @adapter,
      get: fn url, opts ->
        send(test_pid, {:got, url, opts[:basic_auth]})

        case url do
          "http://example.com/1" -> redirection_response("Location", "http://example.com/2")
          "http://example.com/2" -> successful_response()
        end
      end do
      {:ok, "http://example.com/2", _} =
        resolve("http://example.com/1", %{basic_auth: {"user", "pass"}})

      assert_received {:got, "http://example.com/1", {"user", "pass"}}
      assert_received {:got, "http://example.com/2", {"user", "pass"}}
    end
  end

  test "retries with TLSv1.2 on a realistic Mint handshake_failure alert" do
    call_count = :counters.new(1, [:atomics])

    with_mock @adapter,
      get: fn _url, opts ->
        :counters.add(call_count, 1, 1)

        if :counters.get(call_count, 1) == 1 do
          {:error,
           %Error{
             reason:
               {:tls_alert,
                {:handshake_failure,
                 ~c"TLS client: In state wait_sh received SERVER ALERT: Fatal - Handshake Failure"}},
             adapter: @adapter
           }}
        else
          assert opts[:ssl] == [versions: [:"tlsv1.2"]]
          successful_response()
        end
      end do
      {:ok, "https://example.com/", _} = resolve("https://example.com/")
      assert :counters.get(call_count, 1) == 2
    end
  end

  test "does not retry on a certificate-validation TLS alert" do
    call_count = :counters.new(1, [:atomics])

    with_mock @adapter,
      get: fn _url, _opts ->
        :counters.add(call_count, 1, 1)

        {:error,
         %Error{reason: {:tls_alert, {:bad_certificate, ~c"bad cert"}}, adapter: @adapter}}
      end do
      assert {:error, "https://example.com/", %Error{reason: {:tls_alert, {:bad_certificate, _}}}} =
               resolve("https://example.com/")

      assert :counters.get(call_count, 1) == 1
    end
  end

  # This fails with hackney greater than 1.21.0
  @tag :integration
  test "https://github.com/edgurgel/httpoison/issues/501 regression test" do
    assert {:ok, "https://www.freedomfromtorture.org/", %Response{status_code: 200}} =
             resolve("https://www.freedomfromtorture.org/")
  end
end
