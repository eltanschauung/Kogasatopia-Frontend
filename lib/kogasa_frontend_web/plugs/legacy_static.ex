defmodule KogasaFrontendWeb.Plugs.LegacyStatic do
  @moduledoc false
  import Plug.Conn

  alias KogasaFrontend.LegacySite

  @allowed_exts ~w(
    .html .htm .css .js .png .jpg .jpeg .gif .ico .svg .txt .json
    .mp3 .wav .woff .woff2 .ttf .otf .webp .vpk
  )
  def init(opts), do: opts

  def call(%Plug.Conn{method: method} = conn, _opts) when method not in ["GET", "HEAD"], do: conn

  def call(conn, _opts) do
    path = conn.request_path

    cond do
      path in ["/", "/index.php", "/index.html", "/info", "/info/", "/info/index.html"] ->
        conn

      true ->
        maybe_serve(conn, path)
    end
  end

  defp maybe_serve(conn, request_path) do
    with {:ok, resolved} <- LegacySite.safe_resolve(request_path),
         {:ok, picked} <- pick_file(resolved, request_path) do
      case picked do
        {:redirect_dir, location} ->
          conn
          |> maybe_put_cache_headers(request_path)
          |> put_resp_header("location", location)
          |> send_resp(302, "")
          |> halt()

        {:file, file} ->
          if allowed_file?(file) do
            conn
            |> maybe_put_cache_headers(request_path)
            |> put_resp_content_type(content_type(file))
            |> send_file(conn.status || 200, file)
            |> halt()
          else
            conn
          end

        _ ->
          conn
      end
    else
      _ -> conn
    end
  end

  defp pick_file(resolved, request_path) do
    cond do
      File.regular?(resolved) ->
        {:ok, {:file, resolved}}

      File.dir?(resolved) and not String.ends_with?(request_path, "/") and
          has_index_html?(resolved) ->
        {:ok, {:redirect_dir, request_path <> "/"}}

      File.dir?(resolved) and File.regular?(Path.join(resolved, "index.html")) ->
        {:ok, {:file, Path.join(resolved, "index.html")}}

      File.dir?(resolved) and File.regular?(Path.join(resolved, "index.htm")) ->
        {:ok, {:file, Path.join(resolved, "index.htm")}}

      true ->
        :error
    end
  end

  defp has_index_html?(resolved) do
    File.regular?(Path.join(resolved, "index.html")) or
      File.regular?(Path.join(resolved, "index.htm"))
  end

  defp allowed_file?(file) do
    ext = file |> Path.extname() |> String.downcase()
    ext in @allowed_exts
  end

  defp content_type(file) do
    case MIME.from_path(file) do
      "" -> "application/octet-stream"
      type -> type
    end
  end

  defp maybe_put_cache_headers(conn, request_path) do
    normalized =
      if String.starts_with?(request_path, "/") do
        request_path
      else
        "/" <> request_path
      end

    cond do
      info_path?(normalized) and info_image_path?(normalized) ->
        put_info_image_cache_headers(conn)

      info_path?(normalized) ->
        put_info_asset_cache_headers(conn)

      MapSet.member?(LegacySite.homepage_immutable_images(), normalized) or
        MapSet.member?(LegacySite.homepage_immutable_assets(), normalized) or
          hat_background_path?(normalized) ->
        put_forever_cache_headers(conn)

      true ->
        conn
    end
  end

  defp info_path?(path), do: path == "/info" or String.starts_with?(path, "/info/")

  defp info_image_path?(path) do
    ext = path |> Path.extname() |> String.downcase()
    ext in ~w(.png .jpg .jpeg .gif .ico .svg .webp)
  end

  defp hat_background_path?(path), do: path == "/hat.jpg"

  defp put_info_image_cache_headers(conn) do
    put_resp_header(conn, "cache-control", "public, max-age=2592000")
  end

  defp put_info_asset_cache_headers(conn) do
    put_resp_header(conn, "cache-control", "public, max-age=3600")
  end

  defp put_forever_cache_headers(conn) do
    put_resp_header(conn, "cache-control", "public, max-age=31536000, immutable")
  end
end
