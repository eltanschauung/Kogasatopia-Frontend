defmodule KogasaFrontendWeb.StatsLoginController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontendWeb.SteamLogin

  def show(conn, params) do
    SteamLogin.handle(conn, params,
      login_path: "/stats/login.php",
      default_return: "/stats",
      title: "Stats Login",
      return_label: "stats"
    )
  end
end
