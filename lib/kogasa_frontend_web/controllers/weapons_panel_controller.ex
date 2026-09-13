defmodule KogasaFrontendWeb.WeaponsPanelController do
  use KogasaFrontendWeb, :controller

  alias KogasaFrontend.WeaponPanel

  def create_action(conn, %{
        "token" => token,
        "weapon_uid" => weapon_uid,
        "equipped" => equipped
      }) do
    case WeaponPanel.enqueue_action(token, weapon_uid, equipped) do
      {:ok, action_id} ->
        conn
        |> no_store()
        |> put_status(:accepted)
        |> json(%{ok: true, action_id: action_id})

      {:error, :expired} ->
        error(conn, :gone, "expired")

      {:error, :invalid} ->
        error(conn, :bad_request, "invalid")

      {:error, :unavailable} ->
        error(conn, :service_unavailable, "unavailable")
    end
  end

  def create_action(conn, _params), do: error(conn, :bad_request, "invalid")

  def show_action(conn, %{"token" => token, "action_id" => action_id}) do
    case WeaponPanel.fetch_action(token, action_id) do
      {:ok, action} ->
        conn
        |> no_store()
        |> json(Map.put(action, :ok, true))

      :error ->
        error(conn, :not_found, "not_found")
    end
  end

  defp error(conn, status, code) do
    conn
    |> no_store()
    |> put_status(status)
    |> json(%{ok: false, error: code})
  end

  defp no_store(conn), do: put_resp_header(conn, "cache-control", "no-store")
end
