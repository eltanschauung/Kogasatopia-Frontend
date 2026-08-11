defmodule KogasaFrontend.MapsDb.Cache do
  @moduledoc false

  use GenServer

  require Logger

  @cache_version 1
  @default_ttl_seconds 24 * 60 * 60
  @default_retry_delay_ms 60_000
  @table __MODULE__
  @task_supervisor Module.concat(__MODULE__, TaskSupervisor)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def enabled? do
    Application.get_env(:kogasa_frontend, :mapsdb_cache_enabled, true)
  end

  def get do
    case lookup_entry() do
      {:ok, entry, :fresh} ->
        {:ok, entry}

      {:ok, entry, :stale} ->
        refresh()
        {:ok, entry}

      :error ->
        if Process.whereis(__MODULE__) do
          GenServer.call(__MODULE__, :get_or_build, :infinity)
        else
          {:error, :not_started}
        end
    end
  end

  def refresh do
    if Process.whereis(__MODULE__), do: GenServer.cast(__MODULE__, :refresh)
    :ok
  end

  @impl true
  def init(opts) do
    :ets.new(@table, [:named_table, :set, :protected, read_concurrency: true])

    state = %{
      build_fun: Keyword.get(opts, :build_fun, &KogasaFrontend.MapsDb.build_cache_payload/0),
      cache_path: Keyword.get(opts, :cache_path, configured_cache_path()),
      next_refresh_at: nil,
      refresh_ref: nil,
      retry_delay_ms: Keyword.get(opts, :retry_delay_ms, @default_retry_delay_ms),
      ttl_seconds: Keyword.get(opts, :ttl_seconds, configured_ttl_seconds()),
      validate_fun: Keyword.get(opts, :validate_fun, &valid_maps_payload?/1),
      waiters: []
    }

    :ets.insert(@table, {:ttl_seconds, state.ttl_seconds})
    state = load_persisted_entry(state)

    case lookup_entry(state.ttl_seconds) do
      {:ok, _entry, :fresh} -> :ok
      _ -> send(self(), :refresh)
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_or_build, from, state) do
    case lookup_entry(state.ttl_seconds) do
      {:ok, entry, freshness} ->
        state = if freshness == :stale, do: start_refresh(state), else: state
        {:reply, {:ok, entry}, state}

      :error ->
        state = start_refresh(state)

        if state.refresh_ref do
          {:noreply, add_waiter(state, from)}
        else
          {:reply, {:error, :refresh_backoff}, state}
        end
    end
  end

  @impl true
  def handle_cast(:refresh, state), do: {:noreply, start_refresh(state)}

  @impl true
  def handle_info(:refresh, state), do: {:noreply, start_refresh(state)}

  def handle_info({ref, {:ok, payload, elapsed_ms}}, %{refresh_ref: ref} = state) do
    Process.demonitor(ref, [:flush])

    entry = build_entry(payload)
    :ets.insert(@table, {:entry, entry})

    case persist_entry(state.cache_path, entry) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Could not persist maps analytics cache: #{inspect(reason)}")
    end

    Logger.info("Regenerated maps analytics cache hash=#{entry.hash} elapsed_ms=#{elapsed_ms}")

    reply_waiters(state.waiters, {:ok, entry})
    {:noreply, %{state | next_refresh_at: nil, refresh_ref: nil, waiters: []}}
  end

  def handle_info({ref, {:error, reason, elapsed_ms}}, %{refresh_ref: ref} = state) do
    Process.demonitor(ref, [:flush])
    Logger.error("Maps analytics cache refresh failed after #{elapsed_ms}ms: #{inspect(reason)}")
    reply_waiters(state.waiters, {:error, reason})
    {:noreply, refresh_failed(state)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{refresh_ref: ref} = state) do
    Logger.error("Maps analytics cache task exited: #{inspect(reason)}")
    reply_waiters(state.waiters, {:error, reason})
    {:noreply, refresh_failed(state)}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp start_refresh(%{refresh_ref: nil} = state) do
    if is_nil(state.next_refresh_at) or monotonic_milliseconds() >= state.next_refresh_at do
      task =
        Task.Supervisor.async_nolink(@task_supervisor, fn ->
          started_at = monotonic_milliseconds()

          result =
            try do
              case state.build_fun.() do
                payload when is_map(payload) ->
                  if state.validate_fun.(payload) do
                    {:ok, payload}
                  else
                    {:error, :invalid_payload}
                  end

                other ->
                  {:error, {:invalid_payload, other}}
              end
            rescue
              error -> {:error, Exception.format(:error, error, __STACKTRACE__)}
            catch
              kind, reason -> {:error, Exception.format(kind, reason, __STACKTRACE__)}
            end

          elapsed_ms = monotonic_milliseconds() - started_at

          case result do
            {:ok, payload} -> {:ok, payload, elapsed_ms}
            {:error, reason} -> {:error, reason, elapsed_ms}
          end
        end)

      %{state | refresh_ref: task.ref}
    else
      state
    end
  end

  defp start_refresh(state), do: state

  defp add_waiter(state, from), do: %{state | waiters: [from | state.waiters]}

  defp reply_waiters(waiters, reply) do
    Enum.each(waiters, &GenServer.reply(&1, reply))
  end

  defp refresh_failed(state) do
    %{
      state
      | next_refresh_at: monotonic_milliseconds() + state.retry_delay_ms,
        refresh_ref: nil,
        waiters: []
    }
  end

  defp lookup_entry(ttl_seconds \\ nil) do
    ttl_seconds = ttl_seconds || cached_ttl_seconds()

    case :ets.lookup(@table, :entry) do
      [{:entry, entry}] -> {:ok, entry, freshness(entry, ttl_seconds)}
      _ -> :error
    end
  rescue
    ArgumentError -> :error
  end

  defp freshness(%{generated_at: generated_at}, ttl_seconds) do
    age = System.system_time(:second) - generated_at
    if age >= 0 and age < ttl_seconds, do: :fresh, else: :stale
  end

  defp build_entry(payload) do
    %{
      version: @cache_version,
      generated_at: System.system_time(:second),
      hash: payload_hash(payload),
      payload: payload
    }
  end

  defp payload_hash(payload) do
    payload
    |> :erlang.term_to_binary([:deterministic])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 7)
  end

  defp load_persisted_entry(state) do
    with {:ok, binary} <- File.read(state.cache_path),
         # SQL result maps contain runtime-created atom keys. This app-owned 0600 file is trusted.
         entry <- :erlang.binary_to_term(binary),
         true <- valid_entry?(entry) do
      :ets.insert(@table, {:entry, entry})
    else
      _ -> :ok
    end

    state
  rescue
    _ -> state
  end

  defp valid_entry?(%{
         version: @cache_version,
         generated_at: generated_at,
         hash: hash,
         payload: payload
       }) do
    is_integer(generated_at) and is_binary(hash) and byte_size(hash) == 7 and is_map(payload)
  end

  defp valid_entry?(_entry), do: false

  defp valid_maps_payload?(%{
         popular_maps: popular_maps,
         popularity_chart: %{"labels" => labels},
         map_analytics: %{rows: analytics_rows, class_popularity: class_popularity}
       }) do
    popular_maps != [] and labels != [] and analytics_rows != [] and class_popularity != []
  end

  defp valid_maps_payload?(_payload), do: false

  defp persist_entry(path, entry) do
    directory = Path.dirname(path)
    temporary_path = path <> ".tmp-#{System.unique_integer([:positive])}"

    with :ok <- File.mkdir_p(directory),
         :ok <- File.write(temporary_path, :erlang.term_to_binary(entry, [:compressed])),
         :ok <- File.rename(temporary_path, path) do
      File.chmod(path, 0o600)
    else
      {:error, reason} = error ->
        File.rm(temporary_path)
        Logger.debug("Maps analytics cache write failed: #{inspect(reason)}")
        error
    end
  end

  defp configured_cache_path do
    Application.get_env(
      :kogasa_frontend,
      :mapsdb_cache_path,
      Path.join([System.user_home!(), ".cache", "kogasa_frontend", "maps_page.etf"])
    )
  end

  defp configured_ttl_seconds do
    Application.get_env(:kogasa_frontend, :mapsdb_cache_ttl_seconds, @default_ttl_seconds)
  end

  defp cached_ttl_seconds do
    case :ets.lookup(@table, :ttl_seconds) do
      [{:ttl_seconds, ttl_seconds}] -> ttl_seconds
      _ -> configured_ttl_seconds()
    end
  rescue
    ArgumentError -> configured_ttl_seconds()
  end

  defp monotonic_milliseconds, do: System.monotonic_time(:millisecond)
end
