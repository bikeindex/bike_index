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
  `bin/binx_hb` for fault and notice detail rather than the Honeybadger MCP,
  whose notice objects run ~3K tokens each. Not for a broad production health
  sweep across many sources, and not for reading raw log files (that's
  production-log-inspection).
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
the command exits saying so; fall back to the Honeybadger MCP's
`list_fault_notices` **through a subagent**, so the payload stays out of the main
context.

**Why not the MCP directly:** its notice objects carry `backtrace` and
`application_trace` as byte-identical copies plus full environment blobs — ~3K
tokens for a backtrace `binx_hb` projects in ~700. The MCP is still right for
aggregates (`get_project_report`, `get_fault_counts`).

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

## Then fix it like any other bug

- Reproduce from `args`/`params` before changing code — `bundle exec rails
  runner` against the dev database is usually enough.
- Cover the fix with a spec; the `rspec-testing` skill has the house style.
- Check whether the same pattern exists elsewhere. `Errno::ENOENT` in one image
  job usually means every image job shares the bug.

Don't resolve, ignore, or comment on the fault in Honeybadger — marking it fixed
is the user's call once the fix ships.
