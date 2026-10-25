defmodule KogasaFrontend.SteamSession.Record do
  @moduledoc false
  use Ecto.Schema
  @primary_key {:token_hash, :string, autogenerate: false}
  schema "whaletracker_steam_sessions" do
    field :steamid, :string
    field :issued_at, :integer
    field :expires_at, :integer
  end
end
