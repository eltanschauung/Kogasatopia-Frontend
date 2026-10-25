defmodule KogasaFrontend.MapsDb.PublicConfigTest do
  use ExUnit.Case, async: true
  alias KogasaFrontend.MapsDb.PublicConfig

  test "known private directives disappear while ordinary game settings survive" do
    content =
      "hostname public\nsv_password \"synthetic-password\"\nrcon_password synthetic-rcon\n" <>
        "sv_setsteamaccount synthetic-gslt\nsm_web_api_key synthetic-api\nmp_timelimit 30\n"

    result = PublicConfig.redact(content)
    assert result =~ "hostname public\n"
    assert result =~ "mp_timelimit 30\n"
    refute result =~ "synthetic-"
    assert result =~ "redacted sensitive directive"
  end

  test "quoted multiline, mixed case, alias, comments and semicolons cannot leak known secrets" do
    for content <- [
          "SV_PASSWORD \"synthetic-\nprivate\"; mp_winlimit 2\n",
          "alias setup \"rcon_password synthetic-private; echo ok\"\nmp_winlimit 2\n",
          "// sv_password synthetic-private; more-private\nmp_winlimit 2\n",
          "\"sv_password\" \"synthetic-private\"; mp_winlimit 2\n",
          "sm_downloadurl \"https://user:synthetic-private@example.test/path\"\nmp_winlimit 2\n"
        ] do
      result = PublicConfig.redact(content)
      refute result =~ "synthetic-"
      refute result =~ "private"
      assert result =~ "mp_winlimit 2"
    end
  end

  test "benign quoted separators and empty config preserve exact bytes" do
    for content <- ["", "hostname \"hello; world\"\n", "// comment; intact\nmp_timelimit 30\n"] do
      assert PublicConfig.redact(content) == content
    end
  end
end
