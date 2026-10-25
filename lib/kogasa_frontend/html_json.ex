defmodule KogasaFrontend.HTMLJSON do
  @moduledoc "JSON for HTML script text, preserving values without allowing HTML tag boundaries."

  def encode!(value) do
    value
    |> Jason.encode!(escape: :html_safe)
    |> String.replace(">", "\\u003E")
    |> String.replace("&", "\\u0026")
  end
end
