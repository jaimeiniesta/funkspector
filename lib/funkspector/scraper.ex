defmodule Funkspector.Scraper do
  # TODO: raise error on bad URL
  # TODO: normalize URL
  # TODO: follow redirections
  def scrape(url) do
    url
    |> HTTPoison.get
    |> handle_response(url)
  end

  def handle_response({ :ok, %{status_code: status, body: body }}, url) when status in 200..299 do
    { :ok, scraped_data(body, url) }
  end

  def handle_response({ _,   %{status_code: _,   body: body}}, url) do
    { :error, %{url: url, body: body} }
  end

  defp scraped_data(body, url) do
    %{
      body: body,
      url: url,
      root_url: root_url(url),
      links: %{
        raw: raw_links(body)
      }
    }
  end

  defp root_url(url) do
    %{scheme: scheme, host: host} = URI.parse(url)

    "#{scheme}://#{host}/"
  end

  defp raw_links(html) do
    html
    |> Floki.find("a")
    |> Floki.attribute("href")
  end
end
