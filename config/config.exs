# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :whale_chat,
  ecto_repos: [WhaleChat.Repo],
  generators: [timestamp_type: :utc_datetime]

config :whale_chat,
  default_avatar_url:
    System.get_env("WT_DEFAULT_AVATAR_URL") || "/stats/assets/whaley-avatar.jpg",
  secondary_avatar_url:
    System.get_env("WT_SECONDARY_AVATAR_URL") || "/stats/assets/whaley-avatar-2.jpg",
  server_avatar_url:
    System.get_env("WT_SERVER_AVATAR_URL") || "/stats/assets/server-chat-avatar.jpg",
  chat_assets_dir: System.get_env("WT_CHAT_ASSETS_DIR") || "/var/www/kogasatopia/stats/assets",
  display_time_zone: System.get_env("WT_DISPLAY_TIME_ZONE") || "America/New_York",
  access_log_path: Path.expand("access.log")

# Configure the endpoint
config :whale_chat, WhaleChatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: WhaleChatWeb.ErrorHTML, json: WhaleChatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: WhaleChat.PubSub,
  live_view: [signing_salt: "qhUO0Cuj"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
