---
name: production-log-inspection
description: >-
  Inspect Bike Index production Rails logs at `tmp/*.production.log` —
  JSON-per-request format produced by Lograge, far too large to read
  end-to-end. Trigger when the user asks to
  review, investigate, audit, or pull stats from a production log file
  (slow requests, error spikes, status-code distribution, exception
  stack traces, per-endpoint hit counts, suspicious traffic). Also
  triggers when chasing a specific incident from logs (e.g. "what
  happened at 04:42 UTC?", "why did `/search/registrations` 500?").
  Honeybadger MCP is the right tool for *aggregated* exception triage
  across time; this skill is for ad-hoc analysis of a specific log
  file already on disk.
---

# Inspecting production logs

Bike Index production logs live at `tmp/<YYYY-M-D>.production.log` (e.g. `tmp/2026-4-27.production.log`). They're large, so:

- **Never `Read` or `cat` the whole file.** Use `grep`/`awk`/`head`/`tail` to slice.
- **Synthesize by default; paste at most one short example when it's load-bearing.** Lograge lines are long and mostly structural JSON — dumping multiple into a reply is unreadable and burns context. A single representative line for an exception or a slow request is fine; a wall of grep output is not.

## Log line format

Each request produces one JSON-content line (Lograge), prefixed by a syslog-style header:

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

When a request raises, you also get **separate, non-JSON lines** with the same request id prefix containing the exception class, message, and stack trace, *followed* by another JSON line for `/500` (the `ErrorsController#server_error` render). That secondary `/500` line is noise for most analyses — it inflates 500 counts unless you filter it out.

## Common queries

**Time range covered.**

```bash
head -1 tmp/2026-4-27.production.log
tail -1 tmp/2026-4-27.production.log
```

**Status-code distribution.**

```bash
grep -oE '"status":[0-9]+' tmp/2026-4-27.production.log | sort | uniq -c | sort -rn
```

**Slow requests over a threshold (in ms).** Use `awk` rather than a regex — durations are floats with arbitrary digit counts and a regex like `"duration":[5-9][0-9]{4}` will silently miss values:

```bash
awk -F'"duration":' '$2 != "" {split($2,a,","); if (a[1]+0 > 60000) print}' tmp/2026-4-27.production.log
```

Pipe that into `grep -oE '"path":"[^"]+"' | sort | uniq -c | sort -rn` to group by path, or `grep -oE '"status":[0-9]+'` for status mix.

**Distribution stats (p50/p90/p99).**

```bash
awk -F'"duration":' '$2 != "" {split($2,a,","); print a[1]+0}' tmp/2026-4-27.production.log \
  | sort -n \
  | awk 'BEGIN{c=0}{v[c++]=$1; s+=$1} END{print "n="c, "p50="v[int(c*.5)], "p90="v[int(c*.9)], "p99="v[int(c*.99)], "max="v[c-1], "mean="s/c}'
```

**Most-hit endpoints.**

```bash
grep -oE '"controller":"[^"]+","action":"[^"]+"' tmp/2026-4-27.production.log | sort | uniq -c | sort -rn | head -20
```

**5xx counts by endpoint.** Filter to `"status":5` first to keep the line set small:

```bash
grep '"status":5' tmp/2026-4-27.production.log \
  | grep -oE '"controller":"[^"]+","action":"[^"]+"' | sort | uniq -c | sort -rn
```

## Finding exception stack traces

The JSON request line tells you a request 500'd but not *why*. Grab the request id from the JSON line, then `grep -n` the whole file for that id — Rails writes the exception class and backtrace as separate lines with the same `[request-id]` prefix:

```bash
grep -n "0591f694-49b4-4c9c-b49e-4fef89ae8d7b" tmp/2026-4-27.production.log
```

Look for lines starting with `E,` (ERROR severity) and lines beginning `[<id>] ActiveRecord::…` / `[<id>] ActionView::…` / `[<id>] Caused by:` / `[<id>] app/…:NN`. The trailing `app/…` lines are the user-code frames (Rails strips gem frames by default).

To find clusters of the same exception, search for the exception class plus a line of context:

```bash
grep -B0 -A1 "PG::TRSerializationFailure" tmp/2026-4-27.production.log | head -40
```

## Pitfalls

- **Each errored request creates ≥2 JSON lines** — the original + the rendered `/500` page. Counting `"status":500` over-counts unless you exclude `"controller":"ErrorsController"` or filter to one of them.
- **`grep | sort | uniq` on JSON fragments is fine for counting**, but don't `awk -F,` or `cut -d,` on a whole line — `params:{…}` contains commas. Anchor splits to the field name (`-F'"duration":'`).
- **Durations are ms**, not seconds. A "slow" search is `> 60000`, not `> 60`.
- **The replication-conflict cancel error** (`PG::TRSerializationFailure: canceling statement due to conflict with recovery`) means the *replica* killed the query because WAL recovery was blocked — it's a symptom of a slow query holding the replica too long, not a bug in the SQL itself. Look for the underlying duration to find the real cause.
- **Bots and scanners produce a lot of noise** in 4xx and 5xx counts (path-traversal probes, `.well-known/*` lookups, npm CDN-style 404s). Eyeball the path before treating an error spike as a real issue.
- **The Bash tool truncates long lines in piped output** with `[... omitted end of long line]`, even when the pipeline ends in a file redirect. Fields at the *end* of a Lograge JSON line (`@timestamp`, `@version`, `message`) get clipped if you stage with `grep <line-pattern> | grep -oE '<trailing-field>'`. Workarounds: (a) `awk` directly on the file — no pipe, full lines preserved; (b) `grep -oE '<pattern>' file.log` so the *match* itself (short) is what enters the pipeline, not the whole line.
- **One scanner IP can dominate counts.** A single bot can rack up tens of thousands of 4xx/5xx and make a real user-facing issue look bigger than it is. Always check `"remote_ip"` distribution before treating an error spike as a real signal — group by IP first, then re-run analyses excluding the dominant scanner.

## When `jq` is and isn't worth it

The lines are JSON, so `jq` is tempting — but you have to strip the syslog prefix first, and on a full-day log it's noticeably slower than `grep`/`awk`. Use `jq` when you need to group by **two or more** JSON fields at once, or when params/payload structure matters; otherwise `awk -F'"key":'` patterns above are faster.

```bash
# strip prefix, then jq — only worth it for multi-field aggregations
sed -E 's/^[^{]+//' tmp/2026-4-27.production.log \
  | jq -r 'select(.status==500) | "\(.controller)#\(.action)\t\(.duration)"' \
  | sort | uniq -c | sort -rn | head
```

## Honeybadger vs. log files

For "what's currently broken in production" or "is exception X happening more this week", Honeybadger MCP (`mcp__honeybadger__list_faults`, `get_fault`, `query_insights`) is the right tool — it has aggregation, dedup, and time-series. Reach for this skill when:

- The user has already downloaded or pointed you at a specific log file, or
- The question is about *requests that didn't raise* (slow successful queries, traffic patterns, status-code mix), which Honeybadger doesn't capture.
