defmodule KogasaFrontendWeb.MapsDbLoginController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.MapsDb
  alias KogasaFrontendWeb.SteamLogin

  def show(conn, params) do
    SteamLogin.handle(conn, params,
      login_path: "/mapsdb/login.php",
      default_return: "/mapsdb",
      title: "MapsDB Login",
      return_label: "mapsdb",
      session_detail: &admin_session_detail/2
    )
  end

  defp admin_session_detail(steamid, esc) do
    admin = MapsDb.admin?(steamid)
    " (admin: <code>#{esc.(if admin, do: "yes", else: "no")}</code>)"
  end
end
