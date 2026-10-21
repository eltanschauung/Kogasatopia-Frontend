defmodule KogasaFrontend.WeaponsRootCache do
  @moduledoc false
  use GenServer

  # Only the current public parse per path is retained; callers cannot grow this unboundedly.
  @max_paths 8

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, name: Keyword.get(opts, :name, __MODULE__))
  end

  def load(path, opts \\ []) do
    server = Keyword.get(opts, :server, __MODULE__)
    parser = Keyword.get(opts, :parser, &KogasaFrontend.ValveKeyValues.parse/1)
    path = Path.expand(path)

    case File.read(path) do
      {:ok, bytes} ->
        digest = :crypto.hash(:sha256, bytes)

        case GenServer.call(server, {:load, path, digest, bytes, parser}) do
          {:ok, root} -> root
          {:raise, error, stack} -> reraise error, stack
        end

      _ ->
        GenServer.call(server, {:invalidate, path})
        []
    end
  end

  @impl true
  def init(_), do: {:ok, %{entries: %{}, order: []}}

  @impl true
  def handle_call({:invalidate, path}, _from, state) do
    {:reply, :ok,
     %{state | entries: Map.delete(state.entries, path), order: List.delete(state.order, path)}}
  end

  def handle_call({:load, path, digest, bytes, parser}, _from, state) do
    case state.entries[path] do
      {^digest, root} ->
        {:reply, {:ok, root}, state}

      _ ->
        try do
          root = parser.(bytes)
          order = [path | List.delete(state.order, path)] |> Enum.take(@max_paths)
          entries = state.entries |> Map.put(path, {digest, root}) |> Map.take(order)
          {:reply, {:ok, root}, %{state | entries: entries, order: order}}
        rescue
          error -> {:reply, {:raise, error, __STACKTRACE__}, state}
        end
    end
  end
end
