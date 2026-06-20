defmodule KogasaFrontendWeb.Router do
  use KogasaFrontendWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {KogasaFrontendWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug KogasaFrontendWeb.Plugs.ChatIdentity
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :chat_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug KogasaFrontendWeb.Plugs.ChatIdentity
  end

  pipeline :mapsdb_api do
    plug :accepts, ["json"]
    plug :fetch_session
  end

  scope "/", KogasaFrontendWeb do
    pipe_through :browser

    get "/", LegacyController, :home
    get "/index.php", LegacyController, :home
    get "/index.html", LegacyController, :home
    get "/manual", LegacyController, :manual
    get "/changelog", LegacyController, :manual
    get "/info", InfoController, :entry
    get "/info/index.html", InfoController, :entry
    get "/weapons", InfoController, :entry
    get "/weapons/index.html", InfoController, :entry
    get "/leaderboard", LegacyController, :leaderboard
    get "/stats", StatsController, :index
    get "/stats/index.php", StatsController, :index
    get "/whaletracker", PageController, :whaletracker
    get "/nav", PageController, :home
    live "/chat", ChatLive
    get "/online", OnlineController, :index
    get "/logs", LogsController, :index
    get "/logs/index.php", LogsController, :index
    get "/logs/short", LogsController, :short
    get "/logs/short/index.php", LogsController, :short
    get "/logs/current", LogsController, :current
    get "/logs/current/index.php", LogsController, :current
    get "/stats/login.php", StatsLoginController, :show
    get "/maps", MapsDbController, :index
    get "/maps/index.php", MapsDbController, :index
    get "/maps/login.php", MapsDbLoginController, :show
    get "/mapsdb", MapsDbController, :legacy_redirect
    get "/mapsdb/index.php", MapsDbController, :legacy_redirect
    get "/mapsdb/login.php", MapsDbLoginController, :show
  end

  scope "/stats", KogasaFrontendWeb do
    pipe_through :chat_api

    get "/chat.php", ChatApiController, :index
    post "/chat.php", ChatApiController, :create
    get "/online_summary.php", OnlineSummaryController, :index
    get "/online.php", OnlineApiController, :index
    get "/fetch_page.php", StatsApiController, :fetch_page
    get "/cumulative_fragment.php", StatsApiController, :cumulative_fragment
    get "/logs_fragment.php", StatsApiController, :logs_fragment
    get "/current_log_fragment.php", StatsApiController, :current_log_fragment
  end

  scope "/mapsdb", KogasaFrontendWeb do
    pipe_through :mapsdb_api

    get "/api.php", MapsDbApiController, :handle
    post "/api.php", MapsDbApiController, :handle
  end

  scope "/maps", KogasaFrontendWeb do
    pipe_through :mapsdb_api

    get "/api.php", MapsDbApiController, :handle
    post "/api.php", MapsDbApiController, :handle
  end

  scope "/playercount_widget", KogasaFrontendWeb do
    pipe_through :browser

    get "/index.php", PlayercountWidgetController, :index
    get "/index2.php", PlayercountWidgetController, :index2
    get "/index3.php", PlayercountWidgetController, :index3
    get "/index4.php", PlayercountWidgetController, :index4
  end

  scope "/", KogasaFrontendWeb do
    pipe_through :browser

    match :*, "/*path", LegacyController, :passthrough
  end

  # Other scopes may use custom stacks.
  # scope "/api", KogasaFrontendWeb do
  #   pipe_through :api
  # end
end
