defmodule KogasaFrontend.PlayerIdentity do
  @moduledoc false

  alias Ecto.Adapters.SQL
  alias KogasaFrontend.AdminStatus
  alias KogasaFrontend.Chat.NameStyle
  alias KogasaFrontend.Repo

  require Logger

  def stats_mode do
    if Application.get_env(:kogasa_frontend, :stats_use_filter_identity, false),
      do: :filters,
      else: :steam
  end

  def for_ids(ids) do
    ids = normalize_ids(ids)
    prenames = query_names("prename_rules", "pattern", "newname", ids)
    cached_names = query_names("filters_steam_names", "steamid64", "last_name", ids)
    preferences = query_preferences(ids)
    admin_flags = AdminStatus.admin_flags_for_ids(ids)

    Map.new(ids, fn steamid ->
      preference = Map.get(preferences, steamid)

      {steamid,
       %{
         prename: Map.get(prenames, steamid, ""),
         cached_name: Map.get(cached_names, steamid, ""),
         name_style: NameStyle.from_preference(preference),
         is_admin: Map.get(admin_flags, steamid, false)
       }}
    end)
  end

  def name_styles_for_ids(ids) do
    ids
    |> normalize_ids()
    |> query_preferences()
    |> Map.new(fn {steamid, preference} ->
      {steamid, NameStyle.from_preference(preference)}
    end)
  end

  def get(identities, steamid) when is_map(identities) do
    Map.get(identities, normalize(steamid), empty())
  end

  def get(_identities, _steamid), do: empty()

  def resolve_name(identity, api_name, fallback_name, steamid, mode \\ :filters) do
    candidates =
      case mode do
        :steam ->
          [value(identity, :cached_name), api_name, fallback_name, steamid]

        _ ->
          [
            value(identity, :prename),
            value(identity, :cached_name),
            api_name,
            fallback_name,
            steamid
          ]
      end

    candidates
    |> Enum.find_value("", fn candidate ->
      case normalize(candidate) do
        "" -> nil
        name -> name
      end
    end)
  end

  def name_style(_identity, :steam), do: nil
  def name_style(identity, _mode), do: value(identity, :name_style)

  def empty do
    %{prename: "", cached_name: "", name_style: nil, is_admin: false}
  end

  defp query_names(_table, _id_column, _name_column, []), do: %{}

  defp query_names(table, id_column, name_column, ids) do
    placeholders = Enum.map_join(ids, ", ", fn _ -> "?" end)

    sql =
      "SELECT #{id_column}, #{name_column} FROM #{table} WHERE #{id_column} IN (#{placeholders})"

    case SQL.query(Repo, sql, ids) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [steamid, name | _] -> {normalize(steamid), normalize(name)} end)

      {:error, reason} ->
        Logger.debug(fn ->
          "Player identity name query failed for #{table}: #{inspect(reason)}"
        end)

        %{}
    end
  rescue
    error ->
      Logger.debug(fn -> "Player identity name query crashed for #{table}: #{inspect(error)}" end)
      %{}
  end

  defp query_preferences([]), do: %{}

  defp query_preferences(ids) do
    placeholders = Enum.map_join(ids, ", ", fn _ -> "?" end)

    sql =
      "SELECT steamid, color, pattern FROM filters_namecolors WHERE steamid IN (#{placeholders})"

    case SQL.query(Repo, sql, ids) do
      {:ok, %{rows: rows}} ->
        Map.new(rows, fn [steamid, color, pattern | _] ->
          {normalize(steamid), %{color: normalize(color), pattern: normalize(pattern)}}
        end)

      {:error, reason} ->
        Logger.debug(fn -> "Player identity preference query failed: #{inspect(reason)}" end)
        %{}
    end
  rescue
    error ->
      Logger.debug(fn -> "Player identity preference query crashed: #{inspect(error)}" end)
      %{}
  end

  defp normalize_ids(ids) do
    ids
    |> List.wrap()
    |> Enum.map(&normalize/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp value(map, key) when is_map(map),
    do: Map.get(map, key) || Map.get(map, Atom.to_string(key))

  defp value(_map, _key), do: nil

  defp normalize(value) when is_binary(value), do: String.trim(value)
  defp normalize(value) when is_integer(value), do: Integer.to_string(value)
  defp normalize(_value), do: ""
end
