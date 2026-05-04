defmodule Funkspector.Utils do
  @moduledoc """
  Common utility functions shared across the scrapers.

  Provides URL absolutification (converting relative URLs to absolute) and
  URL validation built on top of `URI.parse/1` and the IANA TLD list bundled
  in `priv/tlds-alpha-by-domain.txt`.
  """

  @tlds_file Path.join([:code.priv_dir(:funkspector), "tlds-alpha-by-domain.txt"])
  @external_resource @tlds_file

  @tlds @tlds_file
        |> File.read!()
        |> String.split("\n", trim: true)
        |> Enum.reject(&String.starts_with?(&1, "#"))
        |> Enum.map(&String.downcase/1)
        |> MapSet.new()

  @doc """
  Converts relative URLs to absolute URLs using the given base URL.

  Accepts either a single URL string or a list of URL strings. Non-HTTP URLs
  (like `javascript:` or `mailto:`) are passed through `URI.merge/2` unchanged
  in practice, though the result depends on the URI scheme.

  ## Examples

      iex> Funkspector.Utils.absolutify(["javascript:alert(hi)", "/faqs?section=legal", "/about", "http://example.com/faqs"], "http://example.com")
      ["javascript:alert(hi)", "http://example.com/faqs?section=legal", "http://example.com/about", "http://example.com/faqs"]
  """
  @spec absolutify([String.t()], String.t()) :: [String.t()]
  def absolutify(links, base_url) when is_list(links) do
    Enum.map(links, &absolutify(&1, base_url))
  end

  @spec absolutify(String.t(), String.t()) :: String.t()
  def absolutify(link, base_url) when is_binary(link) do
    URI.merge(base_url, link) |> to_string()
  end

  @doc """
  Returns whether the given URL looks like a real, reachable HTTP(S) URL.

  A URL is considered valid when:

    * it contains no whitespace or control characters,
    * it parses with `URI.parse/1` into a recognizable URI,
    * its scheme is `http` or `https` (case-insensitive),
    * it has a non-empty host, and
    * the host is `localhost`, an IPv4/IPv6 address, or a domain whose
      last label is in the bundled IANA TLD list.

  IDN domains with ASCII TLDs (e.g. `ñandú.com`, `münchen.de`) are
  accepted. URLs whose TLD itself is non-ASCII (e.g. `example.中国`) are
  rejected, because the IANA list stores those in punycode form and we do
  not ship a punycode encoder.

  ## Examples

      iex> Funkspector.Utils.valid_url?("https://example.com")
      true

      iex> Funkspector.Utils.valid_url?("http://localhost:3000")
      true

      iex> Funkspector.Utils.valid_url?("joe@example.com")
      false

      iex> Funkspector.Utils.valid_url?(nil)
      false

      iex> Funkspector.Utils.valid_url?("  ")
      false
  """
  @spec valid_url?(any()) :: boolean()
  def valid_url?(url) when is_binary(url) do
    with false <- has_disallowed_chars?(url),
         %URI{scheme: scheme, host: host} <- URI.parse(url),
         true <- is_binary(scheme) and String.downcase(scheme) in ["http", "https"],
         true <- is_binary(host) and host != "" do
      valid_host?(host)
    else
      _ -> false
    end
  end

  def valid_url?(_), do: false

  defp has_disallowed_chars?(string) do
    String.match?(string, ~r/[\s\x00-\x1f\x7f]/u)
  end

  defp valid_host?("localhost"), do: true

  defp valid_host?(host) do
    ip_address?(host) or valid_tld?(host)
  end

  defp ip_address?(host) do
    case :inet.parse_address(String.to_charlist(host)) do
      {:ok, _} -> true
      _ -> false
    end
  end

  defp valid_tld?(host) do
    case String.split(host, ".") do
      [_single] ->
        false

      labels ->
        tld = labels |> List.last() |> String.downcase()
        ascii?(tld) and MapSet.member?(@tlds, tld)
    end
  end

  defp ascii?(string), do: string == for(<<c <- string>>, c < 128, into: "", do: <<c>>)
end
