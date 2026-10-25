defmodule KogasaFrontendWeb.LegacyControllerTest do
  use ExUnit.Case, async: false

  use KogasaFrontendWeb, :verified_routes

  import Plug.Conn, only: [get_resp_header: 2]
  import Phoenix.ConnTest

  @endpoint KogasaFrontendWeb.Endpoint

  setup do
    path = Path.join(System.tmp_dir!(), "widget-#{System.unique_integer([:positive])}")
    File.mkdir_p!(path)

    for {file, name, port} <- [
          {"quickstats.txt", "kogasa.tf | New Jersey", 27015},
          {"server27016_quickstats.txt", "kogasa.tf | MGE | New Jersey", 27016}
        ] do
      File.write!(
        Path.join(path, file),
        "Hostname: #{name}\nPort: #{port}\nPlayer Count: 0 / 24\nMap Name: koth_fixture.bsp\n"
      )
    end

    previous = Application.fetch_env(:kogasa_frontend, :quickstats_dir)
    Application.put_env(:kogasa_frontend, :quickstats_dir, path)

    on_exit(fn ->
      File.rm_rf!(path)

      case previous do
        {:ok, value} -> Application.put_env(:kogasa_frontend, :quickstats_dir, value)
        :error -> Application.delete_env(:kogasa_frontend, :quickstats_dir)
      end
    end)

    {:ok, conn: %{build_conn() | host: "localhost"}}
  end

  test "playercount widget renders natively", %{conn: conn} do
    conn = get(conn, "/playercount_widget/index.php")

    assert html_response(conn, 200) =~ ~s(<div class="server-name">kogasa.tf | New Jersey</div>)
    assert response(conn, 200) =~ "https://bantculture.com/static/flags/us.png"
    assert get_resp_header(conn, "location") == []
  end

  test "playercount widget mge iframe renders natively", %{conn: conn} do
    conn = get(conn, "/playercount_widget/index3.php")

    assert html_response(conn, 200) =~
             ~s(<div class="server-name">kogasa.tf | MGE | New Jersey</div>)

    assert response(conn, 200) =~ "https://bantculture.com/static/flags/kaguya.png"
    assert get_resp_header(conn, "location") == []
  end

  test "leaderboard app redirects to online", %{conn: conn} do
    conn = get(conn, "/leaderboard")

    assert redirected_to(conn, 302) == "/online"
  end

  test "legacy leaderboard php entrypoints redirect to online", %{conn: conn} do
    conn = get(conn, "/leaderboard/index.php")

    assert redirected_to(conn, 302) == "/online"
  end

  test "generic php passthrough returns not found", %{conn: conn} do
    conn = get(conn, "/foo.php")

    assert response(conn, 404) == "Not Found"
    assert get_resp_header(conn, "location") == []
  end
end
