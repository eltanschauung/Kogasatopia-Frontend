defmodule KogasaFrontend.RepoCompatibilityTest do
  use KogasaFrontend.DataCase, async: false
  @moduletag :database
  alias KogasaFrontend.SteamSession.Record

  test "native adapter preserves decimal, integer and UTF-8 bound parameter values" do
    result =
      Repo.query!(
        "SELECT CAST(? AS DECIMAL(12,3)), CAST(? AS SIGNED), ?",
        ["1234.875", 1_234_567_890, "synthetic 人"]
      )

    assert [[decimal, 1_234_567_890, "synthetic 人"]] = result.rows
    assert Decimal.equal?(decimal, Decimal.new("1234.875"))
  end

  test "native transactions roll back authentication writes without leaking partial state" do
    hash = String.duplicate("a", 64)

    assert {:error, :synthetic_rollback} =
             Repo.transaction(fn ->
               Repo.insert!(%Record{
                 token_hash: hash,
                 steamid: "10000000000000001",
                 issued_at: 1,
                 expires_at: 2
               })

               Repo.rollback(:synthetic_rollback)
             end)

    assert Repo.get(Record, hash) == nil
  end
end
