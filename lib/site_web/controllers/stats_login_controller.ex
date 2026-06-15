defmodule WhaleChatWeb.StatsLoginController do
  use WhaleChatWeb, :controller

  alias WhaleChatWeb.SteamLogin

  def show(conn, params) do
    SteamLogin.handle(conn, params,
      login_path: "/stats/login.php",
      default_return: "/stats",
      title: "Stats Login",
      return_label: "stats"
    )
  end
end
