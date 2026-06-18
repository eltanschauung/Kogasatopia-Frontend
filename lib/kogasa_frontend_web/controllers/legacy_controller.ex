defmodule KogasaFrontendWeb.LegacyController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.Homepage
  alias KogasaFrontend.LegacySite

  def home(conn, _params) do
    render_home(conn)
  end

  def manual(conn, _params) do
    render_home(conn, default_tab: "updates", scroll_target: "updatesMain")
  end

  defp render_home(conn, opts \\ []) do
    html =
      opts
      |> Keyword.put(:mobile?, mobile_request?(conn))
      |> Homepage.render_html()

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  def leaderboard(conn, _params) do
    redirect(conn, to: "/online")
  end

  def passthrough(conn, %{"path" => path_parts}) do
    req_path = "/" <> Enum.join(path_parts, "/")

    cond do
      leaderboard_path?(req_path) ->
        redirect(conn, to: "/online")

      php_index_dir?(req_path) or String.ends_with?(req_path, ".php") ->
        legacy_php_unavailable(conn)

      true ->
        send_resp(conn, 404, "Not Found")
    end
  end

  defp php_index_dir?(request_path) do
    with {:ok, resolved} <- LegacySite.safe_resolve(request_path),
         true <- File.dir?(resolved) do
      File.regular?(Path.join(resolved, "index.php"))
    else
      _ -> false
    end
  end

  defp leaderboard_path?(request_path) do
    request_path in ["/leaderboard", "/leaderboard/"] or
      (String.starts_with?(request_path, "/leaderboard/") and
         String.ends_with?(request_path, ".php"))
  end

  defp legacy_php_unavailable(conn) do
    send_resp(conn, 502, "Legacy PHP backend unavailable")
  end

  defp mobile_request?(conn) do
    ua = List.first(get_req_header(conn, "user-agent")) || ""
    String.contains?(ua, "Mobile") or String.contains?(ua, "Android")
  end
end
