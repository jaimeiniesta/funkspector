defmodule FunkspectorTest.EndlessServer do
  @moduledoc false
  # A bare HTTP server that answers every request with the given headers and
  # then sends 64 KB chunks until the client hangs up. Bypass can't do this: its
  # instance crashes when a client closes a connection in the middle of a body.

  @chunk String.duplicate("a", 65_536)

  @doc "Starts the server and returns its URL."
  def start(content_type \\ "application/octet-stream") do
    {:ok, listen} = :gen_tcp.listen(0, [:binary, active: false, reuseaddr: true])
    {:ok, port} = :inet.port(listen)
    spawn_link(fn -> accept(listen, content_type) end)
    "http://localhost:#{port}/"
  end

  defp accept(listen, content_type) do
    case :gen_tcp.accept(listen) do
      {:ok, socket} ->
        spawn(fn -> serve(socket, content_type) end)
        accept(listen, content_type)

      {:error, _} ->
        :ok
    end
  end

  defp serve(socket, content_type) do
    {:ok, _request} = :gen_tcp.recv(socket, 0, 5_000)

    :gen_tcp.send(
      socket,
      "HTTP/1.1 200 OK\r\ncontent-type: #{content_type}\r\ntransfer-encoding: chunked\r\n\r\n"
    )

    send_chunks(socket)
  end

  defp send_chunks(socket) do
    case :gen_tcp.send(socket, ["10000\r\n", @chunk, "\r\n"]) do
      :ok -> send_chunks(socket)
      {:error, _} -> :gen_tcp.close(socket)
    end
  end
end
