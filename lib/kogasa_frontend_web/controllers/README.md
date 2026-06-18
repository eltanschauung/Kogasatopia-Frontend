# API Controllers

Only route-facing controller actions are listed here.

## chat_api_controller.ex
- `index` - Returns chat messages with limit, before, after, and alerts_only filters.
- `create` - Submits a web chat message or updates the sender persona.

## maps_db_api_controller.ex
- `handle` - Authenticates the session, checks admin access, and dispatches the requested Maps action.
- `handle/list` - Returns the editable map config list.
- `handle/load` - Returns one map config file.
- `handle/save` - Saves one map config file.
- `handle/mass_edit` - Replaces text across map config files.

## online_api_controller.ex
- `index` - Returns the current online-player payload without HTTP caching.

## stats_api_controller.ex
- `fetch_page` - Returns cumulative stats rows, rendered HTML, and pagination metadata.
- `cumulative_fragment` - Returns the same cumulative stats payload as `fetch_page`.
- `logs_fragment` - Returns rendered match-log HTML for a page and scope.
- `current_log_fragment` - Returns rendered HTML for the current match log.
