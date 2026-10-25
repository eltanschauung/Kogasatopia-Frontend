defmodule KogasaFrontendWeb.SteamLogin do
  @moduledoc false

  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  @steam_openid_url "https://steamcommunity.com/openid/login"
  @openid_ns "http://specs.openid.net/auth/2.0"
  @openid_identifier_select "http://specs.openid.net/auth/2.0/identifier_select"

  def handle(conn, params, opts) do
    action = params["action"] || "login"
    return_to = sanitize_return(params["return"] || Keyword.fetch!(opts, :default_return), opts)

    case action do
      "logout" when conn.method in ["GET", "HEAD"] ->
        confirm_logout(conn, return_to, opts)

      "logout" when conn.method == "POST" ->
        if token = get_session(conn, "wt_chat_client_token") do
          Phoenix.PubSub.broadcast(
            KogasaFrontend.PubSub,
            KogasaFrontend.Chat.Identity.session_topic(token),
            :steam_logout
          )
        end

        conn
        |> configure_session(drop: true)
        |> redirect(to: return_to)

      "logout" ->
        conn
        |> put_resp_header("allow", "GET, HEAD, POST")
        |> send_resp(405, "Method Not Allowed")

      _ ->
        login_or_callback(conn, params, return_to, opts)
    end
  end

  defp confirm_logout(conn, return_to, opts) do
    html = """
    <!doctype html><html lang="en"><head><meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1"><title>Log out</title></head>
    <body><main><h1>Log out</h1><p>Are you sure you want to log out?</p>
    <form method="post" action="#{escape(Keyword.fetch!(opts, :login_path))}">
    <input type="hidden" name="_csrf_token" value="#{escape(Phoenix.Controller.get_csrf_token())}">
    <input type="hidden" name="action" value="logout">
    <input type="hidden" name="return" value="#{escape(return_to)}">
    <button type="submit">Log out</button></form>
    <p><a href="#{escape(return_to)}">Cancel</a></p></main></body></html>
    """

    conn
    |> put_resp_header("cache-control", "private, no-store")
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp escape(value),
    do: value |> to_string() |> Plug.HTML.html_escape_to_iodata() |> IO.iodata_to_binary()

  defp login_or_callback(conn, %{"openid.mode" => "cancel"}, return_to, _opts) do
    conn
    |> delete_session("steam_login_pending")
    |> redirect(to: append_query_flag(return_to, "login", "cancelled"))
  end

  defp login_or_callback(conn, %{"openid.mode" => _mode} = params, return_to, opts) do
    case validate_openid_response(conn, params, return_to, opts) do
      {:ok, steamid} ->
        conn
        |> configure_session(renew: true)
        |> put_session("steamid", steamid)
        |> put_session("steam_verified_id", steamid)
        |> delete_session("steam_login_pending")
        |> redirect(to: return_to)

      {:error, reason} ->
        render_error_page(conn, return_to, reason, opts)
    end
  end

  defp login_or_callback(conn, _params, return_to, opts) do
    pending = %{
      "token" => Base.url_encode64(:crypto.strong_rand_bytes(24), padding: false),
      "return" => return_to,
      "issued_at" => System.system_time(:second)
    }

    conn = put_session(conn, "steam_login_pending", pending)
    redirect(conn, external: build_steam_login_url(conn, return_to, opts))
  end

  defp build_steam_login_url(conn, return_to, opts) do
    return_url = absolute_login_return_url(conn, return_to, opts)
    realm = configured_realm()

    query =
      URI.encode_query(%{
        "openid.ns" => @openid_ns,
        "openid.mode" => "checkid_setup",
        "openid.identity" => @openid_identifier_select,
        "openid.claimed_id" => @openid_identifier_select,
        "openid.return_to" => return_url,
        "openid.realm" => realm
      })

    @steam_openid_url <> "?" <> query
  end

  defp validate_openid_response(conn, params, return_to, opts) do
    openid_fields =
      params
      |> Enum.filter(fn {k, _v} -> String.starts_with?(k, "openid.") end)
      |> Map.new()
      |> Map.put("openid.mode", "check_authentication")

    signed =
      case params["openid.signed"] do
        value when is_binary(value) -> String.split(value, ",")
        _ -> []
      end

    required = ~w(op_endpoint claimed_id identity return_to response_nonce)

    request_options =
      Keyword.merge(Keyword.get(opts, :request_options, []),
        form: openid_fields,
        receive_timeout: 5_000
      )

    with %{"token" => token, "return" => ^return_to, "issued_at" => issued_at} <-
           get_session(conn, "steam_login_pending"),
         true <- is_binary(token) and token == params["state"],
         true <- is_integer(issued_at) and (System.system_time(:second) - issued_at) in 0..600,
         true <- params["openid.mode"] == "id_res" and params["openid.ns"] == @openid_ns,
         true <- params["openid.op_endpoint"] == @steam_openid_url,
         true <- params["openid.identity"] == params["openid.claimed_id"],
         true <- Enum.all?(required, &(&1 in signed)),
         true <- params["openid.return_to"] == absolute_login_return_url(conn, return_to, opts),
         {:ok, response} <- Req.post(@steam_openid_url, request_options),
         true <- response.status in 200..299,
         body when is_binary(body) <- response.body,
         true <- "is_valid:true" in String.split(body, ~r/\r?\n/),
         {:ok, steamid} <- steamid_from_claimed_id(params["openid.claimed_id"]) do
      {:ok, steamid}
    else
      false ->
        {:error, "Steam OpenID validation failed."}

      _ ->
        {:error, "Steam OpenID validation failed."}
    end
  end

  defp steamid_from_claimed_id(claimed_id) when is_binary(claimed_id) do
    case Regex.run(~r|^https://steamcommunity\.com/openid/id/(\d{17})$|, claimed_id) do
      [_full, steamid] -> {:ok, steamid}
      _ -> {:error, :invalid_claimed_id}
    end
  end

  defp steamid_from_claimed_id(_), do: {:error, :missing_claimed_id}

  defp absolute_login_return_url(conn, return_to, opts) do
    state = get_in(get_session(conn), ["steam_login_pending", "token"]) || ""

    configured_realm() <>
      Keyword.fetch!(opts, :login_path) <>
      "?" <> URI.encode_query(%{"return" => return_to, "state" => state})
  end

  defp configured_realm do
    url_config = Application.get_env(:kogasa_frontend, KogasaFrontendWeb.Endpoint, [])[:url] || []
    scheme = Keyword.get(url_config, :scheme, "https")
    host = Keyword.get(url_config, :host, System.get_env("PHX_HOST") || "kogasa.tf")
    port = Keyword.get(url_config, :port)

    port_part =
      case {scheme, port} do
        {"https", port} when port in [nil, 443] -> ""
        {"http", port} when port in [nil, 80] -> ""
        {_scheme, nil} -> ""
        {_scheme, port} -> ":#{port}"
      end

    scheme <> "://" <> host <> port_part
  end

  defp append_query_flag(path, key, value) do
    uri = URI.parse(path)
    existing = if uri.query, do: URI.decode_query(uri.query), else: %{}
    %{uri | query: URI.encode_query(Map.put(existing, key, value))} |> URI.to_string()
  end

  defp render_error_page(conn, return_to, error_msg, opts) do
    esc = &escape/1

    steamid = get_session(conn, "steamid")
    title = Keyword.get(opts, :title, "Steam Login")
    return_label = Keyword.get(opts, :return_label, "page")

    session_detail =
      Keyword.get(opts, :session_detail, fn _steamid, _esc -> "" end).(steamid, esc)

    html = """
    <!doctype html>
    <html lang="en"><head>
      <meta charset="utf-8" />
      <meta name="viewport" content="width=device-width, initial-scale=1" />
      <title>#{esc.(title)}</title>
      <style>
        body { font-family: sans-serif; background:#0f1118; color:#eee; margin:0; padding:2rem; }
        .card { max-width:760px; margin:0 auto; background:#171b26; border:1px solid #303749; padding:1rem 1.25rem; }
        a { display:inline-block; margin-top:.6rem; padding:.5rem .9rem; border:1px solid #51607d; background:#36455f; color:#fff; text-decoration:none; }
        .muted { color:#aab2c5; } .err { color:#ff9b9b; } code { background:#0b0f18; padding:.1rem .3rem; }
      </style>
    </head><body><div class="card">
      <h1>Steam Login Error</h1>
      <p class="err">#{esc.(error_msg)}</p>
      <p class="muted">Current session steamid: <code>#{esc.(steamid || "none")}</code>#{session_detail}</p>
      <p><a href="#{Keyword.fetch!(opts, :login_path)}?return=#{URI.encode(return_to)}">Try Steam login again</a></p>
      <p><a href="#{esc.(return_to)}">Return to #{esc.(return_label)}</a></p>
    </div></body></html>
    """

    conn
    |> put_resp_content_type("text/html")
    |> send_resp(200, html)
  end

  defp sanitize_return(path, opts) do
    if is_binary(path) and String.starts_with?(path, "/") and
         not String.starts_with?(path, "//") and not String.match?(path, ~r/[\\\\\x00-\x20\x7f]/) do
      path
    else
      Keyword.fetch!(opts, :default_return)
    end
  end
end
