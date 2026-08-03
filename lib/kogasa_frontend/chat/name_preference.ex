defmodule KogasaFrontend.Chat.NamePreference do
  @moduledoc false

  use Ecto.Schema

  @primary_key false
  schema "filters_namecolors" do
    field :steamid, :string
    field :color, :string
    field :pattern, :string
  end
end
