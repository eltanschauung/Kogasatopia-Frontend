defmodule KogasaFrontendWeb.AccessLogSecurityTest do
  use ExUnit.Case, async: true
  import Plug.Conn
  alias KogasaFrontendWeb.Plugs.AccessLog

  test "combined log omits all query proofs and strips referrer credentials" do
    conn =
      Plug.Test.conn(:get, "/info?token=synthetic-secret&openid.sig=synthetic-proof")
      |> put_req_header(
        "referer",
        "https://user:synthetic-password@example.test/info?token=synthetic-secret#proof"
      )
      |> put_req_header("user-agent", "synthetic-browser")
      |> resp(200, "ok")

    line = AccessLog.format_line(conn)
    assert line =~ ~s("GET /info HTTP/1.1" 200 2)
    assert line =~ ~s("https://example.test/info" "synthetic-browser")
    refute line =~ "synthetic-secret"
    refute line =~ "synthetic-password"
    refute line =~ "synthetic-proof"
    refute line =~ "openid"
  end

  test "untrusted fields have bounded size and cannot forge log records" do
    conn =
      Plug.Test.conn(:get, "/" <> String.duplicate("x", 10_000))
      |> put_req_header("user-agent", String.duplicate("a", 10_000))
      |> resp(200, "ok")

    line = AccessLog.format_line(conn)
    assert byte_size(line) < 8192
    assert length(String.split(line, "\n")) == 2
  end

  test "framework parameter filtering covers OpenID and nested bearer fields" do
    result =
      Phoenix.Logger.filter_values(%{
        "openid.sig" => "synthetic-proof",
        "state" => "synthetic-state",
        "payload" => %{"session_token" => "synthetic-token"},
        "page" => "2"
      })

    assert result["openid.sig"] == "[FILTERED]"
    assert result["state"] == "[FILTERED]"
    assert result["payload"]["session_token"] == "[FILTERED]"
    assert result["page"] == "2"
  end

  test "path capabilities are redacted in request and referrer paths, including encoded prefixes" do
    secret = String.duplicate("a", 32)

    for prefix <- [
          "/api/weapons/panel/",
          "/%61pi/weapons/panel/",
          "/api//weapons/panel/",
          "/api/weapons//panel/",
          "///api///weapons///panel///",
          "/api%2Fweapons/panel/"
        ] do
      path = prefix <> secret <> "/actions"

      conn =
        Plug.Test.conn(:post, path)
        |> put_req_header("referer", "https://example.test" <> path)
        |> resp(202, "ok")

      line = AccessLog.format_line(conn)
      refute line =~ secret
      assert line =~ "[FILTERED]"
      assert KogasaFrontend.LogPrivacy.request_level(conn) == false
    end

    assert Phoenix.Logger.filter_values(%{"path" => ["api", "weapons", "panel", secret]}) ==
             %{"path" => "[FILTERED]"}

    assert KogasaFrontend.LogPrivacy.request_level(Plug.Test.conn(:get, "/stats")) == :info
  end
end
