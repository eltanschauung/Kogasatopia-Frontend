defmodule KogasaFrontendWeb.InlineJSONSecurityTest do
  use KogasaFrontendWeb.ConnCase, async: false

  test "untrusted statistics search and player fields cannot close the inline script", %{
    conn: conn
  } do
    payload = "</script><img id=audit-injected src=x onerror=alert(1)>"
    body = conn |> get("/stats", %{"q" => payload, "player" => payload}) |> html_response(200)
    refute body =~ payload
    refute body =~ "<img id=audit-injected"
    assert body =~ "\\u003C"
  end

  test "HTML JSON encoding preserves nested values and prevents every tag boundary" do
    input = %{
      "name" => "</ScRiPt><script>alert(1)</script>",
      "nested" => ["<>&", "雪", "\u2028\u2029", nil, true, 3]
    }

    encoded = KogasaFrontend.HTMLJSON.encode!(input)
    refute encoded =~ "<"
    refute encoded =~ ">"
    refute encoded =~ "&"
    assert Jason.decode!(encoded) == input
  end
end
