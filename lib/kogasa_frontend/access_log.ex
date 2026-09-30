defmodule KogasaFrontend.AccessLog do
  @moduledoc false

  use GenServer

  require Logger

  @name __MODULE__
  @clear_interval 7 * 24 * 60 * 60
  @check_interval :timer.hours(1)

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, @name))
  end

  def write(line) when is_binary(line) do
    case Process.whereis(@name) do
      nil -> :ok
      _pid -> GenServer.cast(@name, {:write, line})
    end
  end

  @impl true
  def init(opts) do
    path = Keyword.get(opts, :path) || Application.fetch_env!(:kogasa_frontend, :access_log_path)
    path = Path.expand(path)

    marker = path <> ".last_clear"
    state = %{path: path, io: nil, marker: marker, last_clear: read_last_clear(marker)}
    state = state |> clear_if_due() |> reopen()
    Process.send_after(self(), :clear_if_due, @check_interval)
    {:ok, state}
  end

  @impl true
  def handle_info(:clear_if_due, state) do
    state = clear_if_due(state)
    Process.send_after(self(), :clear_if_due, @check_interval)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:write, line}, %{io: nil} = state) do
    case open_log(state.path) do
      {:ok, io} ->
        handle_cast({:write, line}, %{state | io: io})

      {:error, _reason} ->
        {:noreply, state}
    end
  end

  def handle_cast({:write, line}, %{io: io} = state) do
    case IO.write(io, line) do
      :ok ->
        {:noreply, state}

      {:error, reason} ->
        Logger.error("failed to write access log: #{inspect(reason)}")
        {:noreply, reopen(state)}
    end
  rescue
    error ->
      Logger.error("failed to write access log: #{Exception.message(error)}")
      {:noreply, reopen(state)}
  end

  @impl true
  def terminate(_reason, %{io: nil}), do: :ok

  def terminate(_reason, %{io: io}) do
    File.close(io)
  end

  defp reopen(%{path: path, io: io} = state) do
    if io, do: File.close(io)

    case open_log(path) do
      {:ok, new_io} -> %{state | io: new_io}
      {:error, _reason} -> %{state | io: nil}
    end
  end

  defp read_last_clear(marker) do
    with {:ok, value} <- File.read(marker),
         {timestamp, ""} when timestamp > 0 <- Integer.parse(String.trim(value)) do
      timestamp
    else
      _ -> 0
    end
  end

  defp clear_if_due(state) do
    now = System.system_time(:second)

    if now - state.last_clear >= @clear_interval do
      # The same GenServer owns writes and truncation; restarts retain the cadence.
      if state.io, do: File.close(state.io)
      state = %{state | io: nil}
      File.mkdir_p!(Path.dirname(state.path))

      case File.write(state.path, "") do
        :ok ->
          case File.write(state.marker, Integer.to_string(now)) do
            :ok ->
              :ok

            {:error, reason} ->
              Logger.error("failed to persist access log clearing: #{inspect(reason)}")
          end

          Logger.info("cleared weekly access log #{state.path}")
          reopen(%{state | last_clear: now})

        {:error, reason} ->
          Logger.error("failed to clear access log #{state.path}: #{inspect(reason)}")
          reopen(state)
      end
    else
      state
    end
  end

  defp open_log(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p!()

    case File.open(path, [:append, :utf8]) do
      {:ok, io} ->
        {:ok, io}

      {:error, reason} ->
        Logger.error("failed to open access log #{path}: #{inspect(reason)}")
        {:error, reason}
    end
  end
end
