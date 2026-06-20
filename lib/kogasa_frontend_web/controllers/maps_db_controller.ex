defmodule KogasaFrontendWeb.MapsDbController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.MapsDb

  def index(conn, _params) do
    steamid = get_session(conn, "steamid")
    data = MapsDb.page_data(steamid)

    render(conn, :index,
      mapsdb: data,
      chart_json: Jason.encode!(data.popularity_chart),
      analytics_chart_json:
        Jason.encode!(%{
          population: data.map_analytics.population_curve_chart,
          first15: data.map_analytics.first15_chart
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
