defmodule WhaleChat.TimeDisplay do
  @moduledoc false

  @default_server_time_zone "America/New_York"

  def server_time_zone do
    Application.get_env(:whale_chat, :display_time_zone, @default_server_time_zone)
  end

  def format_server_datetime(unix_seconds, format \\ "%m/%d %H:%M %Z")

  def format_server_datetime(unix_seconds, format)
      when is_integer(unix_seconds) and unix_seconds > 0 do
    case unix_to_server_datetime(unix_seconds) do
      {:ok, datetime, zone_abbr} -> format_datetime(datetime, zone_abbr, format)
      _ -> "n/a"
    end
  rescue
    _ -> "n/a"
  end

  def format_server_datetime(_, _), do: "n/a"

  def format_server_time(unix_seconds, format \\ "%H:%M %Z") do
    format_server_datetime(unix_seconds, format)
  end

  def server_hour(unix_seconds) when is_integer(unix_seconds) and unix_seconds > 0 do
    case unix_to_server_datetime(unix_seconds) do
      {:ok, datetime, _zone_abbr} -> datetime.hour
      _ -> nil
    end
  end

  def server_hour(_), do: nil

  def server_naive_to_unix(%NaiveDateTime{} = naive) do
    local_wall_clock_unix =
      naive
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()

    local_wall_clock_unix - server_offset_seconds_for_local(naive)
  rescue
    _ -> DateTime.from_naive!(naive, "Etc/UTC") |> DateTime.to_unix()
  end

  defp unix_to_server_datetime(unix_seconds) do
    offset = server_offset_seconds_for_unix(unix_seconds)

    case DateTime.from_unix(unix_seconds + offset) do
      {:ok, datetime} -> {:ok, datetime, zone_abbr(offset)}
      error -> error
    end
  end

  defp format_datetime(datetime, zone_abbr, format) do
    format
    |> String.replace("%Y", pad(datetime.year, 4))
    |> String.replace("%m", pad(datetime.month, 2))
    |> String.replace("%d", pad(datetime.day, 2))
    |> String.replace("%H", pad(datetime.hour, 2))
    |> String.replace("%M", pad(datetime.minute, 2))
    |> String.replace("%S", pad(datetime.second, 2))
    |> String.replace("%Z", zone_abbr)
  end

  defp server_offset_seconds_for_unix(unix_seconds) do
    {:ok, utc_datetime} = DateTime.from_unix(unix_seconds)
    year = utc_datetime.year

    if unix_seconds >= dst_start_utc(year) and unix_seconds < dst_end_utc(year) do
      -4 * 3600
    else
      -5 * 3600
    end
  end

  defp server_offset_seconds_for_local(%NaiveDateTime{} = naive) do
    year = naive.year

    if NaiveDateTime.compare(naive, dst_start_local(year)) != :lt and
         NaiveDateTime.compare(naive, dst_end_local(year)) == :lt do
      -4 * 3600
    else
      -5 * 3600
    end
  end

  defp dst_start_utc(year), do: unix_utc(year, 3, nth_sunday(year, 3, 2), 7)
  defp dst_end_utc(year), do: unix_utc(year, 11, nth_sunday(year, 11, 1), 6)

  defp dst_start_local(year), do: naive!(year, 3, nth_sunday(year, 3, 2), 2)
  defp dst_end_local(year), do: naive!(year, 11, nth_sunday(year, 11, 1), 2)

  defp nth_sunday(year, month, nth) do
    first_sunday =
      Enum.find(1..7, fn day ->
        Date.day_of_week(Date.new!(year, month, day)) == 7
      end)

    first_sunday + (nth - 1) * 7
  end

  defp unix_utc(year, month, day, hour) do
    year
    |> naive!(month, day, hour)
    |> DateTime.from_naive!("Etc/UTC")
    |> DateTime.to_unix()
  end

  defp naive!(year, month, day, hour) do
    NaiveDateTime.new!(year, month, day, hour, 0, 0)
  end

  defp zone_abbr(-14_400), do: "EDT"
  defp zone_abbr(_), do: "EST"

  defp pad(value, size) do
    value
    |> Integer.to_string()
    |> String.pad_leading(size, "0")
  end
end
