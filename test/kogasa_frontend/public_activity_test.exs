defmodule PublicActivityTest do
  use ExUnit.Case, async: false
  alias KogasaFrontend.PublicActivity

  test "only exact SteamID64 lines become exclusions" do
    a = "76561198000000001"
    b = "76561198000000002"

    assert PublicActivity.parse("# Private list\r\n #{a} \r\n#{a}\n#{b}\ninvalid\n#{a}x\n") == [
             a,
             b
           ]
  end

  test "SQL excludes bound identities while retaining unattributed rows" do
    ids = ["76561198000000001", "76561198000000002"]

    assert PublicActivity.sql_filter("steamid", ids) ==
             {"(steamid IS NULL OR steamid NOT IN (?,?))", ids}

    assert PublicActivity.sql_filter("steamid", []) == {"1 = 1", []}
    assert_raise FunctionClauseError, fn -> PublicActivity.sql_filter("untrusted;sql", ids) end
  end

  test "reads the shared configuration without hardcoded accounts" do
    path =
      Path.join(System.tmp_dir!(), "public-activity-#{System.unique_integer([:positive])}.txt")

    old = Application.get_env(:kogasa_frontend, :public_activity_exclusions_file)

    on_exit(fn ->
      File.rm(path)

      if old,
        do: Application.put_env(:kogasa_frontend, :public_activity_exclusions_file, old),
        else: Application.delete_env(:kogasa_frontend, :public_activity_exclusions_file)
    end)

    File.write!(path, "76561198000000001\n")
    Application.put_env(:kogasa_frontend, :public_activity_exclusions_file, path)
    assert PublicActivity.excluded?("76561198000000001")
    refute PublicActivity.excluded?("76561198000000002")
    refute PublicActivity.excluded?(nil)
    File.write!(path, "76561198000000002\n")
    refute PublicActivity.excluded?("76561198000000001")
    assert PublicActivity.excluded?("76561198000000002")
  end
end
