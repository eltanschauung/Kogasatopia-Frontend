defmodule KogasaFrontend.SteamSession do
  @moduledoc """
  Persistent per-device Steam authentication. Cookies hold random handles; the
  database stores only SHA-256 digests. Marker-only cookies intentionally become
  anonymous without rotating signing secrets or changing user/game records.
  """
  import Ecto.Query
  alias KogasaFrontend.Repo
  alias KogasaFrontend.SteamSession.Record
  @default_ttl 30 * 24 * 60 * 60
  @handle_pattern ~r/\A[A-Za-z0-9_-]{43}\z/
  @steamid_pattern ~r/\A[0-9]{17}\z/

  def steamid(%{"steamid" => id, "steam_session_id" => handle}) do
    if valid?(id, handle), do: id
  end

  def steamid(_), do: nil

  def valid?(id, handle) when is_binary(id) and is_binary(handle) do
    if Regex.match?(@steamid_pattern, id) and valid_handle?(handle) do
      hash = digest(handle)
      now = System.system_time(:second)

      Repo.exists?(
        from s in Record,
          where:
            s.token_hash == ^hash and s.steamid == ^id and
              s.issued_at <= ^now and s.expires_at > ^now
      )
    else
      false
    end
  rescue
    _ -> false
  catch
    :exit, _ -> false
  end

  def valid?(_, _), do: false

  # Called only after provider validation. Replacement and revocation are atomic.
  def issue(id, previous_session \\ %{})

  def issue(id, previous_session) when is_binary(id) do
    if Regex.match?(@steamid_pattern, id) do
      handle = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      now = System.system_time(:second)

      case Repo.transaction(fn ->
             revoke_record(previous_session)

             Repo.insert!(%Record{
               token_hash: digest(handle),
               steamid: id,
               issued_at: now,
               expires_at: now + ttl()
             })

             handle
           end) do
        {:ok, handle} -> {:ok, handle}
        _ -> {:error, :unavailable}
      end
    else
      {:error, :invalid}
    end
  rescue
    _ -> {:error, :unavailable}
  catch
    :exit, _ -> {:error, :unavailable}
  end

  def issue(_, _), do: {:error, :invalid}

  def revoke(session) do
    revoke_record(session)
    :ok
  rescue
    _ -> {:error, :unavailable}
  catch
    :exit, _ -> {:error, :unavailable}
  end

  def prune_expired do
    now = System.system_time(:second)
    {count, _} = Repo.delete_all(from s in Record, where: s.expires_at <= ^now)
    {:ok, count}
  rescue
    _ -> {:error, :unavailable}
  catch
    :exit, _ -> {:error, :unavailable}
  end

  defp revoke_record(%{"steam_session_id" => handle}) when is_binary(handle) do
    if valid_handle?(handle) do
      hash = digest(handle)
      Repo.delete_all(from s in Record, where: s.token_hash == ^hash)
    end

    :ok
  end

  defp revoke_record(_), do: :ok
  defp valid_handle?(handle), do: Regex.match?(@handle_pattern, handle)
  defp digest(handle), do: :crypto.hash(:sha256, handle) |> Base.encode16(case: :lower)

  defp ttl do
    case Application.get_env(:kogasa_frontend, :steam_session_ttl_seconds, @default_ttl) do
      value when is_integer(value) -> value |> max(300) |> min(90 * 24 * 60 * 60)
      _ -> @default_ttl
    end
  end
end
