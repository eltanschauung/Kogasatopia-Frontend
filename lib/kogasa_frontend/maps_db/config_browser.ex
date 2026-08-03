defmodule KogasaFrontend.MapsDb.ConfigBrowser do
  @moduledoc false

  import Ecto.Query

  alias KogasaFrontend.MapsDb.MapMeta
  alias KogasaFrontend.MapsDb.Sections
  alias KogasaFrontend.MapsDb.Source
  alias KogasaFrontend.Repo
  alias KogasaFrontend.TimeDisplay

  def list_api_maps(cfg) do
    rows =
      cfg.maps_dir
      |> Path.join("*.cfg")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(&multi_line_config?/1)
      |> Enum.map(fn file ->
        stat = File.stat!(file)
        name = Path.rootname(Path.basename(file))

        %{
          "name" => name,
          "modified" => mtime_unix(stat),
          "size" => stat.size
        }
      end)
      |> Enum.sort_by(&String.downcase(&1["name"]))

    names = Enum.map(rows, & &1["name"])
    Sections.order_api_rows(rows, fetch_categories(names))
  end

  def load_config_file(map, source, cfg) do
    with {:ok, normalized_source} <- Source.sanitize(source),
         {:ok, path, map_name} <- sanitize_map(map, normalized_source, cfg),
         {:ok, content} <- File.read(path),
         {:ok, stat} <- File.stat(path) do
      {:ok, %{map: map_name, content: content, modified: mtime_unix(stat)}}
    else
      {:error, _} = error -> error
      {:file_error, reason} -> {:error, {:io, reason}}
    end
  end

  def build_page_sections(cfg) do
    map_names =
      cfg.maps_dir
      |> Path.join("*.cfg")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.filter(&multi_line_config?/1)
      |> Enum.map(&Path.rootname(Path.basename(&1)))
      |> Enum.sort_by(&String.downcase/1)

    map_meta = fetch_meta(map_names)

    sections =
      []
      |> maybe_add_server_configs(cfg.tf_cfg_dir)
      |> maybe_add_mapcycles(cfg.tf_cfg_dir)
      |> add_playercount_settings(cfg)
      |> maybe_add_category_configs(map_meta, cfg)

    sections ++ Sections.build_map_sections(map_names, map_meta)
  end

  defp fetch_categories([]), do: %{}

  defp fetch_categories(names) do
    Repo.all(from m in MapMeta, where: m.map_name in ^names, select: {m.map_name, m.category})
    |> Map.new()
  end

  defp fetch_meta([]), do: %{}

  defp fetch_meta(names) do
    Repo.all(
      from m in MapMeta,
        where: m.map_name in ^names,
        select: {m.map_name, %{category: m.category, sub_category: m.sub_category}}
    )
    |> Enum.map(fn {name, meta} ->
      {name, %{category: meta.category || "", sub_category: meta.sub_category || ""}}
    end)
    |> Map.new()
  end

  defp maybe_add_server_configs(sections, tf_cfg_dir) do
    entries =
      list_tfcfg_files(
        tf_cfg_dir,
        fn _base, lower ->
          String.contains?(lower, "server") && not String.contains?(lower, "mapcycle")
        end,
        "server",
        "server",
        "tfcfg"
      )

    if entries == [] do
      sections
    else
      sections ++
        [%{label: "Server configs", slug: "server-configs", entries: entries, open: false}]
    end
  end

  defp maybe_add_mapcycles(sections, tf_cfg_dir) do
    entries =
      list_tfcfg_files(
        tf_cfg_dir,
        fn _base, lower -> String.contains?(lower, "mapcycle") end,
        "mapcycle",
        "mapcycle",
        "tfcfg"
      )

    if entries == [] do
      sections
    else
      sections ++ [%{label: "Mapcycles", slug: "mapcycles", entries: entries, open: false}]
    end
  end

  defp add_playercount_settings(sections, cfg) do
    entries =
      [
        %{
          name: "d_highpop",
          display: "High Population",
          type: "playercount",
          category: "playercount",
          source: "mapsdb"
        },
        %{
          name: "d_lowpop",
          display: "Low Population",
          type: "playercount",
          category: "playercount",
          source: "mapsdb"
        }
      ]
      |> Enum.filter(&mapsdb_entry_has_multiple_lines?(&1, cfg))

    if entries == [] do
      sections
    else
      sections ++
        [
          %{
            label: "Playercount settings",
            slug: "playercount-settings",
            open: false,
            entries: entries
          }
        ]
    end
  end

  defp maybe_add_category_configs(sections, map_meta, cfg) do
    category_targets = [
      {"harvest", :sub_category, "category_harvest", "Harvest-type maps", "subcategory"},
      {"5cp", :category, "category_5cp", "5CP maps", "category"},
      {"3cp", :category, "category_3cp", "3CP maps", "category"},
      {"attack/defend", :category, "category_attack_defend", "Attack/Defend maps", "category"}
    ]

    entries =
      Enum.flat_map(category_targets, fn {slug, column, name, display, type} ->
        exists? =
          Enum.any?(map_meta, fn {_map_name, meta} ->
            value =
              meta |> Map.get(column, "") |> to_string() |> String.trim() |> String.downcase()

            value == slug
          end)

        entry = %{name: name, display: display, type: type, category: type, source: "mapsdb"}

        if exists? and mapsdb_entry_has_multiple_lines?(entry, cfg), do: [entry], else: []
      end)

    if entries == [] do
      sections
    else
      sections ++
        [%{label: "Category configs", slug: "category-configs", entries: entries, open: false}]
    end
  end

  defp list_tfcfg_files(tf_cfg_dir, predicate, type, category, source) do
    if File.dir?(tf_cfg_dir) do
      tf_cfg_dir
      |> File.ls!()
      |> Enum.filter(fn file ->
        lower = String.downcase(file)
        path = Path.join(tf_cfg_dir, file)

        String.ends_with?(lower, ".cfg") and predicate.(Path.rootname(file), lower) and
          multi_line_config?(path)
      end)
      |> Enum.map(fn file ->
        %{
          name: Path.rootname(file),
          display: Path.rootname(file),
          type: type,
          category: category,
          source: source
        }
      end)
      |> Enum.sort_by(&String.downcase(&1.name))
    else
      []
    end
  end

  defp sanitize_map(nil, _source, _cfg), do: {:error, :missing_map}
  defp sanitize_map("", _source, _cfg), do: {:error, :missing_map}

  defp sanitize_map(map, source, cfg) when is_binary(map) do
    if Regex.match?(~r/^[A-Za-z0-9_]+$/, map) do
      base = if source == "tfcfg", do: cfg.tf_cfg_dir, else: cfg.maps_dir
      path = Path.join(base, map <> ".cfg")

      with true <- allowed_config?(map, source, cfg),
           true <- File.regular?(path),
           {:ok, safe_path} <- contained_path(path, base) do
        {:ok, safe_path, map}
      else
        _ -> {:error, :not_found}
      end
    else
      {:error, :invalid_map}
    end
  end

  defp allowed_config?(map, "tfcfg", cfg),
    do: cfg.tf_cfg_dir |> allowed_tfcfg_entries() |> MapSet.member?(map)

  defp allowed_config?(map, _source, cfg),
    do: cfg.maps_dir |> allowed_mapsdb_entries() |> MapSet.member?(map)

  defp allowed_mapsdb_entries(maps_dir) do
    maps_dir
    |> wildcard_cfg_names()
    |> MapSet.new()
  end

  defp allowed_tfcfg_entries(tf_cfg_dir) do
    server_configs =
      list_tfcfg_files(
        tf_cfg_dir,
        fn _base, lower ->
          String.contains?(lower, "server") && not String.contains?(lower, "mapcycle")
        end,
        "server",
        "server",
        "tfcfg"
      )

    mapcycles =
      list_tfcfg_files(
        tf_cfg_dir,
        fn _base, lower -> String.contains?(lower, "mapcycle") end,
        "mapcycle",
        "mapcycle",
        "tfcfg"
      )

    (server_configs ++ mapcycles)
    |> Enum.map(& &1.name)
    |> MapSet.new()
  end

  defp wildcard_cfg_names(dir) do
    dir
    |> Path.join("*.cfg")
    |> Path.wildcard()
    |> Enum.filter(&File.regular?/1)
    |> Enum.filter(&multi_line_config?/1)
    |> Enum.map(&Path.rootname(Path.basename(&1)))
  end

  defp mapsdb_entry_has_multiple_lines?(%{name: name}, cfg) do
    cfg.maps_dir
    |> Path.join(name <> ".cfg")
    |> multi_line_config?()
  end

  defp multi_line_config?(path) do
    path
    |> File.stream!([], :line)
    |> Enum.take(2)
    |> length()
    |> Kernel.>(1)
  rescue
    _ -> false
  end

  defp contained_path(path, base) do
    base_path = Path.expand(base)
    safe_path = Path.expand(path)

    with {:ok, %File.Stat{type: type}} when type != :symlink <- File.lstat(path) do
      if safe_path == base_path or String.starts_with?(safe_path, base_path <> "/") do
        {:ok, safe_path}
      else
        {:error, :not_found}
      end
    else
      _ -> {:error, :not_found}
    end
  end

  defp mtime_unix(%File.Stat{mtime: {{year, month, day}, {hour, minute, second}}}) do
    {:ok, naive_datetime} = NaiveDateTime.new(year, month, day, hour, minute, second)
    TimeDisplay.server_naive_to_unix(naive_datetime)
  end

  defp mtime_unix(%File.Stat{}), do: System.system_time(:second)
end
