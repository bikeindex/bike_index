---
name: honeybadger-debugging
description: >-
  Investigate and fix a specific Honeybadger exception in the Bike Index app —
  pull the fault, read its backtrace, find the offending code, write the fix.
  Trigger whenever a request names one Honeybadger error: a pasted fault URL
  (`app.honeybadger.io/projects/…/faults/…`), a fault ID, an error class plus
  "in production" (`Vips::Error`, `NoMethodError in AfterStolenRecordSaveJob`),
  or phrasings like "fix this Honeybadger error", "why is this erroring in
  prod", "what's causing this exception", "look at this HB fault". Use
  `bin/binx_hb` for fault and notice detail; it is the only Honeybadger reader
  this repo uses. Not for a broad production health sweep across many sources,
  and not for reading raw log files (that's production-log-inspection).
---

# Fixing a Honeybadger exception

## Pull the fault with `bin/binx_hb`

Run it from the repo root — `bin/binx_hb` with no arguments prints its own usage.
Two modes matter here: `fault` for the summary, `notice` for the backtrace.

```
bin/binx_hb fault  https://app.honeybadger.io/projects/35931/faults/133010748
bin/binx_hb notice backend/133010748
```

Both take a pasted fault URL or `<project>/<fault_id>`, where project is
`backend`, `frontend`, or `csp`. Each prints `raw: tmp/hb-…json` on its last
line — answer follow-up questions with `jq` against that file rather than
fetching again.

It reads `HONEYBADGER_PERSONAL_AUTH_TOKEN` from `.env.development`. Without it
the command exits saying so — get a new token at honeybadger.io/users/edit and
ask the user to set it. Don't fall back to the `honeybadger` MCP server: its
results land in context with no way to redirect them to a file, and a notice's
`backtrace` field alone can run 130 KB (measured on a Grape API
`Redis::TimeoutError`, 2026-09-01) against the ~700 tokens `binx_hb` projects it
into. Aggregates are covered too — `binx_hb trend` and `binx_hb counts`.

## Read the notice in this order

1. **`message` and `params`** — the failing input is usually right here. For a
   job, `params` holds the Sidekiq hash and `args` names the record to reproduce
   against.
2. **App frames** — the default listing, deepest first. The top frame is where it
   raised, the bottom is the entry point. `[PROJECT_ROOT]` is the repo root.
3. **`--all-frames`** — when the raise is inside a gem and you need the call path
   that reached it.
4. **`deploy`** — the revision live when it fired. A fault created minutes after
   that deploy makes `git show <revision>` the first place to look.

One notice is almost always enough; repeat notices of a fault are near-identical.
Pass `--limit N` only when you suspect the occurrences genuinely differ — a
browser-specific frontend error, or params that vary between failures.

## Then fix it

Decide which kind of fault it is first — the two need different work.

### Deterministic — a bug reachable from the input

- Reproduce from `args`/`params` before changing code — `bundle exec rails
  runner` against the dev database is usually enough.
- Cover the fix with a spec; the `rspec-testing` skill has the house style.
- Check whether the same pattern exists elsewhere. `Errno::ENOENT` in one image
  job usually means every image job shares the bug.

### Transient — a 5xx or timeout from S3/R2, the image CDN, another service

Don't try to reproduce it. The tell is a burst of notices inside a few seconds
and then nothing, with a `message` naming the provider rather than your code.

- Check the job's retry setting first. `config/honeybadger.yml` sets
  `sidekiq.attempt_threshold`, which only drops the first failure of a
  *retryable* job — `retry: false` reports every blip, and `ScheduledJob`
  defaults to it.
- A retry only silences a blip shorter than Sidekiq's first backoff,
  `15 + rand(30)` seconds. Check the notice timestamps against that.
- Check what a mid-operation failure leaves behind — retrying doesn't help work
  that isn't idempotent. `ActiveStorage::Blob#purge` destroys the row before
  deleting the file, so a failed delete orphans the file for good.
- Find prior occurrences by error class, not job name. Honeybadger's `q` doesn't
  match the component field, and a renamed component splits the history.

Don't resolve, ignore, or comment on the fault in Honeybadger — marking it fixed
is the user's call once the fix ships.
