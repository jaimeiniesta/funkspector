defmodule Funkspector.Scraper do
  @moduledoc """
  Provides a method to scrape a given URL.
  """

  alias Funkspector.Resolver

  @doc """
  Fetches the given URL, follows redirections, and returns the data scraped from its HTML.

  ## Examples

      iex> { :ok, data } = Funkspector.scrape("http://jaimeiniesta.com")
      iex> data.scheme
      "http"
      iex> data.host
      "jaimeiniesta.com"
      iex> data.root_url
      "http://jaimeiniesta.com/"
      iex> data.links.http.internal
      ["http://jaimeiniesta.com/",
       "http://jaimeiniesta.com/about/",
       "http://jaimeiniesta.com/archive/",
       "http://jaimeiniesta.com/portfolio/",
       "http://jaimeiniesta.com",
       "http://jaimeiniesta.com/articles/questions-about-getting-into-freelancing/",
       "http://jaimeiniesta.com/articles/building-a-disqus-recent-comments-widget-with-javascript/",
       "http://jaimeiniesta.com/articles/tips-for-a-new-rails-developer/",
       "http://jaimeiniesta.com/articles/fifteen-servers/",
       "http://jaimeiniesta.com/atom.xml"]
      iex> data.links.http.external
      ["http://jekyllrb.com",
       "http://mademistakes.com/so-simple/",
       "http://twitter.com/jaimeiniesta",
       "http://facebook.com/jaime.iniesta.7",
       "http://plus.google.com/+jaimeiniesta",
       "http://linkedin.com/in/jaimeiniesta",
       "http://instagram.com/jaimeiniesta",
       "http://www.flickr.com/photos/jaimeiniesta", "http://github.com/jaimeiniesta"]
      iex> data.links.non_http
      ["mailto:jaimeiniesta@gmail.com"]

      iex> { :ok, data } = Funkspector.scrape("http://github.com")
      iex> data.original_url
      "http://github.com"
      iex> data.final_url
      "https://github.com/"
  """
  def scrape(original_url) do
    case Resolver.resolve(original_url) do
      { :ok, final_url, response } ->
        handle_response(response, original_url, final_url)
      { _, url, response } ->
        { :error, url, response}
    end
  end

  defp handle_response(response = %{status_code: status, body: _body }, original_url, _final_url) when not status in 200..299 do
    { :error, original_url, response }
  end

  defp handle_response(%{status_code: status, body: body }, original_url, final_url) when status in 200..299 do
    { :ok, scraped_data(body, original_url, final_url) }
  end

  defp scraped_data(body, original_url, final_url) do
    %{scheme: scheme, host: host} = URI.parse(final_url)

    raw_links                          = raw_links(body)
    { http_links, non_http_links }     = http_and_non_http(raw_links)
    { internal_links, external_links } = internal_and_external(http_links, host)

    %{
      scheme: scheme,
      host: host,
      original_url: original_url,
      final_url: final_url,
      root_url: "#{scheme}://#{host}/",
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

  defp raw_links(html) do
    html
    |> Floki.find("a")
    |> Floki.attribute("href")
    |> Enum.uniq
  end

  defp http_and_non_http(links) do
    Enum.partition(links, &(&1 =~ ~r/^http(s)?:\/\//i))
  end

  defp internal_and_external(links, host) do
    Enum.partition(links, &(&1 =~ ~r/^http(s)?:\/\/#{host}/i))
  end
end
