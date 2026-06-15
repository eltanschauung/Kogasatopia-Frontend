defmodule WhaleChat.LegacyPaths do
  @moduledoc false

  @static_root Path.expand("../../priv/static", __DIR__)

  def static_root do
    Application.get_env(:whale_chat, :legacy_static_root, @static_root)
  end

  def playercount_widget_dir do
    Application.get_env(
      :whale_chat,
      :playercount_widget_root,
      Path.join(static_root(), "playercount_widget")
    )
  end

  def quickstats_dir do
    Application.get_env(
      :whale_chat,
      :quickstats_dir,
      "/home/kogasa/hlserver/tf2/tf/addons/sourcemod/logs/connections"
    )
  end

  def stats_assets_dir do
    Application.get_env(:whale_chat, :chat_assets_dir, Path.join(static_root(), "stats/assets"))
  end

  def stats_cache_dir do
    Application.get_env(:whale_chat, :php_stats_cache_dir, Path.join(static_root(), "stats/cache"))
  end

  def admin_cache_file do
    Application.get_env(
      :whale_chat,
      :mapsdb_admin_cache_file,
      Path.join(stats_cache_dir(), "admins_cache.json")
    )
  end
end
