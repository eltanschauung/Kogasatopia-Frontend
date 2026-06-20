defmodule KogasaFrontendWeb.MapsDbLoginController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.MapsDb
  alias KogasaFrontendWeb.SteamLogin

  def show(conn, params) do
    SteamLogin.handle(conn, params,
      login_path: "/maps/login.php",
      default_return: "/maps",
      title: "Maps Login",
      return_label: "maps",
      session_detail: &admin_session_detail/2
    )
  end

  defp admin_session_detail(steamid, esc) do
    admin = MapsDb.admin?(steamid)
    " (admin: <code>#{esc.(if admin, do: "yes", else: "no")}</code>)"
  end
end
