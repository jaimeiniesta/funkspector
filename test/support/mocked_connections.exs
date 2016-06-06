defmodule Rocket.MockedConnections do
  def unsuccessful_response(status) do
    { :ok, %{ status_code: status, body: "returned body" } }
  end

  def successful_response(status \\ 200) do
    { :ok, %{ status_code: status, body: mocked_html } }
  end

  def redirection_response(to_url) do
    { :ok, %{ status_code: 301, headers: [ {"Content-length", "0"}, { "Location", to_url }, {"Content-length", "0"} ] } }
  end

  def http_error_response(url) do
    { :error, url, %HTTPoison.Error{id: nil, reason: :nxdomain} }
  end

  def redirect_from(url) do
    case url do
      "http://example.com/redirect/1" -> redirection_response("http://example.com/redirect/2")
      "http://example.com/redirect/2" -> redirection_response("http://example.com/redirect/3")
      "http://example.com/redirect/3" -> successful_response
    end
  end

  def mocked_html do
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

        <!-- External links -->
        <a href="https://twitter.com">Twitter</a>
        <a href="https://github.com">Github</a>

        <!-- Non-HTTP links -->
        <a href="mailto:hello@example.com">email</a>
        <a href="javascript:alert('hi');">hello</a>
        <a href="ftp://ftp.example.com">FTP</a>
      </body>
    </html>
    """
  end
end
