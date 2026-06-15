defmodule WhaleChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      WhaleChatWeb.Telemetry,
      WhaleChat.Repo,
      WhaleChat.Chat.RateLimiter,
      WhaleChat.AccessLog,
      {DNSCluster, query: Application.get_env(:kogasa_frontend, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: WhaleChat.PubSub},
      # Start a worker by calling: WhaleChat.Worker.start_link(arg)
      # {WhaleChat.Worker, arg},
      # Start to serve requests, typically the last entry
      WhaleChatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WhaleChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WhaleChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
