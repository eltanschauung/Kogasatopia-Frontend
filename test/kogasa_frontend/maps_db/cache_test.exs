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

  test "caps cold waiters and removes disconnected callers", %{cache_path: cache_path} do
    test_pid = self()

    {:ok, cache} =
      Cache.start_link(
        cache_path: cache_path,
        max_waiters: 2,
        build_fun: fn ->
          send(test_pid, {:builder, self()})

          receive do
            :finish -> %{version: "ready"}
          end
        end,
        validate_fun: fn _ -> true end
      )

    assert_receive {:builder, builder}
    caller = spawn(fn -> Cache.get() end)
    waiter = Task.async(&Cache.get/0)
    assert_eventually(fn -> map_size(:sys.get_state(cache).waiters) == 2 end)
    assert {:error, :busy} = Cache.get()
    Process.exit(caller, :kill)
    assert_eventually(fn -> map_size(:sys.get_state(cache).waiters) == 1 end)
    send(builder, :finish)
    assert {:ok, %{payload: %{version: "ready"}}} = Task.await(waiter)
    assert :sys.get_state(cache).waiters == %{}
    GenServer.stop(cache)
  end

  test "bounds caller waits and kills timed-out builds with retry backoff", %{
    cache_path: cache_path
  } do
    test_pid = self()

    capture_log(fn ->
      {:ok, cache} =
        Cache.start_link(
          cache_path: cache_path,
          wait_timeout_ms: 15,
          build_timeout_ms: 80,
          retry_delay_ms: 1_000,
          build_fun: fn ->
            send(test_pid, {:builder, self()})

            receive do
              :never -> %{version: "late"}
            end
          end,
          validate_fun: fn _ -> true end
        )

      assert_receive {:builder, builder}
      monitor = Process.monitor(builder)
      assert {:error, :timeout} = Cache.get()
      assert :sys.get_state(cache).waiters == %{}
      assert_receive {:DOWN, ^monitor, :process, ^builder, :killed}, 1_000
      assert_eventually(fn -> is_nil(:sys.get_state(cache).refresh_ref) end)
      assert {:error, :refresh_backoff} = Cache.get()
      refute_receive {:builder, _}, 50
      GenServer.stop(cache)
    end)
  end

  test "serves stale data even after a bounded refresh times out", %{cache_path: cache_path} do
    {:ok, cache} =
      Cache.start_link(
        cache_path: cache_path,
        build_fun: fn -> %{version: "last-good"} end,
        validate_fun: fn _ -> true end
      )

    assert {:ok, _} = Cache.get()
    GenServer.stop(cache)

    persisted = cache_path |> File.read!() |> :erlang.binary_to_term([:safe])
    File.write!(cache_path, :erlang.term_to_binary(%{persisted | generated_at: 1}))

    capture_log(fn ->
      {:ok, cache} =
        Cache.start_link(
          cache_path: cache_path,
          build_timeout_ms: 20,
          retry_delay_ms: 1_000,
          build_fun: fn ->
            receive do
              :never -> %{}
            end
          end,
          validate_fun: fn _ -> true end
        )

      assert {:ok, %{payload: %{version: "last-good"}}} = Cache.get()
      assert_eventually(fn -> not is_nil(:sys.get_state(cache).next_refresh_at) end)
      assert {:ok, %{payload: %{version: "last-good"}}} = Cache.get()
      GenServer.stop(cache)
    end)
  end

  test "stopping or crashing the cache cannot orphan a refresh", %{cache_path: cache_path} do
    test_pid = self()

    for stop <- [:normal, :kill] do
      {:ok, cache} =
        Cache.start_link(
          cache_path: cache_path,
          build_fun: fn ->
            send(test_pid, {:builder, self()})

            receive do
              :never -> %{}
            end
          end,
          validate_fun: fn _ -> true end
        )

      Process.unlink(cache)
      assert_receive {:builder, builder}
      monitor = Process.monitor(builder)
      if stop == :normal, do: GenServer.stop(cache), else: Process.exit(cache, :kill)
      assert_receive {:DOWN, ^monitor, :process, ^builder, _reason}, 1_000
      assert_eventually(fn -> is_nil(Process.whereis(Cache)) end)
    end
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
