defmodule KogasaFrontend.SteamSession do
  @moduledoc false

  # Old sessions could be created by the retired raw-SteamID login shortcut.
  # Only the server-verified OpenID callback may issue this matching marker.
  def steamid(%{"steamid" => id, "steam_verified_id" => verified})
      when is_binary(id) and id == verified do
    if Regex.match?(~r/^\d{17}$/, id), do: id
  end

  def steamid(_), do: nil
end
