defmodule WhaleChatWeb.Plugs.FastdlHost do
  @moduledoc false
  import Plug.Conn

  alias WhaleChat.FastdlSite

  def init(opts), do: opts

  def call(%Plug.Conn{host: host} = conn, _opts) do
    cond do
      not FastdlSite.fastdl_host?(host) ->
        conn

      conn.method not in ["GET", "HEAD"] ->
        conn
        |> put_no_cache_headers()
        |> send_resp(405, "Method Not Allowed")
        |> halt()

      true ->
        serve(conn)
    end
  end

  defp serve(conn) do
    request_path = conn.request_path

    with {:ok, resolved} <- FastdlSite.safe_resolve(request_path),
         {:ok, picked} <- pick_path(resolved) do
      case picked do
        {:redirect, location} ->
          conn
          |> put_no_cache_headers()
          |> put_resp_header("location", location)
          |> send_resp(301, "")
          |> halt()

        {:file, file} ->
          send_fastdl_file(conn, file)

        {:listing, dir} ->
          send_directory_listing(conn, request_path, dir)
      end
    else
      _ ->
        conn
        |> put_no_cache_headers()
        |> send_resp(404, "Not Found")
        |> halt()
    end
  end

  defp pick_path(resolved) do
    index_file = existing_index_file(resolved)

    cond do
      File.regular?(resolved) ->
        {:ok, {:file, resolved}}

      File.dir?(resolved) and is_binary(index_file) ->
        {:ok, {:file, index_file}}

      File.dir?(resolved) ->
        {:ok, {:listing, resolved}}

      true ->
        :error
    end
  end

  defp existing_index_file(dir) do
    Enum.find(
      [Path.join(dir, "index.html"), Path.join(dir, "index.htm")],
      &File.regular?/1
    )
  end

  defp send_fastdl_file(conn, file) do
    {:ok, stat} = File.stat(file)

    conn =
      conn
      |> put_no_cache_headers()
      |> put_resp_content_type(content_type(file))
      |> put_resp_header("content-length", Integer.to_string(stat.size))

    if conn.method == "HEAD" do
      conn
      |> send_resp(conn.status || 200, "")
      |> halt()
    else
      conn
      |> send_file(conn.status || 200, file)
      |> halt()
    end
  end

  defp send_directory_listing(conn, request_path, dir) do
    html = render_directory_listing(request_path, dir)

    conn
    |> put_no_cache_headers()
    |> put_resp_content_type("text/html")
    |> send_resp(200, if(conn.method == "HEAD", do: "", else: html))
    |> halt()
  end

  defp render_directory_listing(request_path, dir) do
    entries =
      dir
      |> File.ls!()
      |> Enum.sort(:asc)
      |> Enum.flat_map(&directory_entry(request_path, dir, &1))

    rows =
      Enum.map(entries, fn %{href: href, name: name, size: size, modified: modified} ->
        [
          "<tr><td><a href=\"",
          Plug.HTML.html_escape_to_iodata(href),
          "\">",
          Plug.HTML.html_escape_to_iodata(name),
          "</a></td><td>",
          Plug.HTML.html_escape_to_iodata(modified),
          "</td><td>",
          Plug.HTML.html_escape_to_iodata(size),
          "</td></tr>"
        ]
      end)

    [
      "<!doctype html><html><head><meta charset=\"utf-8\"><title>Index of ",
      Plug.HTML.html_escape_to_iodata(request_path),
      "</title></head><body><h1>Index of ",
      Plug.HTML.html_escape_to_iodata(request_path),
      "</h1><table><tr><th>Name</th><th>Last modified (ET)</th><th>Size</th></tr>",
      parent_row(request_path),
      rows,
      "</table></body></html>"
    ]
  end

  defp directory_entry(request_path, dir, name) do
    path = Path.join(dir, name)

    case File.stat(path) do
      {:ok, stat} ->
        directory? = stat.type == :directory
        display_name = if(directory?, do: name <> "/", else: name)

        href =
          request_path
          |> ensure_trailing_slash()
          |> Kernel.<>(URI.encode(display_name))

        [
          %{
            href: href,
            name: display_name,
            modified: format_mtime(stat.mtime),
            size: if(directory?, do: "-", else: format_size(stat.size))
          }
        ]

      {:error, _reason} ->
        []
    end
  end

  defp parent_row("/"), do: ""

  defp parent_row(request_path) do
    parent =
      request_path
      |> String.trim_trailing("/")
      |> Path.dirname()
      |> ensure_trailing_slash()

    [
      "<tr><td><a href=\"",
      Plug.HTML.html_escape_to_iodata(parent),
      "\">../</a></td><td>-</td><td>-</td></tr>"
    ]
  end

  defp ensure_trailing_slash(path) do
    if String.ends_with?(path, "/"), do: path, else: path <> "/"
  end

  defp format_mtime({{year, month, day}, {hour, minute, _second}}) do
    :io_lib.format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B ET", [year, month, day, hour, minute])
    |> IO.iodata_to_binary()
  end

  defp format_size(size) when size >= 1024 * 1024 do
    :io_lib.format("~.1fM", [size / (1024 * 1024)])
    |> IO.iodata_to_binary()
  end

  defp format_size(size) when size >= 1024 do
    :io_lib.format("~.1fK", [size / 1024])
    |> IO.iodata_to_binary()
  end

  defp format_size(size), do: Integer.to_string(size)

  defp content_type(file) do
    case MIME.from_path(file) do
      "" -> "application/octet-stream"
      type -> type
    end
  end

  defp put_no_cache_headers(conn) do
    conn
    |> put_resp_header("cache-control", "no-store, no-cache, must-revalidate, max-age=0")
    |> put_resp_header("pragma", "no-cache")
    |> put_resp_header("expires", "0")
    |> put_resp_header("surrogate-control", "no-store")
  end
end
