defmodule Funkspector.HTTP.Adapters.ReqTest do
  use ExUnit.Case

  import Mock

  alias Funkspector.HTTP.Adapters.Req, as: ReqAdapter

  # Captures the keyword list the adapter passes to `Req.request/1` by mocking
  # the underlying client, so we can assert on the option translation without
  # hitting the network.
  defp captured_req_options(url, opts) do
    test_pid = self()

    with_mock Req,
      request: fn req_opts ->
        send(test_pid, {:req_opts, req_opts})
        {:ok, %Req.Response{status: 200, headers: %{}, body: ""}}
      end do
      ReqAdapter.get(url, opts)

      receive do
        {:req_opts, req_opts} -> req_opts
      after
        0 -> flunk("Req.request/1 was not called")
      end
    end
  end

  defp transport_opts(req_opts) do
    req_opts
    |> Keyword.get(:connect_options, [])
    |> Keyword.get(:transport_opts, [])
  end

  describe "TLS verification" do
    test "verifies certificates by default (no verify_none)" do
      req_opts = captured_req_options("https://example.com", %{})

      refute transport_opts(req_opts)[:verify] == :verify_none
    end

    test "disables certificate verification when insecure: true" do
      req_opts = captured_req_options("https://example.com", %{insecure: true})

      assert transport_opts(req_opts)[:verify] == :verify_none
    end

    test "still honors the legacy hackney: [:insecure] flag" do
      req_opts = captured_req_options("https://example.com", %{hackney: [:insecure]})

      assert transport_opts(req_opts)[:verify] == :verify_none
    end

    test "still honors an explicit ssl: [verify: :verify_none]" do
      req_opts = captured_req_options("https://example.com", %{ssl: [verify: :verify_none]})

      assert transport_opts(req_opts)[:verify] == :verify_none
    end
  end

  describe "response body size" do
    test "rejects a body larger than max_body_size" do
      with_mock Req,
        request: fn _ ->
          {:ok, %Req.Response{status: 200, headers: %{}, body: String.duplicate("a", 1000)}}
        end do
        assert {:error, %Funkspector.Error{reason: :body_too_large}} =
                 ReqAdapter.get("https://example.com", %{max_body_size: 100})
      end
    end

    test "allows a body within max_body_size" do
      with_mock Req,
        request: fn _ -> {:ok, %Req.Response{status: 200, headers: %{}, body: "small"}} end do
        assert {:ok, %Funkspector.Response{status_code: 200}} =
                 ReqAdapter.get("https://example.com", %{max_body_size: 100})
      end
    end
  end

  describe "error mapping" do
    test "passes a transport reason atom through unchanged" do
      with_mock Req, request: fn _ -> {:error, %Req.TransportError{reason: :nxdomain}} end do
        assert {:error, %Funkspector.Error{reason: :nxdomain}} =
                 ReqAdapter.get("https://example.com", %{})
      end
    end

    test "maps a reason-less exception to a stable {:adapter_error, _} value" do
      with_mock Req, request: fn _ -> {:error, %RuntimeError{message: "boom"}} end do
        assert {:error, %Funkspector.Error{reason: {:adapter_error, "boom"}}} =
                 ReqAdapter.get("https://example.com", %{})
      end
    end
  end

  describe "max_body_size with a real server" do
    setup do
      {:ok, bypass: Bypass.open()}
    end

    test "stops reading an endless body at the limit" do
      url = FunkspectorTest.EndlessServer.start()

      task =
        Task.async(fn ->
          ReqAdapter.get(url, %{
            max_body_size: 1_000_000,
            recv_timeout: 2_000
          })
        end)

      assert {:error, %Funkspector.Error{reason: :body_too_large}} = Task.await(task, 5_000)
    end

    test "a body under the limit is returned whole", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/small", fn conn ->
        Plug.Conn.resp(conn, 200, String.duplicate("a", 512_000))
      end)

      assert {:ok, %Funkspector.Response{body: body}} =
               ReqAdapter.get(server_url(bypass, "/small"), %{max_body_size: 1_000_000})

      assert byte_size(body) == 512_000
    end

    test "a gzipped body under the limit still reaches the caller inflated", %{bypass: bypass} do
      Bypass.expect_once(bypass, "GET", "/gzipped", fn conn ->
        conn
        |> Plug.Conn.put_resp_header("content-encoding", "gzip")
        |> Plug.Conn.resp(200, :zlib.gzip("<html>hello</html>"))
      end)

      assert {:ok, _url, %Funkspector.Response{body: "<html>hello</html>"}} =
               Funkspector.Resolver.resolve(server_url(bypass, "/gzipped"), %{
                 max_body_size: 1_000_000
               })
    end
  end

  defp server_url(%Bypass{port: port}, path), do: "http://localhost:#{port}#{path}"
end
