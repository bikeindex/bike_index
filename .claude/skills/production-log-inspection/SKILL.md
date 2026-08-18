---
name: production-log-inspection
description: >-
  Inspect the Bike Index production Rails logs downloaded by `binx_logs` and
  streamed with `binx_cat web` / `binx_cat worker` — JSON-per-request (Lograge)
  on web plus free-form background-job lines on worker, far too large to read
  end-to-end. Trigger when the user asks to
  review, investigate, audit, or pull stats from a production log file
  (slow requests, error spikes, status-code distribution, exception
  stack traces, per-endpoint hit counts, suspicious traffic, failing
  background jobs). Also triggers when chasing a specific incident from logs
  (e.g. "what happened at 04:42 UTC?", "why did `/search/registrations` 500?").
  For one named exception use honeybadger-debugging, and for *aggregated*
  exception triage across time the Honeybadger MCP; this skill is for ad-hoc
  analysis of log files already on disk.
---

# Inspecting production logs

## Getting the logs

`binx_logs` downloads production logs; `binx_cat` streams them. Both are personal scripts on `PATH` (`~/bin`), not repo `bin/` entries, and both must be run from the repo root.

```bash
binx_logs                        # default: web AND worker, yesterday's archive + today's live log
binx_logs -d 7                   # both servers, past week of archives
binx_logs web                    # web only

binx_cat web | rg '"status":5'   # stream a server's logs, oldest lines first
binx_cat -l worker               # list the files that would be streamed
```

`binx_logs` leaves the rotated archives gzipped on disk (`tmp/<server>-production.log.<date>-<n>.gz`) alongside today's still-rotating, uncompressed log (`tmp/current-production-<server>.log`). **Always read them through `binx_cat <server>`** — it decompresses the archives and concatenates everything in chronological order on the fly. Don't glob the files yourself, and don't build your own concatenated copy: a day of web logs is ~630 MB uncompressed, and decompression is cheap next to the search, so streaming is free.

| Server | Contents |
|---|---|
| `binx_cat web` | Puma request logs — mostly Lograge JSON, one line per request |
| `binx_cat worker` | Background workers — free-form Rails/job/library lines |

**Review both by default.** A question framed around requests ("why are we 500ing") usually has half its answer in the worker log: the job that poisoned the cache, the Honeybadger client silently dropping error reports, a worker process crash-looping. Only skip a server when the user explicitly scopes to one.

**Use `rg`, not `grep`.** On a day of web logs `rg` is roughly 4× faster (a `-o` aggregation over 1.3M lines: 1.4s vs 5.5s). Flag translation is nearly one-to-one — `grep -oE 'x'` → `rg -o 'x'` (rg is always regex, so drop `-E`), `-c`/`-n`/`-A`/`-B` are the same, and `-F` still means literal. `rg` exits 1 on no matches, same as `grep`.

Rules for both servers:

- **Never `Read` the logs, and never `binx_cat` without a filter.** The web log is routinely several hundred MB. Always pipe into `rg`/`awk`/`head`/`tail`.
- **Synthesize by default; paste at most one short example when it's load-bearing.** Lograge lines are long and mostly structural JSON — dumping multiple into a reply is unreadable and burns context. A single representative line for an exception or a slow request is fine; a wall of match output is not.

## Line formats

Both servers share a syslog-style header: a severity letter (`I`/`W`/`E`), timestamp, and pid.

**Web — Lograge JSON**, one line per request, with a request-id prefix:

```
I, [2026-04-27T04:42:04.467657 #277641]  INFO -- : [0591f694-…] {"method":"GET","path":"/search/registrations","format":"html","controller":"Search::RegistrationsController","action":"index","status":500,"allocations":1073409,"duration":51237.65,"view":0.0,"db":51234.09,"remote_ip":"71.212.12.114","u_id":148942,"params":{…},"@timestamp":"…","@version":"1","message":"…"}
```

Key fields:

| Field | Notes |
|---|---|
| `duration`, `view`, `db` | **Milliseconds.** A 60s query is `60000`, not `60`. |
| `status` | HTTP status code |
| `controller`, `action`, `path` | Routing info |
| `u_id` | User id (null for anonymous) |
| `remote_ip` | Forwarded client IP |
| `allocations` | Ruby object allocations — high allocations + long duration is a strong signal of a bad query plan |
| `params` | Object literal — may contain commas/colons; don't split lines on `,` |

When a request raises, you also get **separate, non-JSON lines** starting with `[<request-id>]` at column 0 (no syslog header) containing the exception class, message, and stack trace, *followed* by another JSON line for `/500` (the `ErrorsController#server_error` render). That secondary `/500` line is noise for most analyses — it inflates 500 counts unless you filter it out.

**Worker — free-form.** Only a trickle of Lograge lines (bots hitting the worker host by IP). The bulk is:

- Job/rake output (`Requesting page 1`, `S3 Storage (56.1ms) Deleted files by key prefix: …`)
- `[SKYLIGHT] … Skylight agent enabled` — one per process boot; a high count means workers are restarting a lot
- Honeybadger client chatter (`Reporting error id=…`, `Success ⚡ …`, and throttle warnings — see pitfalls)
- Library deprecation warnings (`Scoped order is ignored, use :cursor with :order …`)
- Exception classes + backtraces, same `[<request-id>]`-prefixed shape as web

Since there's no fixed schema, search by message text, not by field.

## Common queries (web)

**Time range covered.** `binx_cat` exits cleanly when `head` closes the pipe.

```bash
binx_cat web | head -1
binx_cat web | tail -1
```

**Status-code distribution.**

```bash
binx_cat web | rg -o '"status":[0-9]+' | sort | uniq -c | sort -rn
```

**Slow requests over a threshold (in ms).** Use `awk` rather than a regex — durations are floats with arbitrary digit counts and a pattern like `"duration":[5-9][0-9]{4}` will silently miss values:

```bash
binx_cat web | awk -F'"duration":' '$2 != "" {split($2,a,","); if (a[1]+0 > 60000) print}'
```

Pipe that into `rg -o '"path":"[^"]+"' | sort | uniq -c | sort -rn` to group by path, or `rg -o '"status":[0-9]+'` for status mix.

**Distribution stats (p50/p90/p99).**

```bash
binx_cat web | awk -F'"duration":' '$2 != "" {split($2,a,","); print a[1]+0}' \
  | sort -n \
  | awk 'BEGIN{c=0}{v[c++]=$1; s+=$1} END{print "n="c, "p50="v[int(c*.5)], "p90="v[int(c*.9)], "p99="v[int(c*.99)], "max="v[c-1], "mean="s/c}'
```

**Most-hit endpoints.**

```bash
binx_cat web | rg -o '"controller":"[^"]+","action":"[^"]+"' | sort | uniq -c | sort -rn | head -20
```

**5xx counts by endpoint.** Filter to `"status":5` first to keep the line set small:

```bash
binx_cat web | rg '"status":5' \
  | rg -o '"controller":"[^"]+","action":"[^"]+"' | sort | uniq -c | sort -rn
```

**Several stats at once.** Each `binx_cat` re-reads the whole log, so when you want more than two or three cuts of the same data, spool once and reuse — the win is I/O, not decompression:

```bash
binx_cat web | rg '"status":5' > tmp/_5xx.log   # small; delete when done
```

## Common queries (worker)

**Severity mix** — cheap first pass; `E,` lines and `[`-prefixed backtrace lines are where the signal is:

```bash
binx_cat worker | awk '{print substr($0,1,1)}' | sort | uniq -c | sort -rn
```

**Cluster the noise.** Strip the header and the varying ids, then count — most of the file is a handful of repeated messages:

```bash
binx_cat worker \
  | sed -E 's/^[IWE], \[[^]]+\] +[A-Z]+ -- //; s/id=[a-f0-9-]+//g; s/pid=[0-9]+//g' \
  | cut -c1-90 | sort | uniq -c | sort -rn | head -15
```

**Exception classes.**

```bash
binx_cat worker | rg -o '^\[[a-f0-9-]+\] [A-Z][A-Za-z]*(::[A-Za-z]+)+' \
  | sed -E 's/^\[[a-f0-9-]+\] //' | sort | uniq -c | sort -rn
```

**Hourly rate of any message** — turns "this happens a lot" into "this started at 09:00":

```bash
binx_cat worker | rg 'reached max queue size' \
  | rg -o '\[2026-[0-9-]+T[0-9]{2}' | sort | uniq -c
```

**Worker restarts** (each boot logs the Skylight agent once):

```bash
binx_cat worker | rg -c 'Skylight agent enabled'
```

## Finding exception stack traces

Works the same on both servers. The JSON request line tells you a request 500'd but not *why*. Grab the request id from the JSON line, then search for that id — Rails writes the exception class and backtrace as separate lines with the same `[request-id]` prefix:

```bash
binx_cat web | rg -n '0591f694-49b4-4c9c-b49e-4fef89ae8d7b'
```

Look for lines starting with `E,` (ERROR severity) and lines beginning `[<id>] ActiveRecord::…` / `[<id>] ActionView::…` / `[<id>] Caused by:` / `[<id>] app/…:NN`. The trailing `app/…` lines are the user-code frames (Rails strips gem frames by default).

To find clusters of the same exception, search for the exception class plus a line of context:

```bash
binx_cat worker | rg -A1 'ActionController::RoutingError' | head -40
```

## Searching the files directly (optional fast path)

`rg -z` reads gzip and plain files alike, so it can search the archives *and* today's uncompressed log in one shot, in parallel across cores. It's modestly faster than streaming (1.1s vs 1.4s on one day; the gap widens with `-d 7`, where there are more archives to parallelize over). Two catches, so reach for it only on many-pass aggregations:

```bash
rg -z -I -o '"status":[0-9]+' $(binx_cat -l web) | sort | uniq -c | sort -rn
```

- **`-I` (`--no-filename`) is mandatory.** With more than one file `rg` prefixes each match with `tmp/current-production-web.log:`, which corrupts any `sort | uniq -c`.
- **Output order is not chronological.** `rg` searches files in parallel and emits them as they finish — today's log routinely lands before yesterday's archive. Fine for counting; wrong for `head -1`, `tail -1`, timelines, or reading a trace in order. Use `binx_cat` for anything order-sensitive.

## Pitfalls

- **Don't stop at the web log.** Job failures, cache poisoning, and worker crash-loops only show up in `binx_cat worker`, and they're often the cause of what the web log records as a symptom.
- **Sidekiq job lines are not in the worker log.** Searching it for `Sidekiq`, `TID-`, `Performing`, or `Enqueued` returns nothing — it holds Rails-level output from worker processes, not Sidekiq's own job lifecycle log. Use Sidekiq's web UI or Honeybadger for per-job success/failure.
- **Honeybadger throttle warnings mean Honeybadger is under-counting.** `Unable to report error; reached max queue size of 100` and `Error report failed: project is sending too many errors` in the worker log mean error reports were *dropped client-side*. When these are firing, Honeybadger fault counts are a floor, not a total — trust the logs over the dashboard for that window, and treat the onset time of these warnings as the real start of the incident.
- **Each errored request creates ≥2 JSON lines** — the original + the rendered `/500` page. Counting `"status":500` over-counts unless you exclude `"controller":"ErrorsController"` or filter to one of them.
- **`rg | sort | uniq` on JSON fragments is fine for counting**, but don't `awk -F,` or `cut -d,` on a whole line — `params:{…}` contains commas. Anchor splits to the field name (`-F'"duration":'`).
- **`grep -E` patterns need `-E` dropped for `rg`**, which is always regex. Conversely `rg` has no `-P`; it's Rust regex, so no backreferences or lookaround — none of the patterns here need them.
- **Durations are ms**, not seconds. A "slow" search is `> 60000`, not `> 60`.
- **The replication-conflict cancel error** (`PG::TRSerializationFailure: canceling statement due to conflict with recovery`) means the *replica* killed the query because WAL recovery was blocked — it's a symptom of a slow query holding the replica too long, not a bug in the SQL itself. Look for the underlying duration to find the real cause.
- **Bots and scanners produce a lot of noise** in 4xx and 5xx counts (path-traversal probes, `.well-known/*` lookups, npm CDN-style 404s). Nearly every request line in the *worker* log is a bot hitting the host's bare IP — `ActionController::RoutingError (No route matches [POST] "/")` there is noise, not a routing regression. Eyeball the path before treating an error spike as a real issue.
- **The Bash tool truncates long lines it *displays*** with `[... omitted end of long line]`. The data itself is intact — redirecting to a file or piping onward preserves full lines — but a whole Lograge line printed to the transcript gets clipped at the end (`@timestamp`, `@version`, `message`). So don't eyeball trailing fields off a raw line; extract them with `rg -o '<trailing-field>'` so the short *match* is what's displayed.
- **One scanner IP can dominate counts.** A single bot can rack up tens of thousands of 4xx/5xx and make a real user-facing issue look bigger than it is. Always check `"remote_ip"` distribution before treating an error spike as a real signal — group by IP first, then re-run analyses excluding the dominant scanner.
- **Archives outside the requested window are deleted on each `binx_logs` run**, so `binx_cat` can't stream a stale day from an earlier pull. If you need more history, re-run with `-d N` rather than hoarding files.

## When `jq` is and isn't worth it

The web log's lines are JSON, so `jq` is tempting — but you have to strip the syslog prefix first, and on a full-day log it's noticeably slower than `rg`/`awk`. Use `jq` when you need to group by **two or more** JSON fields at once, or when params/payload structure matters; otherwise the `awk -F'"key":'` patterns above are faster. It's rarely useful on the worker log, which is mostly not JSON.

```bash
# strip prefix, then jq — only worth it for multi-field aggregations
binx_cat web | sed -E 's/^[^{]+//' \
  | jq -r 'select(.status==500) | "\(.controller)#\(.action)\t\(.duration)"' \
  | sort | uniq -c | sort -rn | head
```

## Honeybadger vs. log files

For "what's currently broken in production" or "is exception X happening more this week", Honeybadger MCP (`mcp__honeybadger__list_faults`, `get_fault`, `query_insights`) is the right tool — it has aggregation, dedup, and time-series. Reach for this skill when:

- The user has already downloaded or pointed you at a specific log file, or
- The question is about *requests that didn't raise* (slow successful queries, traffic patterns, status-code mix), which Honeybadger doesn't capture, or
- The worker log shows Honeybadger client throttling, in which case its counts are unreliable for that window.
