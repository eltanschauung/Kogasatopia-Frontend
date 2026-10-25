defmodule KogasaFrontendWeb.MapsDbControllerTest do
  use KogasaFrontendWeb.ConnCase, async: false

  setup do
    previous = Application.fetch_env(:kogasa_frontend, :mapsdb_cache_enabled)
    Application.put_env(:kogasa_frontend, :mapsdb_cache_enabled, true)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:kogasa_frontend, :mapsdb_cache_enabled, value)
        :error -> Application.delete_env(:kogasa_frontend, :mapsdb_cache_enabled)
      end
    end)

    :ok
  end

  test "unavailable analytics return503 without falling back to SQL", %{conn: conn} do
    refute Process.whereis(KogasaFrontend.MapsDb.Cache)
    owner = self()
    id = "maps-unavailable-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      id,
      [:kogasa_frontend, :repo, :query],
      fn _, _, metadata, _ ->
        # The normal browser pipeline may check chat bans. Only analytics work
        # must be absent; suppressing unrelated security checks would be wrong.
        if is_binary(metadata[:query]) and
             String.contains?(metadata.query, [
               "mapsdb",
               "server_population_statistics_samples",
               "map_statistics_sessions",
               "nativevotes_statistics_events",
               "cwx_weapon_popularity",
               "plugin_statistics_events"
             ]),
           do: send(owner, :unexpected_query)
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(id) end)

    for _ <- 1..3 do
      response = get(conn, "/maps")
      assert response.status == 503
      assert response.resp_body =~ "temporarily unavailable"
      assert get_resp_header(response, "retry-after") == ["60"]
      assert get_resp_header(response, "cache-control") == ["no-store"]
    end

    refute_receive :unexpected_query
  end
end
