defmodule KogasaFrontendWeb.MapsDbController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.MapsDb

  def index(conn, _params) do
    data = MapsDb.page_data()

    render(conn, :index,
      page_title: "Maps",
      mapsdb: data,
      chart_json: Jason.encode!(data.popularity_chart),
      analytics_chart_json:
        Jason.encode!(%{
          bestPerforming: data.map_analytics.best_performing_chart
        }),
      map_sections: data.map_sections,
      popular_maps: data.popular_maps,
      map_previews: data.map_previews
    )
  end

  def legacy_redirect(conn, _params) do
    redirect(conn, to: "/maps")
  end
end
