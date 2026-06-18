defmodule KogasaFrontend.MapsDb.MapMeta do
  use Ecto.Schema

  @primary_key {:map_name, :string, autogenerate: false}
  @derive {Jason.Encoder, only: [:map_name, :category, :sub_category, :popularity]}
  schema "mapsdb" do
    field :category, :string, default: ""
    field :sub_category, :string, default: ""
    field :popularity, :integer, default: 0
  end
end
