defmodule WhaleChat.LegacyPaths do
  @moduledoc false

  @static_root Path.expand("../../priv/static", __DIR__)

  def static_root do
    Application.get_env(:kogasa_frontend, :legacy_static_root, @static_root)
  end

  def playercount_widget_dir do
    Application.get_env(
      :kogasa_frontend,
      :playercount_widget_root,
      Path.join(static_root(), "playercount_widget")
    )
  end

  def quickstats_dir do
    Application.get_env(
      :kogasa_frontend,
      :quickstats_dir,
      "/home/kogasa/hlserver/tf2/tf/addons/sourcemod/logs/connections"
    )
  end

  def stats_assets_dir do
    Application.get_env(
      :kogasa_frontend,
      :chat_assets_dir,
      Path.join(static_root(), "stats/assets")
    )
  end

  def stats_cache_dir do
    Application.get_env(
      :kogasa_frontend,
      :php_stats_cache_dir,
      Path.join(static_root(), "stats/cache")
    )
  end
end
