defmodule KogasaFrontendWeb.ClientDependencyVersionsTest do
  use ExUnit.Case, async: true

  for {app, filename} <- [
        phoenix: "phoenix.min.js",
        phoenix_live_view: "phoenix_live_view.min.js"
      ] do
    test "the shipped #{app} client matches the server dependency" do
      app = unquote(app)
      filename = unquote(filename)
      public = Path.expand("../../priv/static/assets/js/#{filename}", __DIR__)
      dependency = Application.app_dir(app, "priv/static/#{filename}")

      assert File.read!(public) == File.read!(dependency),
             "Refresh the vendored #{app} client when upgrading its server dependency"
    end
  end
end
