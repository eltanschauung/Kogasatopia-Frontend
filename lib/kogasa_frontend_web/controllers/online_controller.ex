defmodule KogasaFrontendWeb.OnlineController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.OnlineFeed

  def index(conn, _params) do
    cfg = OnlineFeed.page_config()

    render(conn, :index,
      page_title: "Online players",
      default_avatar_url: cfg.default_avatar_url,
      class_icon_base: cfg.class_icon_base,
      class_metadata: cfg.class_metadata
    )
  end
end
