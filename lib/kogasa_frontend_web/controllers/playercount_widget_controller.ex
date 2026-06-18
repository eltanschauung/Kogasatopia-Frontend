defmodule KogasaFrontendWeb.PlayercountWidgetController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.PlayercountWidget

  def index(conn, _params), do: send_widget(conn, :index)
  def index2(conn, _params), do: send_widget(conn, :index2)
  def index3(conn, _params), do: send_widget(conn, :index3)
  def index4(conn, _params), do: send_widget(conn, :index4)

  defp send_widget(conn, widget) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, PlayercountWidget.render(widget))
  end
end
