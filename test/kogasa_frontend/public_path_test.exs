defmodule KogasaFrontend.PublicPathTest do
  use ExUnit.Case, async: false
  alias KogasaFrontend.{PublicPath, LegacySite, FastdlSite}
  alias KogasaFrontendWeb.Plugs.{LegacyStatic, FastdlHost, SafeStatic}

  setup do
    dir = Path.join(System.tmp_dir!(), "published-#{System.unique_integer([:positive])}")
    root = Path.join(dir, "public")
    File.mkdir_p!(Path.join(root, "folder"))
    File.write!(Path.join(root, "public.txt"), "public content")
    outside = Path.join(dir, "outside.txt")
    File.write!(outside, "synthetic private content")
    File.ln_s!(outside, Path.join(root, "leaf.txt"))
    File.ln_s!(dir, Path.join(root, "linked"))
    File.ln_s!(outside, Path.join(root, "folder/index.html"))

    previous =
      for key <- [:legacy_static_root, :fastdl_root],
          into: %{},
          do: {key, Application.fetch_env(:kogasa_frontend, key)}

    for key <- Map.keys(previous), do: Application.put_env(:kogasa_frontend, key, root)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:kogasa_frontend, key, value)
        {key, :error} -> Application.delete_env(:kogasa_frontend, key)
      end)

      File.rm_rf!(dir)
    end)

    %{root: root, dir: dir, outside: outside}
  end

  test "all publishers reject leaf and intermediate symlinks and traversal", %{root: root} do
    for path <- [
          "/leaf.txt",
          "/linked/outside.txt",
          "/../outside.txt",
          "/bad\\name",
          "/bad\0name"
        ] do
      assert PublicPath.resolve(root, path) == :error
      assert LegacySite.safe_resolve(path) == :error
      assert FastdlSite.safe_resolve(path) == :error
    end

    assert FastdlSite.safe_resolve("/%2e%2e/outside.txt") == :error
    assert LegacySite.safe_resolve("/%2e%2e/outside.txt") == :error
    assert {:ok, _} = PublicPath.resolve(root, "public.txt")
  end

  test "legacy directory indexes cannot bypass leaf validation" do
    conn = Plug.Test.conn(:get, "/folder/") |> LegacyStatic.call([])
    refute conn.halted
    refute conn.resp_body == "synthetic private content"
  end

  test "FastDL refuses linked files and hides their directory entries" do
    conn = Plug.Test.conn(:get, "http://fastdl.kogasa.tf/leaf.txt") |> FastdlHost.call([])
    assert conn.status == 404
    listing = Plug.Test.conn(:get, "http://fastdl.kogasa.tf/") |> FastdlHost.call([])
    assert listing.status == 200
    refute IO.iodata_to_binary(listing.resp_body) =~ "leaf.txt"
    refute IO.iodata_to_binary(listing.resp_body) =~ "linked/"
    normal = Plug.Test.conn(:get, "http://fastdl.kogasa.tf/public.txt") |> FastdlHost.call([])
    assert normal.status == 200
    assert normal.resp_body == "public content"
  end

  test "ordinary and precompressed Plug static files share confinement", %{
    root: root,
    outside: outside
  } do
    opts = SafeStatic.init(at: "/assets", from: root, gzip: true)
    normal = Plug.Test.conn(:get, "/assets/public.txt") |> SafeStatic.call(opts)
    assert normal.status == 200
    linked = Plug.Test.conn(:get, "/assets/leaf.txt") |> SafeStatic.call(opts)
    assert linked.status == 404
    File.ln_s!(outside, Path.join(root, "public.txt.gz"))

    compressed =
      Plug.Test.conn(:get, "/assets/public.txt")
      |> Plug.Conn.put_req_header("accept-encoding", "gzip")
      |> SafeStatic.call(opts)

    assert compressed.status == 404
    refute compressed.resp_body == "synthetic private content"
  end
end
