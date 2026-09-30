defmodule KogasaFrontend.AccessLogTest do
  use ExUnit.Case, async: true

  alias KogasaFrontend.AccessLog

  setup do
    dir = Path.join(System.tmp_dir!(), "access-log-#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, path: Path.join(dir, "access.log")}
  end

  test "initial clearing opens a writable log", %{path: path} do
    File.write!(path, "old log\n")
    pid = start_supervised!({AccessLog, path: path, name: nil})
    assert File.read!(path) == ""
    GenServer.cast(pid, {:write, "new log\n"})
    :sys.get_state(pid)
    assert File.read!(path) == "new log\n"
    assert File.exists?(path <> ".last_clear")
  end

  test "restarts do not clear a log before its week expires", %{path: path} do
    File.write!(path, "retained\n")
    File.write!(path <> ".last_clear", Integer.to_string(System.system_time(:second)))
    pid = start_supervised!({AccessLog, path: path, name: nil})
    send(pid, :clear_if_due)
    :sys.get_state(pid)
    assert File.read!(path) == "retained\n"
    stop_supervised!(AccessLog)
    start_supervised!({AccessLog, path: path, name: nil})
    assert File.read!(path) == "retained\n"
  end

  test "weekly clearing is serialized with writes and persists its timestamp", %{path: path} do
    pid = start_supervised!({AccessLog, path: path, name: nil})
    GenServer.cast(pid, {:write, "before\n"})

    :sys.replace_state(pid, fn state ->
      %{state | last_clear: System.system_time(:second) - 7 * 24 * 60 * 60}
    end)

    send(pid, :clear_if_due)
    GenServer.cast(pid, {:write, "after\n"})
    :sys.get_state(pid)
    assert File.read!(path) == "after\n"
    timestamp = path |> Kernel.<>(".last_clear") |> File.read!() |> String.to_integer()
    assert abs(System.system_time(:second) - timestamp) < 5
    stop_supervised!(AccessLog)
    start_supervised!({AccessLog, path: path, name: nil})
    assert File.read!(path) == "after\n"
  end

  test "an overdue log is cleared at startup", %{path: path} do
    File.write!(path, "expired\n")
    File.write!(path <> ".last_clear", Integer.to_string(System.system_time(:second) - 604_800))
    start_supervised!({AccessLog, path: path, name: nil})
    assert File.read!(path) == ""
  end
end
