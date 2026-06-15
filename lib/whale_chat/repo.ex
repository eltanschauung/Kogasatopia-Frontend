defmodule WhaleChat.Repo do
  use Ecto.Repo,
    otp_app: :kogasa_frontend,
    adapter: Ecto.Adapters.MyXQL
end
