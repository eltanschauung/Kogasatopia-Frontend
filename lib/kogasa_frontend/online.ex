defmodule KogasaFrontend.Online do
  @moduledoc false

  import KogasaFrontend.Value, only: [int: 1]

  alias Ecto.Adapters.SQL
  alias KogasaFrontend.Repo

  @default_visible_max 32
  @online_fresh_seconds 30

  def summary do
    now = System.system_time(:second)
    cutoff = now - 180
    human_player_count = human_online_count(now)

    visible_max =
      case aggregate_server_counts(cutoff, now) do
        {_players, slots, _updated_at} when slots > 0 ->
          slots

        _ ->
          @default_visible_max
      end

    %{
      success: true,
      player_count: max(human_player_count, 0),
      visible_max: if(visible_max > 0, do: visible_max, else: @default_visible_max),
      updated: now
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

  defp human_online_count(now) do
    cutoff = now - @online_fresh_seconds

    case SQL.query(
           Repo,
           "SELECT COUNT(*) AS total_players FROM whaletracker_online WHERE last_update >= ?",
           [cutoff]
         ) do
      {:ok, %{rows: [[players]]}} -> int(players)
      _ -> 0
    end
  rescue
    _ -> 0
  end
end
