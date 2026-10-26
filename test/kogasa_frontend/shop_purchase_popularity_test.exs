defmodule KogasaFrontend.ShopPurchasePopularityTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.ShopPurchasePopularity

  setup do
    directory =
      Path.join(System.tmp_dir!(), "shop-popularity-#{System.unique_integer([:positive])}")

    File.mkdir_p!(directory)
    on_exit(fn -> File.rm_rf!(directory) end)
    config = Path.join(directory, "points_store.cfg")
    database = Path.join(directory, "purchases.sq3")

    File.write!(config, """
    "points_store"
    {
      "cat" { "long_name" "Cat Pack" }
      "dog" { "long_name" "" }
    }
    """)

    sqlite = System.find_executable("sqlite3") || flunk("sqlite3 is required")

    {_, 0} =
      System.cmd(sqlite, [
        database,
        """
        CREATE TABLE bonuspoints_transactions(steamid64 TEXT,item_key TEXT,price_paid INTEGER);
        INSERT INTO bonuspoints_transactions VALUES
          ('player-a','cat',100),('player-a','cat',100),('player-b','cat',100),
          ('player-a','dog',100),('player-c','retired_item',100),
          ('player-d','free_gift',0),('player-e','negative',-5),
          ('','cat',100),('player-f','',100);
        """
      ])

    query = fn sql ->
      {output, 0} = System.cmd(sqlite, ["-readonly", "-json", database, sql])
      rows = Jason.decode!(output)
      columns = ["item_key", "purchasers"]
      {:ok, %{columns: columns, rows: Enum.map(rows, fn row -> Enum.map(columns, &row[&1]) end)}}
    end

    %{config: config, query: query}
  end

  test "ranks distinct paid purchasers, with config names and stable ties", context do
    assert ShopPurchasePopularity.list(config_path: context.config, query_fun: context.query) == [
             %{item_key: "cat", name: "Cat Pack", purchasers: 2},
             %{item_key: "dog", name: "dog", purchasers: 1},
             %{item_key: "retired_item", name: "retired_item", purchasers: 1}
           ]
  end

  test "missing catalog retains valid purchase counts", context do
    [first | _] =
      ShopPurchasePopularity.list(
        config_path: context.config <> ".missing",
        query_fun: context.query
      )

    assert first == %{item_key: "cat", name: "cat", purchasers: 2}
  end

  test "missing purchase table or unavailable database produces an empty section" do
    assert ShopPurchasePopularity.list(query_fun: fn _ -> {:error, :missing_table} end) == []
    assert ShopPurchasePopularity.list(query_fun: fn _ -> raise "isolated failure" end) == []

    assert ShopPurchasePopularity.list(query_fun: fn _ -> {:ok, %{columns: [], rows: []}} end) ==
             []
  end
end
