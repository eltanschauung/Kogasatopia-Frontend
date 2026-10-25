defmodule KogasaFrontend.Chat.HistoryTest do
  use ExUnit.Case, async: true
  alias KogasaFrontend.Chat.History

  test "live arrivals retain only the newest500 ordered unique rows" do
    window = History.append([], Enum.map(1000..1//-1, &%{id: &1}))
    assert length(window) == 500
    assert hd(window).id == 501
    assert List.last(window).id == 1000
    assert History.append(window, window) == window
  end

  test "history slides backward instead of permanently capping accessible history" do
    recent = Enum.map(501..1000, &%{id: &1})
    window = History.prepend(recent, Enum.map(451..500, &%{id: &1}))
    assert length(window) == 500
    assert hd(window).id == 451
    assert List.last(window).id == 950
  end
end
