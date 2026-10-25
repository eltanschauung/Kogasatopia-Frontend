defmodule KogasaFrontendWeb.StatsLoginController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontendWeb.SteamLogin

  @options [
    login_path: "/stats/login.php",
    default_return: "/stats",
    title: "Stats Login",
    return_label: "stats"
  ]

  def show(conn, params) do
    SteamLogin.handle(conn, params, @options)
  end

  def logout(conn, params),
    do: SteamLogin.handle(conn, Map.put(params, "action", "logout"), @options)
end
