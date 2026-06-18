defmodule KogasaFrontend.AccessLog do
  @moduledoc false

  use GenServer

  require Logger

  @name __MODULE__

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: @name)
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

    io =
      case open_log(path) do
        {:ok, io} -> io
        {:error, _reason} -> nil
      end

    {:ok, %{path: path, io: io}}
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

  defp reopen(%{io: nil} = state), do: state

  defp reopen(%{path: path, io: io} = state) do
    File.close(io)

    case open_log(path) do
      {:ok, new_io} -> %{state | io: new_io}
      {:error, _reason} -> %{state | io: nil}
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
