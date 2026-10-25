defmodule KogasaFrontend.Repo.Migrations.CreateSteamSessions do
  use Ecto.Migration

  def change do
    create table(:whaletracker_steam_sessions, primary_key: false) do
      add :token_hash, :string, size: 64, primary_key: true
      add :steamid, :string, size: 17, null: false
      add :issued_at, :bigint, null: false
      add :expires_at, :bigint, null: false
    end

    create index(:whaletracker_steam_sessions, [:expires_at])
  end
end
