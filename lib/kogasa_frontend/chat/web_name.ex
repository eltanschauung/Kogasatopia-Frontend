defmodule KogasaFrontend.Chat.WebName do
  use Ecto.Schema

  @primary_key false
  schema "whaletracker_webnames" do
    field :name, :string
    field :color, :string
  end
end
