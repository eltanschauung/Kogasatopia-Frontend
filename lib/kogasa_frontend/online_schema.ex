defmodule KogasaFrontend.OnlineSchema do
  @moduledoc false
  use GenServer

  @tables ~w(whaletracker_online whaletracker_servers)
  @ttl_ms 60_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def invalidate(table, server \\ __MODULE__) when table in @tables do
    cache_call(server, {:invalidate, table})
  end

  # Only schema metadata is cached. The callback always queries live rows.
  def with_columns(table, callback, opts \\ []) when table in @tables do
    server = Keyword.get(opts, :server, __MODULE__)
    query = Keyword.get(opts, :query, &KogasaFrontend.Repo.query/2)

    with {:ok, columns} <- cache_call(server, {:columns, table, query}) do
      case callback.(columns) do
        {:error, error} = result ->
          if schema_error?(error) do
            with :ok <- invalidate(table, server),
                 {:ok, columns} <- cache_call(server, {:columns, table, query}) do
              callback.(columns)
            end
          else
            result
          end

        result ->
          result
      end
    end
  end

  defp schema_error?(%{mysql: %{code: code}}), do: code in [1054, 1146]
  defp schema_error?(_), do: false

  # Repo bounds the metadata query itself. Do not impose a shorter call timeout
  # that exits the request while a healthy worker is still waiting on the DB.
  defp cache_call(server, request) do
    GenServer.call(server, request, :infinity)
  catch
    :exit, reason -> {:error, {:schema_cache_unavailable, reason}}
  end

  defp query_columns(query, table) do
    query.("SHOW COLUMNS FROM #{table}", [])
  rescue
    error -> {:error, {:schema_query_exception, error.__struct__}}
  catch
    :exit, reason -> {:error, {:schema_query_exit, reason}}
    :throw, reason -> {:error, {:schema_query_throw, reason}}
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       entries: %{},
       clock: Keyword.get(opts, :clock, fn -> System.monotonic_time(:millisecond) end)
     }}
  end

  @impl true
  def handle_call({:invalidate, table}, _from, state) do
    {:reply, :ok, %{state | entries: Map.delete(state.entries, table)}}
  end

  def handle_call({:columns, table, query}, _from, state) when table in @tables do
    now = state.clock.()

    case state.entries[table] do
      {columns, expires} when expires > now ->
        {:reply, {:ok, columns}, state}

      _ ->
        case query_columns(query, table) do
          {:ok, %{rows: [_ | _] = rows}} ->
            columns = MapSet.new(rows, fn [field | _] -> to_string(field) end)
            entries = Map.put(state.entries, table, {columns, state.clock.() + @ttl_ms})
            {:reply, {:ok, columns}, %{state | entries: entries}}

          {:ok, _} ->
            {:reply, {:error, :empty_schema},
             %{state | entries: Map.delete(state.entries, table)}}

          error ->
            {:reply, error, %{state | entries: Map.delete(state.entries, table)}}
        end
    end
  end
end
