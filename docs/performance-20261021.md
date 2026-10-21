# Frontend performance changes — 2026-10-21

Implementation for parent review; no commit, push, migration, service restart,
hot load or deployment performed. WhaleTracker, production tables/indexes,
chat/moderation/rate limiting and panel authorization code are unchanged.

## Measurements versus inferred savings

Parent measured one public sample: `/stats` **3.825 s**, `/logs` **0.094 s**,
weapons **0.040 s**, other sampled pages **0.019–0.059 s**. Parent's bounded
three-hour log sample counted 2,326 online-summary, 621 `/api/playercount`,
1,061 current-log and 547 chat requests. These are request counts, not users.

Parent measured the old weekly podium correlated query at **1,147 ms** and
the window-query alternative at **40 ms**, with identical three-row live output.
Those are parent measurements of the alternative, not a benchmark of the final
running application. This implementation retains its window strategy and adds
deterministic ordering only after previously specified tie breakers. No final
production HTTP benchmark was run, so there is no claimed new page latency.

Earlier read-only EXPLAIN estimated 3,434 log rows for both latest-log selection
(scan/filesort) and its count, and 16,290 player rows for totals and averages.
These are optimizer estimates, not measured execution times.

## Implemented

1. **Current log:** uses the same row SQL/mapping and batched player enrichment
   as logs pagination, without its unused total count. Saves one count query per
   successful current-log lookup. Selection/order, identity mode, privacy,
   fragment output and browser no-store policy remain unchanged. The latest-log
   sort itself remains.
2. **Online schema:** a supervised GenServer retains successful column sets for
   the two fixed online/server tables for **60 seconds**, measured with monotonic
   time. Warm payloads save two SHOW COLUMNS round trips; live rows and exclusions
   are still read each request. `OnlineSchema.invalidate(table)` explicitly
   clears one entry. SQL errors 1054/1146 invalidate and force one introspection
   and live-query retry; other SQL failures do not retry. Failed/empty metadata
   is not cached. Cache calls explicitly wait for the Repo-bounded query rather
   than imposing GenServer's shorter five-second timeout. Worker exits return
   error tuples; raised metadata queries return errors without killing the
   worker or caching a failure. Independent column additions become visible by expiry or
   explicit invalidation, since additions need not trigger an SQL error.
3. **Weapons parsing:** a separate supervised GenServer retains one public parse
   and SHA-256 digest per resolved path, bounded to **eight paths**. Bytes are
   still read/hash-checked on each call, catching same-size/same-time edits and
   atomic replacement without a TTL. Successful concurrent misses serialize and
   reuse the parse; only current digest/root is retained per path. Unreadable
   files invalidate their entry and return the existing empty result. Parser
   exceptions propagate to the caller without killing the cache; recovery is
   immediate on valid contents. Default path selection still runs per call.
   Class normalization and rendered HTML are not cached.
4. **Stats aggregates:** full page payload gets totals and eligible-player
   averages from one fresh aggregate statement. Saves one full aggregate scan
   and round trip on that path. Conditional averages preserve eligibility,
   NULL/zero handling and denominators; standalone averages remain available to
   focused-player APIs. No response or gameplay-data TTL was introduced.
5. **Weekly podium:** ROW_NUMBER partitioned by steamid replaces repeated
   correlated selection. Cutoff stays `started_at >= week_start` with no new
   upper bound, minimum-duration or finalized condition. COALESCE, best streak,
   kills and latest-start ordering remain; exact per-player ties use log_id ASC,
   and exact global ties use steamid ASC then log_id ASC. LIMIT 3 still precedes
   Elixir's positive-streak filter. Enrichment/output code is unchanged.
6. **Public count browser requests:** both `WTNavStatus.updateOnline` and
   ChatViewport's count helper now use fetch `cache: "default"` instead of
   no-store, honoring the existing server max-age=5 (and existing headers).
   Both target `/stats/online_summary.php`; `/api/playercount` routes to the
   same public controller. No helper explicitly targeting that alias was found.
   No TTL/header changed. Online details, chat, current-log and panel-action
   request policies remain unchanged. Only GET `/stats/online_summary.php` moved
   from `:chat_api` to its own `:api` scope, avoiding chat persona/session creation
   and Set-Cookie on this public cacheable response. Controller/payload/headers
   and all other routes retain their behavior.

Both caches use small supervised bounded maps rather than ETS. Schema misses
perform database introspection serially; weapons misses perform parsing serially.
This is deliberate coalescing for two stable schema keys and small public files,
not a generic request cache. Restart discards cache state.

## Tested and source-reviewed boundaries

The full ExUnit run disables the Repo and DB test alias using
`KOGASA_SKIP_TEST_DB=1 MIX_ENV=test mix test`. No sandbox or application database
is started; no migration or application table/lock operation occurs in that run.
Native SQL validation is a separate explicit temporary-table fixture command.

Executable checks cover schema hits with live callback execution, 60-second
expiry, explicit invalidation, failure/empty recovery, concurrent miss
coalescing, exactly one schema-error retry, unrelated errors, changed-column
recovery and supervised stop/start. Weapons checks cover shared parsing,
same-size/same-mtime changes, atomic replacement, deletion/recreation, parser
error/recovery, eight-path bound/eviction, supervised stop/start and the exact
public-only shape of retained entries. Existing weapons catalog and weapon
statistics tests also pass in the full suite.

Final follow-up tests additionally cover raised metadata-query failure/recovery,
an absent/stopped worker returning errors, and a Conn request through the legacy
summary route asserting JSON/cache headers, `:api` pipeline, no Set-Cookie,
no chat identity assign and no fetched/created session. They use the DB-skipped
Repo failure default, not real sessions.

Actual produced SQL is tested against isolated in-memory SQLite fixtures:
103 podium differential sets, deterministic exact ties, four aggregate sets,
and actual latest/empty-log SQL. Separately, native MariaDB executes the actual
produced SQL after substituting only table identifiers with random,
connection-local TEMPORARY names: 28 podium differential sets (including
distinct players, streak/kills/latest ordering, NULL/zero and cutoff boundaries),
exact ties, four numeric/NULL aggregate cases and latest/empty-log SQL. There
are no production table reads/writes, persistent fixture tables, named locks or
HTTP listeners in that fixture script. It closes the connection afterward.

Mocked-fetch JS checks execute both count helpers and assert the endpoint,
request cache mode and rendered count. Source assertions guard unchanged
online-detail/chat/current-log policies. JS parsing and `git diff --check` pass.

Source checks, rather than an end-to-end DB fixture, establish that current_log
skips COUNT and reuses mapping/enrichment, and that page_payload calls its shared
aggregate once. Native fixtures supplement those checks with real SQL results;
they do not exercise full HTTP rendering or production query counts.

Panel/session freshness is **source-reviewed**, not claimed as an end-to-end
two-session authorization test. InfoPage still invokes panel_session per request
and marks equipped/locked values afterward; WeaponPanel still performs its
token/class/expiry database checks. None of those files changed. Cache tests
inspect retained state and show public parse entries only. A two-session DB
authorization fixture was not added because that would require new dependency
plumbing or production panel access; neither is necessary for this scoped parse
cache. No personalized/session/permission/equipped/locked/rendered values are
passed into either cache.

## Validation output

Initial focused run before restart/native additions:

```text
Compiling 7 files (.ex)
Generated kogasa_frontend app
Running ExUnit with seed: 34412, max_cases: 4
.............
Finished in 1.1 seconds (1.1s async, 0.00s sync)
13 tests, 0 failures
```

Full DB-skipped suite after scoped formatting and restart additions:

```text
Compiling 3 files (.ex)
Generated kogasa_frontend app
Running ExUnit with seed: 165449, max_cases: 4
.................................................................................................................................................
Finished in 2.8 seconds (2.0s async, 0.7s sync)
145 tests, 0 failures
```

Final full suite after the public-route/cache-failure follow-up:

```text
Compiling 2 files (.ex)
Generated kogasa_frontend app
Running ExUnit with seed: 770010, max_cases: 4
....................................................................................................................................................
Finished in 2.4 seconds (1.7s async, 0.6s sync)
148 tests, 0 failures
```

```text
MariaDB temporary fixture parity passed: 28 podium differential sets, exact ties, 4 aggregate sets, actual latest/empty queries; no persistent tables touched
public count policy passed: both mocked fetch paths and unchanged detail/chat/current-log policies
```

Native fixture input is exported from the test-compiled pure SQL functions with
`mix run --no-start`, then consumed by `test/fixtures/performance_sql_mariadb.php`.
Only that PHP process uses existing service DB credentials; values are not
printed. The temporary-table test is intentionally not run automatically with
the general suite. Both `node --check` invocations and `git diff --check` exit 0.
`mix format` was restricted to touched Elixir source/test files; the follow-up
formatted only its four affected source/test files. JS policy/syntax and diff
checks passed again after the follow-up.

Production compile, after tests, under exported service env and existing
SECRET_KEY_BASE, without `--force`, migrations or launcher:

```text
Compiling 9 files (.ex)
Generated kogasa_frontend app
```

Follow-up production compile under the same service env/secret, without force:

```text
Compiling 3 files (.ex)
Generated kogasa_frontend app
```

Original screen/BEAM chain remains PID 3794900 -> 3794901. No hot load/restart.
The compile result is not evidence that new modules are running.

## Preservation, activation and rollback

Original worktree has 49 unrelated paths: two tracked modifications, one tracked
deletion and 46 untracked files. Snapshot is outside the repo at
`/home/kogasa/frontend-perf-initial-20261021.json`, SHA-256
`453e7ec2b2f4cb9c0cdfd16603ad5c67fbb9103d09e78f3b535437c9a20e3b32`.
Post-compile verification: **49 checked, zero changed**. Existing tracked diffs
and deletion are deliberately excluded from this implementation's source list.

Pre-edit source backup: `/home/kogasa/frontend-perf-code-baseline-20261021.tgz`;
additional app.js baseline: `/home/kogasa/frontend-perf-app-js-baseline-20261021.js`.
Pre-compile application binaries: `/home/kogasa/frontend-perf-prod-binaries-before-20261021.tgz`,
SHA-256 `b631ed02be276623bd815fa9771d074bd0e88ec2d864e697a0e7bb1e53c9f788`.
The binary archive was created with private permissions before prod compilation.
It captures on-disk application binaries, not a dump of loaded VM modules.

After explicit parent approval, activate by the established service procedure,
then verify process identity, public pages, fresh panel behavior and bounded
error/latency summaries. The existing launcher stops screens and runs migrations;
do not invoke it casually as a compile/test command. Any activation must account
for that behavior and avoid unapproved DB changes.

Static assets are served from this checkout: the two JS edits may already be
served by the old process on new asset requests, even though Elixir code awaits
process activation. Browser asset caches may defer uptake. No unrelated asset
build/fingerprint churn was introduced.

If rollback is approved, restore only these implementation source paths from
their baseline and the pre-compile application binaries, preserving all unknown
or subsequent changes; do not blindly extract the entire source backup. Review
newly introduced cache/test/doc files individually. Restore the two JS files
for browser-policy rollback. Restart only through an approved activation step.
No data rollback or schema/index rollback is required.

## Exact implementation files

```text
lib/kogasa_frontend/application.ex
lib/kogasa_frontend/online_feed.ex
lib/kogasa_frontend/online_schema.ex (new)
lib/kogasa_frontend/stats_feed.ex
lib/kogasa_frontend/valve_key_values.ex
lib/kogasa_frontend/weapons_config.ex
lib/kogasa_frontend/weapons_root_cache.ex (new)
lib/kogasa_frontend_web/router.ex
priv/static/assets/js/app.js
priv/static/assets/js/app/nav_status.js
test/kogasa_frontend/online_schema_test.exs (new)
test/kogasa_frontend/performance_sql_test.exs (new)
test/kogasa_frontend/weapons_root_cache_test.exs (new)
test/kogasa_frontend_web/controllers/online_summary_controller_test.exs
test/fixtures/performance_sql.py (new)
test/fixtures/performance_sql_mariadb.php (new)
test/fixtures/public_count_policy.cjs (new)
docs/performance-20261021.md (new)
```

## Remaining costs and risks

Latest-log sorting, summary historical aggregates, identity/profile enrichment,
game-origin chat polling, MapsDb filesystem fanout and cold-cache failure paths
remain deferred. MapsDb already has a separate persisted analytics cache; its
407 small config files are still classified live. No broad response cache,
gameplay TTL increase or index/schema change was introduced.

Window SQL requires the existing database's window-function support, exercised
by native fixtures. Fixture parity is not a production-scale planner benchmark.
Combining aggregates couples their statement-level failure: on failure both
shared results default empty; there is no split-query fallback. Cache processes
serialize misses; schema calls use an explicit infinite GenServer call timeout
while the actual Repo operation remains bounded. Metadata errors and worker
exits return errors for OnlineFeed's existing unavailable-payload behavior.
The 60-second schema lifetime bounds additions that
produce no SQL error. Weapons I/O/hash cost and per-request class normalization
remain. Post-activation latency, cache-hit rates, external Steam miss behavior
and two-session panel rendering still need bounded observation under parent
approval; no new production benchmark is claimed here.

## Production activation — 2026-10-21

Parent authorized deployment after independent source/test review. Restarted only
`kogasa_frontend` using exported existing service env, existing SECRET_KEY_BASE
and `MIX_ENV=prod mix phx.server` directly; no launcher, migrations, indexes,
forced compilation or compile-env override. BEAM changed from 3794901 to
3972730 (screen 3972729). HTTP 80/TLS 443 remain listening. Both game screens
and all four srcds PIDs are unchanged. Existing 49 user paths passed hash/absence
checks before activation and before staging; all are excluded from the commit.

Bounded sequential public HTTPS checks (seconds and downloaded bytes):

| Path | Status | Seconds | Bytes |
| --- | --- | --- | --- |
| `/stats (cold)` | 200 | 1.097018 | 189429 |
| `/stats (warm 1)` | 200 | 0.361902 | 189429 |
| `/stats (warm 2)` | 200 | 0.266708 | 189429 |
| `/stats (warm 3)` | 200 | 0.281242 | 189429 |
| `/` | 200 | 0.023835 | 78759 |
| `/weapons` | 200 | 0.047059 | 145566 |
| `/logs` | 200 | 0.356463 | 713390 |
| `/maps` | 200 | 0.163377 | 189228 |
| `/chat` | 200 | 0.046352 | 54193 |
| `/online` | 200 | 0.058917 | 25188 |
| `/stats/online.php` | 200 | 0.029614 | 887 |
| `/stats/online_summary.php` | 200 | 0.020028 | 85 |
| `/stats/current_log_fragment.php` | 200 | 0.026341 | 10767 |
| `/weapons?view=scout-custom-ingame` | 200 | 0.024636 | 16312 |

All curl exits were zero, with no detected HTTP/body error flags. Public count
JSON has the expected typed fields, zero Set-Cookie headers, and unchanged
`public, max-age=5, stale-while-revalidate=10`. Personalized weapons remains
`no-store`; online details/current-log retain their no-store/no-cache policy.
Bounded new screen observation found zero error-level lines and no compile-env
mismatch. No private bodies, names or identifiers are recorded.

Validation carried forward from the independently reviewed build: 148 ExUnit
tests/zero failures; native MariaDB temporary fixtures: 28 podium differential
sets, exact ties, four aggregate sets, actual latest/empty queries; JS mocked
fetch policy and syntax checks; scoped formatter and diff checks; correct-env
production compilation. No synthetic concurrency load or additional optimization.
The previous 3.825 s stats result was one parent sample; the new one-cold/three-warm
sample is bounded observation, not a controlled benchmark. Two-session panel
rendering, cache hit-rate telemetry and external Steam misses remain unmeasured.
