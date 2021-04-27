defmodule Funkspector.PageScraper do
  @moduledoc """
  Provides a method to scrape an HTML page, given its URL.
  """

  import Funkspector, only: [default_options: 0]
  import Funkspector.Utils
  alias Funkspector.Resolver

  @doc """
  Fetches the given URL, follows redirections, and returns the data scraped from its HTML.

  ## Examples

      iex> { :ok, data } = Funkspector.PageScraper.scrape("http://example.com")
      iex> data.scheme
      "http"
      iex> data.host
      "example.com"
      iex> data.root_url
      "http://example.com/"
      iex> data.links.http.internal
      []
      iex> data.links.http.external
      ["https://www.iana.org/domains/example"]
      iex> data.links.non_http
      []

      iex> { :ok, data } = Funkspector.PageScraper.scrape("http://github.com")
      iex> data.original_url
      "http://github.com"
      iex> data.final_url
      "https://github.com/"
  """
  def scrape(original_url, options \\ %{}) do
    options = Map.merge(default_options(), options)

    case Resolver.resolve(original_url, options) do
      {:ok, final_url, response} ->
        handle_response(response, original_url, final_url)

      {_, url, response} ->
        {:error, url, response}
    end
  end

  #####################
  # Private functions #
  #####################

  defp handle_response(response = %{status_code: status, body: _body}, original_url, _final_url)
       when status not in 200..299 do
    {:error, original_url, response}
  end

  defp handle_response(
         %{status_code: status, headers: headers, body: body},
         original_url,
         final_url
       )
       when status in 200..299 do
    {:ok, scraped_data(headers, body, original_url, final_url)}
  end

  defp scraped_data(headers, body, original_url, final_url) do
    base_url = base_href(body, final_url) || final_url

    %{scheme: scheme, host: host} = URI.parse(final_url)

    root_url = "#{scheme}://#{host}/"
    raw_links = raw_links(body)

    {http_links, non_http_links} =
      raw_links
      |> absolutify(base_url)
      |> http_and_non_http

    {internal_links, external_links} = internal_and_external(http_links, host)

    %{
      scheme: scheme,
      host: host,
      original_url: original_url,
      final_url: final_url,
      root_url: root_url,
      headers: Enum.into(headers, %{}),
      body: body,
      links: %{
        raw: raw_links,
        http: %{
          internal: internal_links,
          external: external_links
        },
        non_http: non_http_links
      }
    }
  end

  defp base_href(html, final_url) do
    case html
         |> Floki.find("base")
         |> Floki.attribute("href")
         |> List.first() do
      nil -> nil
      base_href -> absolutify(base_href, final_url)
    end
  end

  defp raw_links(html) do
    html
    |> Floki.find("a")
    |> Floki.attribute("href")
    |> Enum.map(&String.trim/1)
    |> Enum.uniq()
  end

  defp http_and_non_http(links) do
    Enum.split_with(links, &(&1 =~ ~r/^http(s)?:\/\//i))
  end

  defp internal_and_external(links, host) do
    Enum.split_with(links, &same_host?(&1, host))
  end

  defp same_host?(link, host) do
    case URI.parse(link) do
      %{host: ^host} -> true
      _ -> false
    end
  end
end
