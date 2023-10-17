defmodule Funkspector.SitemapScraper do
  @moduledoc """
  Provides a method to scrape an XML sitemap, given its URL.
  """

  alias Funkspector.Resolver

  import Funkspector, only: [default_options: 0]
  import Funkspector.Utils
  import SweetXml

  @doc """
  Fetches the given URL, follows redirections, and returns the data scraped from its XML.
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
    %{scheme: scheme, host: host} = URI.parse(final_url)

    root_url = "#{scheme}://#{host}/"
    locs = raw_locs(body) |> absolutify(root_url)

    %{
      scheme: scheme,
      host: host,
      original_url: original_url,
      final_url: final_url,
      root_url: root_url,
      headers: Enum.into(headers, %{}),
      body: body,
      locs: locs
    }
  end

  defp raw_locs(xml) do
    try do
      xml
      |> parse(quiet: true)
      |> xpath(~x"//url/loc/text()"l)
      |> Enum.uniq()
      |> Enum.map(&to_string/1)
    catch
      _, _ -> []
    end
  end
end
