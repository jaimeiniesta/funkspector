adapter =
  case System.get_env("FUNKSPECTOR_ADAPTER") do
    "httpoison" -> Funkspector.HTTP.Adapters.HTTPoison
    _ -> Funkspector.HTTP.Adapters.Req
  end

Application.put_env(:funkspector, :http_adapter, adapter)

ExUnit.start(exclude: [:integration])

{:ok, files} = File.ls("./test/support")

Enum.each(files, fn file ->
  Code.require_file("support/#{file}", __DIR__)
end)
