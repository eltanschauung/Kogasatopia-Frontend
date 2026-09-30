defmodule KogasaFrontend.DemoDownloadsTest do
  use ExUnit.Case, async: false

  alias KogasaFrontend.DemoDownloads
  alias KogasaFrontendWeb.StatsFragments

  setup do
    root = Path.join(System.tmp_dir!(), "demo-downloads-#{System.unique_integer([:positive])}")
    File.mkdir_p!(root)
    previous = Application.get_env(:kogasa_frontend, :demo_directory)
    Application.put_env(:kogasa_frontend, :demo_directory, root)

    on_exit(fn ->
      File.rm_rf!(root)

      if previous do
        Application.put_env(:kogasa_frontend, :demo_directory, previous)
      else
        Application.delete_env(:kogasa_frontend, :demo_directory)
      end
    end)

    %{root: root}
  end

  test "only readable published recordings yield download links", %{root: root} do
    filename = "koth_genbu_ravine_b1_sept_30_14-36.dem"
    assert DemoDownloads.url(filename) == nil
    File.write!(Path.join(root, filename), String.duplicate("x", 1073))
    assert DemoDownloads.url(filename) == "https://fastdl.kogasa.tf/demos/" <> filename
    File.rm!(Path.join(root, filename))
    assert DemoDownloads.url(filename) == nil
  end

  test "rejects missing, empty, directory, symlink, unreadable and unsafe names", %{root: root} do
    File.write!(Path.join(root, "empty.dem"), "")
    File.mkdir!(Path.join(root, "directory.dem"))
    File.write!(Path.join(root, "private.dem"), String.duplicate("x", 1073))
    File.chmod!(Path.join(root, "private.dem"), 0o000)
    File.ln_s!(Path.join(root, "private.dem"), Path.join(root, "linked.dem"))

    for filename <- [
          nil,
          "",
          "missing.dem",
          "empty.dem",
          "directory.dem",
          "private.dem",
          "linked.dem",
          "../outside.dem",
          "/outside.dem",
          "test.dem.bz2",
          "test.dem\" onclick=\"bad",
          "folder/test.dem"
        ] do
      assert DemoDownloads.url(filename) == nil
    end
  end

  test "renders badge immediately after gamemode only while file is available", %{root: root} do
    filename = "koth_harvest_final_sept_30_14-36.dem"
    log = %{map: "koth_harvest_final", gamemode: "King of the Hill", demo_filename: filename}
    payload = %{rows: [log]}
    refute StatsFragments.logs_fragment_html(payload) =~ "demo-download"
    File.write!(Path.join(root, filename), String.duplicate("x", 1073))
    html = StatsFragments.logs_fragment_html(payload)
    assert html =~ ~s(<span class="gamemode-label">King of the Hill</span>)
    assert html =~ ~s(class="gamemode-label demo-download")
    assert html =~ ~s(Demo <i class="fa-solid fa-download" aria-hidden="true"></i>)
    assert html =~ ~s(href="https://fastdl.kogasa.tf/demos/#{filename}" download)
    [_, after_mode] = String.split(html, ~s(<span class="gamemode-label">King of the Hill</span>))

    assert String.starts_with?(
             String.trim_leading(after_mode),
             ~s(<a class="gamemode-label demo-download")
           )

    File.rm!(Path.join(root, filename))
    refute StatsFragments.logs_fragment_html(payload) =~ "demo-download"
  end
end
