defmodule KogasaFrontend.WeaponPanelSecurityTest do
  use KogasaFrontendWeb.ConnCase, async: false
  import ExUnit.CaptureLog
  @moduletag :database
  alias KogasaFrontend.{Repo, WeaponPanel}
  @token String.duplicate("a", 32)
  @action "00000000-0000-4000-8000-000000000001"

  setup do
    # Temporary per-connection tables shadow any game schema. Never migrate or
    # rewrite game tables for tests. A dedicated test DB is still required.
    assert %{rows: [[database]]} = Repo.query!("SELECT DATABASE()")
    assert database =~ "_test"

    Repo.query!(
      "CREATE TEMPORARY TABLE weapons_web_sessions (token VARCHAR(32) PRIMARY KEY, steamid64 VARCHAR(17), class_index INT, equipped_uids TEXT, locked_purchase_keys TEXT, expires_at BIGINT)"
    )

    Repo.query!(
      "CREATE TEMPORARY TABLE weapons_web_actions (action_id VARCHAR(36) PRIMARY KEY, session_token VARCHAR(32), weapon_uid VARCHAR(64), desired_equipped INT, status VARCHAR(32), result_loadout TEXT, error_code VARCHAR(64), created_at BIGINT, processed_at BIGINT)"
    )

    Repo.query!(
      "INSERT INTO weapons_web_sessions VALUES (?, ?, 1, '', '', ?)",
      [@token, "10000000000000001", System.system_time(:second) + 300],
      log: false
    )

    Repo.query!(
      "INSERT INTO weapons_web_actions VALUES (?, ?, 'fixture', 1, 'done', 'fixture', '', 1, 1)",
      [@action, @token],
      log: false
    )

    on_exit(fn ->
      Repo.query("DROP TEMPORARY TABLE IF EXISTS weapons_web_actions", [], log: false)
      Repo.query("DROP TEMPORARY TABLE IF EXISTS weapons_web_sessions", [], log: false)
    end)

    :ok
  end

  test "action reads require a currently valid matching capability" do
    assert {:ok, %{status: "done"}} = WeaponPanel.fetch_action(@token, @action)
    assert :error = WeaponPanel.fetch_action(String.duplicate("b", 32), @action)
    Repo.query!("UPDATE weapons_web_sessions SET expires_at = 0")
    assert :error = WeaponPanel.fetch_action(@token, @action)
    assert {:error, :expired} = WeaponPanel.enqueue_action(@token, "fixture", true)
  end

  test "capability request and SQL debug logging do not disclose the token", %{conn: conn} do
    previous = Logger.level()
    Logger.configure(level: :debug)

    try do
      output =
        capture_log(fn ->
          assert {:ok, _} = WeaponPanel.fetch_session(@token, 1)
          assert {:ok, _} = WeaponPanel.enqueue_action(@token, "fixture", true)
          result = get(conn, "/api/weapons/panel/" <> @token <> "/actions/" <> @action)
          assert result.status == 200
        end)

      refute output =~ @token
    after
      Logger.configure(level: previous)
    end
  end
end
