defmodule KogasaFrontend.Online do
  @moduledoc false

  import KogasaFrontend.Value, only: [int: 1]

  alias Ecto.Adapters.SQL
  alias KogasaFrontend.Repo

  @default_visible_max 32

  def summary do
    now = System.system_time(:second)
    cutoff = now - 180

    {player_count, visible_max, updated} =
      case aggregate_server_counts(cutoff, now) do
        {players, slots, _updated_at} when slots > 0 ->
          # OnlineFeed uses the live client rows when a fresh server heartbeat
          # reports zero players, so preserve that behavior for nav/API parity.
          fallback_players =
            if players > 0, do: players, else: elem(fallback_online_count(now), 0)

          {fallback_players, slots, now}

        _ ->
          fallback_online_count(now)
      end

    %{
      success: true,
      player_count: max(player_count, 0),
      visible_max: if(visible_max > 0, do: visible_max, else: @default_visible_max),
      updated: updated
    }
  end

  defp aggregate_server_counts(cutoff, now) do
    sql = """
    SELECT
      COALESCE(SUM(playercount), 0) AS total_players,
      COALESCE(SUM(visible_max), 0) AS total_slots,
      COALESCE(MAX(last_update), ?) AS last_update
    FROM whaletracker_servers
    WHERE last_update >= ?
    """

    case SQL.query(Repo, sql, [now, cutoff]) do
      {:ok, %{rows: [[players, slots, updated]]}} ->
        {int(players), int(slots), int(updated)}

      _ ->
        {0, 0, now}
    end
  rescue
    _ -> {0, 0, now}
  end

  defp fallback_online_count(now) do
    case SQL.query(Repo, "SELECT COUNT(*) AS total_players FROM whaletracker_online", []) do
      {:ok, %{rows: [[players]]}} -> {int(players), @default_visible_max, now}
      _ -> {0, @default_visible_max, now}
    end
  rescue
    _ -> {0, @default_visible_max, now}
  end
end
