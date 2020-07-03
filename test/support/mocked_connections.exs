defmodule Rocket.MockedConnections do
  def unsuccessful_response(status) do
    {:ok, %{status_code: status, body: "returned body"}}
  end

  def successful_response(status \\ 200) do
    {:ok, %{status_code: status, headers: mocked_html_headers(), body: mocked_html()}}
  end

  def successful_response_with_base_href(status \\ 200, url) do
    {:ok,
     %{status_code: status, headers: mocked_html_headers(), body: mocked_html_with_base_href(url)}}
  end

  def successful_response_for_sitemap(status \\ 200) do
    {:ok, %{status_code: status, headers: mocked_xml_headers(), body: mocked_xml()}}
  end

  def malformed_xml_response(status \\ 200) do
    {:ok, %{status_code: status, headers: mocked_xml_headers(), body: malformed_xml()}}
  end

  def redirection_response(location_key, to_url) do
    {:ok,
     %{
       status_code: 301,
       headers: [{"Content-length", "0"}, {location_key, to_url}, {"Content-length", "0"}]
     }}
  end

  def http_error_response(url) do
    {:error, url, %HTTPoison.Error{id: nil, reason: :nxdomain}}
  end

  def redirect_from(url) do
    case url do
      "http://example.com/redirect/1" ->
        redirection_response("Location", "http://example.com/redirect/2")

      "http://example.com/redirect/2" ->
        redirection_response("Location", "http://example.com/redirect/3")

      "http://example.com/redirect/3" ->
        successful_response()

      "http://example.com/redirect/relative" ->
        redirection_response("Location", "/redirect/3")

      "http://example.com/redirect/lowercase-location" ->
        redirection_response("location", "/redirect/3")
    end
  end

  def mocked_html() do
    """
    <html>
      <head>
        <title>An example page</title>
      </head>
      <body>
        <!-- Internal absolute links -->
        <a href="http://example.com/">Root</a>
        <a href="http://example.com/faqs">FAQs</a>
        <a href="http://example.com/faqs">FAQs (duplicate link that will be ignored)</a>
        <a href="http://example.com/contact">Contact</a>
        <a href="https://example.com/secure.html">Secure</a>

        <!--
        <a href="https://example.com/not-included.html">Commented out should not be included</a>
        -->

        <!-- Internal relative links -->
        <a href="/relative-1">Relative 1, including root</a>
        <a href="relative-2">Relative 2, not including root</a>
        <a href="relative-3?q=some#results">Relative 3, with querystring and anchor</a>

        <!-- External links -->
        <a href="https://twitter.com">Twitter</a>
        <a href="https://github.com">Github</a>
        <a href="http://example.com.br">Example BR</a>
        <a href="http://example.com.mx/faqs">Example MX</a>

        <!-- Non-HTTP links -->
        <a href="mailto:hello@example.com">email</a>
        <a href="javascript:alert('hi');">hello</a>
        <a href="ftp://ftp.example.com">FTP</a>
      </body>
    </html>
    """
  end

  def mocked_html_with_base_href(url) do
    mocked_html()
    |> String.replace("<head>", "<head><base href=\"#{url}\">")
  end

  def mocked_xml do
    """
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
       <url>
          <loc>/</loc>
       </url>
       <url>
          <loc>/faqs</loc>
       </url>
       <url>
          <loc>/about</loc>
       </url>
       <!--
       <url>
          <loc>/commented-out-should-not-be-included</loc>
       </url>
       -->
    </urlset>
    """
  end

  def malformed_xml do
    "<xml>"
  end

  def mocked_html_headers do
    [
      {"content-length", "293427"},
      {"content-type", "text/html;charset=utf-8"}
    ]
  end

  def mocked_xml_headers do
    [
      {"content-length", "293427"},
      {"content-type", "text/xml;charset=utf-8"}
    ]
  end
end
