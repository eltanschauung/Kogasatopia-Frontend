defmodule KogasaFrontend.WeaponPanel do
  @moduledoc false

  alias KogasaFrontend.Repo

  @session_token ~r/\A[0-9a-f]{32}\z/i
  @action_id ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i

  def fetch_session(token, expected_class_id) when is_integer(expected_class_id) do
    with true <- valid_session_token?(token),
         {:ok, %{rows: [[steamid64, ^expected_class_id, equipped_uids]]}} <-
           Repo.query(
             "SELECT steamid64, class_index, equipped_uids FROM weapons_web_sessions " <>
               "WHERE token = ? AND expires_at >= ? LIMIT 1",
             [token, now()]
           ) do
      {:ok,
       %{
         token: token,
         steamid64: steamid64,
         class_id: expected_class_id,
         equipped_uids: split_loadout(equipped_uids)
       }}
    else
      _ -> :error
    end
  end

  def fetch_session(_token, _expected_class_id), do: :error

  def enqueue_action(token, weapon_uid, desired_equipped)
      when is_binary(weapon_uid) and is_boolean(desired_equipped) do
    action_id = Ecto.UUID.generate()

    with true <- valid_session_token?(token),
         true <- valid_weapon_uid?(weapon_uid),
         {:ok, %{num_rows: 1}} <-
           Repo.query(
             "INSERT INTO weapons_web_actions " <>
               "(action_id, session_token, weapon_uid, desired_equipped, status, " <>
               "result_loadout, error_code, created_at, processed_at) " <>
               "SELECT ?, token, ?, ?, 'pending', '', '', ?, 0 FROM weapons_web_sessions " <>
               "WHERE token = ? AND expires_at >= ?",
             [
               action_id,
               weapon_uid,
               if(desired_equipped, do: 1, else: 0),
               now(),
               token,
               now()
             ]
           ) do
      {:ok, action_id}
    else
      {:ok, %{num_rows: 0}} -> {:error, :expired}
      false -> {:error, :invalid}
      _ -> {:error, :unavailable}
    end
  end

  def enqueue_action(_token, _weapon_uid, _desired_equipped), do: {:error, :invalid}

  def fetch_action(token, id) do
    with true <- valid_session_token?(token),
         true <- is_binary(id) and Regex.match?(@action_id, id),
         {:ok, %{rows: [[status, result_loadout, error_code]]}} <-
           Repo.query(
             "SELECT status, result_loadout, error_code FROM weapons_web_actions " <>
               "WHERE action_id = ? AND session_token = ? LIMIT 1",
             [id, token]
           ) do
      {:ok,
       %{
         status: status,
         equipped_uids: result_loadout |> split_loadout() |> MapSet.to_list(),
         error: error_code
       }}
    else
      _ -> :error
    end
  end

  defp valid_session_token?(token),
    do: is_binary(token) and Regex.match?(@session_token, token)

  defp valid_weapon_uid?(uid) do
    byte_size(uid) in 1..64 and not String.contains?(uid, ["\0", "|", "\r", "\n"])
  end

  defp split_loadout(value) when is_binary(value) do
    value
    |> String.split("|", trim: true)
    |> MapSet.new()
  end

  defp split_loadout(_value), do: MapSet.new()
  defp now, do: System.system_time(:second)
end
