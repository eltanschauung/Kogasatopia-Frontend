defmodule KogasaFrontend.SteamSession.Pruner do
  @moduledoc false
  use GenServer
  @interval :timer.hours(1)
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  @impl true
  def init(_opts) do
    Process.send_after(self(), :prune, @interval)
    {:ok, nil}
  end

  @impl true
  def handle_info(:prune, state) do
    KogasaFrontend.SteamSession.prune_expired()
    Process.send_after(self(), :prune, @interval)
    {:noreply, state}
  end
end
