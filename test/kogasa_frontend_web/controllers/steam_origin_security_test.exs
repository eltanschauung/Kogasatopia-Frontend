defmodule KogasaFrontendWeb.SteamOriginSecurityTest do
  use ExUnit.Case, async: false
  import Plug.Conn
  alias KogasaFrontendWeb.SteamLogin

  @opts [login_path: "/stats/login.php", default_return: "/stats"]

  setup do
    previous = Application.get_env(:kogasa_frontend, KogasaFrontendWeb.Endpoint)

    Application.put_env(
      :kogasa_frontend,
      KogasaFrontendWeb.Endpoint,
      Keyword.put(previous, :url, scheme: "https", host: "site.example", port: 443)
    )

    on_exit(fn -> Application.put_env(:kogasa_frontend, KogasaFrontendWeb.Endpoint, previous) end)
  end

  test "untrusted Host and forwarded headers cannot choose the OpenID callback origin" do
    conn =
      Plug.Test.conn(:get, "http://untrusted.example/stats/login.php")
      |> Plug.Test.init_test_session(%{})
      |> put_req_header("x-forwarded-host", "untrusted.example")
      |> put_req_header("x-forwarded-proto", "http")

    result = SteamLogin.handle(conn, %{"return" => "/chat?view=all"}, @opts)

    query =
      result
      |> get_resp_header("location")
      |> hd()
      |> URI.parse()
      |> Map.fetch!(:query)
      |> URI.decode_query()

    assert query["openid.realm"] == "https://site.example"
    assert String.starts_with?(query["openid.return_to"], "https://site.example/stats/login.php?")
    refute query["openid.return_to"] =~ "untrusted.example"
  end

  test "logout return values reject ambiguous browser authority and control characters" do
    for path <- [
          "//untrusted.example",
          "/\\untrusted.example",
          "/\t/untrusted.example",
          "/\n/untrusted.example",
          "/\r/untrusted.example",
          "https://untrusted.example",
          ["/chat"]
        ] do
      conn = Plug.Test.conn(:post, "/stats/login.php") |> Plug.Test.init_test_session(%{})
      result = SteamLogin.handle(conn, %{"action" => "logout", "return" => path}, @opts)
      assert get_resp_header(result, "location") == ["/stats"]
    end
  end

  test "ordinary local query and fragment returns remain supported" do
    path = "/stats?player=10000000000000001#recent"
    conn = Plug.Test.conn(:post, "/stats/login.php") |> Plug.Test.init_test_session(%{})
    result = SteamLogin.handle(conn, %{"action" => "logout", "return" => path}, @opts)
    assert get_resp_header(result, "location") == [path]
  end
end
