defmodule KogasaFrontendWeb.Plugs.SafeStatic do
  @moduledoc false
  import Plug.Conn
  alias KogasaFrontend.PublicPath

  def init(opts), do: {opts, Plug.Static.init(opts)}

  def call(conn, {opts, static}) when conn.method in ["GET", "HEAD"] do
    at = opts |> Keyword.fetch!(:at) |> Plug.Router.Utils.split()
    {prefix, segments} = Enum.split(conn.path_info, length(at))
    only = Keyword.get(opts, :only, [])

    if prefix == at and segments != [] and (only == [] or hd(segments) in only) do
      root = root(Keyword.fetch!(opts, :from))
      relative = segments |> Enum.map(&URI.decode/1) |> Enum.join("/")

      extensions =
        [""] ++
          if(Keyword.get(opts, :gzip, false), do: [".gz"], else: []) ++
          if(Keyword.get(opts, :brotli, false), do: [".br"], else: [])

      if Enum.all?(extensions, &match?({:ok, _}, PublicPath.resolve(root, relative <> &1))) do
        Plug.Static.call(conn, static)
      else
        conn |> send_resp(404, "Not Found") |> halt()
      end
    else
      Plug.Static.call(conn, static)
    end
  end

  def call(conn, {_opts, static}), do: Plug.Static.call(conn, static)

  defp root(app) when is_atom(app), do: Application.app_dir(app, "priv/static")
  defp root(path) when is_binary(path), do: path
end
