defmodule KogasaFrontend.MapsDb.CacheTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias KogasaFrontend.MapsDb.Cache

  setup do
    start_supervised!({Task.Supervisor, name: KogasaFrontend.MapsDb.Cache.TaskSupervisor})

    cache_path =
      Path.join(
        System.tmp_dir!(),
        "kogasa-maps-cache-#{System.unique_integer([:positive])}.etf"
      )

    on_exit(fn -> File.rm(cache_path) end)
    %{cache_path: cache_path}
  end

  test "coalesces concurrent cold-cache requests into one build", %{cache_path: cache_path} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    build_fun = fn ->
      Agent.update(counter, &(&1 + 1))
      Process.sleep(100)
      %{popular_maps: [%{map_name: "cp_process_final"}]}
    end

    {:ok, cache} =
      Cache.start_link(
        cache_path: cache_path,
        build_fun: build_fun,
        validate_fun: fn _payload -> true end
      )

    results =
      1..5
      |> Enum.map(fn _ -> Task.async(&Cache.get/0) end)
      |> Task.await_many(2_000)

    assert Enum.all?(results, fn
             {:ok, %{payload: %{popular_maps: [%{map_name: "cp_process_final"}]}}} -> true
             _ -> false
           end)

    assert Agent.get(counter, & &1) == 1
    assert File.exists?(cache_path)
    GenServer.stop(cache)

    test_pid = self()

    {:ok, cache} =
      Cache.start_link(
        cache_path: cache_path,
        build_fun: fn ->
          send(test_pid, :unexpected_rebuild)
          %{popular_maps: []}
        end,
        validate_fun: fn _payload -> true end
      )

    assert {:ok, %{payload: %{popular_maps: [%{map_name: "cp_process_final"}]}}} = Cache.get()
    refute_receive :unexpected_rebuild, 100
    GenServer.stop(cache)
  end

  test "serves stale data while a single background refresh runs", %{cache_path: cache_path} do
    {:ok, counter} = Agent.start_link(fn -> 0 end)

    initial_build = fn ->
      Agent.update(counter, &(&1 + 1))
      %{version: "old"}
    end

    {:ok, cache} =
      Cache.start_link(
        cache_path: cache_path,
        build_fun: initial_build,
        ttl_seconds: 1,
        validate_fun: fn _payload -> true end
      )

    assert {:ok, %{payload: %{version: "old"}}} = Cache.get()
    GenServer.stop(cache)

    persisted = cache_path |> File.read!() |> :erlang.binary_to_term([:safe])
    File.write!(cache_path, :erlang.term_to_binary(%{persisted | generated_at: 1}))

    refreshed_build = fn ->
      Agent.update(counter, &(&1 + 1))
      Process.sleep(150)
      %{version: "new"}
    end

    {:ok, cache} =
      Cache.start_link(
        cache_path: cache_path,
        build_fun: refreshed_build,
        ttl_seconds: 1,
        validate_fun: fn _payload -> true end
      )

    assert {:ok, %{payload: %{version: "old"}}} = Cache.get()

    assert_eventually(fn ->
      match?({:ok, %{payload: %{version: "new"}}}, Cache.get())
    end)

    assert Agent.get(counter, & &1) == 2
    GenServer.stop(cache)
  end

  test "keeps stale data when regeneration fails", %{cache_path: cache_path} do
    {:ok, cache} =
      Cache.start_link(
        cache_path: cache_path,
        build_fun: fn -> %{version: "last-good"} end,
        ttl_seconds: 1,
        validate_fun: fn _payload -> true end
      )

    assert {:ok, %{payload: %{version: "last-good"}}} = Cache.get()
    GenServer.stop(cache)

    persisted = cache_path |> File.read!() |> :erlang.binary_to_term()
    File.write!(cache_path, :erlang.term_to_binary(%{persisted | generated_at: 1}))

    {:ok, attempts} = Agent.start_link(fn -> 0 end)

    log =
      capture_log(fn ->
        {:ok, cache} =
          Cache.start_link(
            cache_path: cache_path,
            build_fun: fn ->
              Agent.update(attempts, &(&1 + 1))
              raise "database unavailable"
            end,
            retry_delay_ms: 1_000,
            ttl_seconds: 1,
            validate_fun: fn _payload -> true end
          )

        assert {:ok, %{payload: %{version: "last-good"}}} = Cache.get()
        Process.sleep(100)
        assert {:ok, %{payload: %{version: "last-good"}}} = Cache.get()
        assert {:ok, %{payload: %{version: "last-good"}}} = Cache.get()
        Process.sleep(50)
        assert Agent.get(attempts, & &1) == 1
        GenServer.stop(cache)
      end)

    assert log =~ "Maps analytics cache refresh failed"
  end

  defp assert_eventually(fun, attempts \\ 30)

  defp assert_eventually(fun, attempts) when attempts > 0 do
    if fun.() do
      :ok
    else
      Process.sleep(20)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp assert_eventually(_fun, 0), do: flunk("condition did not become true")
end
