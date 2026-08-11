defmodule KogasaFrontendWeb.MapsDbController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.MapsDb
  alias KogasaFrontend.TimeDisplay

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
      map_previews: data.map_previews,
      maps_cache_hash: data.analytics_cache_hash,
      maps_cache_generated_at:
        TimeDisplay.format_server_datetime(data.analytics_cached_at, "%m/%d/%Y %H:%M:%S %Z")
    )
  end

  def legacy_redirect(conn, _params) do
    redirect(conn, to: "/maps")
  end
end
