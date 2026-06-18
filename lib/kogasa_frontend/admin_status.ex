defmodule KogasaFrontend.AdminStatus do
  @moduledoc false

  alias Ecto.Adapters.SQL
  alias KogasaFrontend.Repo

  require Logger

  @admins_table "admins"
  @steam64_base 76_561_197_960_265_728

  def admin?(steamid) do
    steamid
    |> admin_flags_for_ids()
    |> Map.values()
    |> Enum.any?()
  end

  def admin_flags_for_ids(nil), do: %{}
  def admin_flags_for_ids(""), do: %{}

  def admin_flags_for_ids(steamid) when is_binary(steamid) do
    admin_flags_for_ids([steamid])
  end

  def admin_flags_for_ids(ids) when is_list(ids) do
    ids
    |> Enum.map(&{&1, normalize_steam_id(&1)})
    |> Enum.reject(fn {_original, normalized} -> normalized == "" end)
    |> query_admin_flags()
  end

  def admin_flags_for_ids(_), do: %{}

  defp query_admin_flags([]), do: %{}

  defp query_admin_flags(pairs) do
    steam64_ids = pairs |> Enum.map(&elem(&1, 1)) |> Enum.uniq()
    placeholders = Enum.map_join(steam64_ids, ", ", fn _ -> "?" end)

    sql = """
    SELECT steamid64
    FROM #{@admins_table}
    WHERE steamid64 IN (#{placeholders})
      AND LOWER(admin_status) IN ('yes', '1', 'true', 'on')
    """

    active_admins =
      case SQL.query(Repo, sql, steam64_ids) do
        {:ok, %{rows: rows}} ->
          rows
          |> Enum.map(fn [steam64 | _] -> to_string(steam64) end)
          |> MapSet.new()

        {:error, reason} ->
          Logger.error("Failed to query admin status: #{inspect(reason)}")
          MapSet.new()
      end

    Enum.reduce(pairs, %{}, fn {original, steam64}, acc ->
      Map.put(acc, original, MapSet.member?(active_admins, steam64))
    end)
  end

  defp normalize_steam_id(value) when is_binary(value) do
    value = String.trim(value)

    cond do
      Regex.match?(~r/^\d{17}$/, value) ->
        value

      steam2 = Regex.run(~r/^STEAM_[0-5]:([0-1]):(\d+)$/i, value) ->
        [_match, auth_server, account] = steam2

        (@steam64_base + String.to_integer(account) * 2 + String.to_integer(auth_server))
        |> Integer.to_string()

      steam3 = Regex.run(~r/^\[U:1:(\d+)\]$/i, value) ->
        [_match, account_id] = steam3

        (@steam64_base + String.to_integer(account_id))
        |> Integer.to_string()

      true ->
        ""
    end
  end

  defp normalize_steam_id(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize_steam_id(_), do: ""
end
