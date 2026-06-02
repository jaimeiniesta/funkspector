defmodule Funkspector.HTTP.Adapters.HTTPoisonTest do
  use ExUnit.Case

  import Mock

  alias Funkspector.HTTP.Adapters.HTTPoison, as: HTTPoisonAdapter

  # Captures the request options the adapter passes to `HTTPoison.get/3` by
  # mocking the underlying client, so we can assert on the option translation
  # without hitting the network.
  defp captured_request_options(url, opts) do
    test_pid = self()

    with_mock HTTPoison,
      get: fn _url, _headers, request_options ->
        send(test_pid, {:httpoison_options, request_options})
        {:ok, %HTTPoison.Response{status_code: 200, headers: [], body: ""}}
      end do
      HTTPoisonAdapter.get(url, opts)

      receive do
        {:httpoison_options, request_options} -> request_options
      after
        0 -> flunk("HTTPoison.get/3 was not called")
      end
    end
  end

  describe "TLS verification" do
    test "does not disable verification by default" do
      request_options = captured_request_options("https://example.com", %{})

      refute :insecure in Keyword.get(request_options, :hackney, [])
    end

    test "disables verification via hackney: [:insecure] when insecure: true" do
      request_options = captured_request_options("https://example.com", %{insecure: true})

      assert :insecure in Keyword.get(request_options, :hackney, [])
    end

    test "merges insecure: true into existing hackney options" do
      request_options =
        captured_request_options("https://example.com", %{
          insecure: true,
          hackney: [pool: :default]
        })

      hackney = Keyword.get(request_options, :hackney, [])
      assert :insecure in hackney
      assert hackney[:pool] == :default
    end

    test "never forwards the raw :insecure key to HTTPoison" do
      request_options = captured_request_options("https://example.com", %{insecure: true})

      refute Keyword.has_key?(request_options, :insecure)
    end
  end

  describe "response body size" do
    test "rejects a body larger than max_body_size" do
      with_mock HTTPoison,
        get: fn _url, _headers, _opts ->
          {:ok,
           %HTTPoison.Response{status_code: 200, headers: [], body: String.duplicate("a", 1000)}}
        end do
        assert {:error, %Funkspector.Error{reason: :body_too_large}} =
                 HTTPoisonAdapter.get("https://example.com", %{max_body_size: 100})
      end
    end

    test "allows a body within max_body_size" do
      with_mock HTTPoison,
        get: fn _url, _headers, _opts ->
          {:ok, %HTTPoison.Response{status_code: 200, headers: [], body: "small"}}
        end do
        assert {:ok, %Funkspector.Response{status_code: 200}} =
                 HTTPoisonAdapter.get("https://example.com", %{max_body_size: 100})
      end
    end

    test "does not forward the funkspector-level :max_body_size option to HTTPoison" do
      request_options = captured_request_options("https://example.com", %{max_body_size: 100})

      refute Keyword.has_key?(request_options, :max_body_size)
    end
  end
end
