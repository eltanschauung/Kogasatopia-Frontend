defmodule KogasaFrontendWeb.PageController do
  use KogasaFrontendWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def whaletracker(conn, _params) do
    redirect(conn, to: "/stats")
  end
end
