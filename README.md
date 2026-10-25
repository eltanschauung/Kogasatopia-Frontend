# Kogasatopia Frontend

This repository represents the frontend used by Kogasatopia. Currently, it's a combination of the previous site frontends (blog + stat tracker dashboard) into one. It uses Elixir and the Phoenix webserver, which I became curious about while developing the server's live chat system at [kogasa.tf/chat](https://kogasa.tf/chat).

Features include:
- teamfortress.com styled blog with a changelog, relevant links and contact link
- cumulative stat tracking page
- 'Online Now' page which shows the in-game players, map, playercount and scoreboard live
- Ad-hoc Steam connect links for servers
- map database & server popularity statistics page
- match logs page
- current match log for in-game use through the motd panel
- live chat, which communicates with both servers (inspired by Minecraft Dynmap concept)
- weapons page which allows clients to check stats easily (to be completed)

## Steam sessions

Run `mix ecto.migrate` before starting an updated application. Steam logins use
per-device database records; this upgrade requires existing users to sign in once
again. Logout revokes that device without signing out other devices. The
`:steam_session_ttl_seconds` application setting defaults to 30 days (bounded to
5 minutes–90 days); expired records are pruned hourly. Keep the session table on
rollback and use only rollback builds that validate the persistent registry.

## Player Count API

`GET https://kogasa.tf/api/playercount` returns the current aggregate server population:

```json
{"success":true,"player_count":0,"visible_max":42,"display":"0","updated":1783915200}
```

Responses permit cross-origin browser requests and are publicly cached for five seconds.

<img width="1920" height="1080" alt="image" src="https://github.com/user-attachments/assets/fc0963c3-633f-41d2-977c-eb73c30e6e14" />
