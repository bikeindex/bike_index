---
name: admin-data-api
description: >-
  Pull live production Sidekiq and PgHero status from Bike Index's
  OAuth-authenticated AdminData API (`GET /api/admin_data/sidekiq`,
  `GET /api/admin_data/pghero` on bikeindex.org) — the same data as the
  cookie-gated `/sidekiq` and `/pghero` dashboards, but agent-friendly JSON.
  Trigger when the user asks about production queue depth, job backlog,
  retries/dead jobs, running Sidekiq processes, or Postgres health
  (slow/blocked queries, index usage, unused/invalid indexes, connection
  counts, table/db sizes, vacuum/transaction-id danger) — and wants the
  *live* answer from production rather than logs or Honeybadger. Also trigger
  when a request returns 401/expired and the AdminData token needs
  refreshing/re-authorizing. Not for reading log files (use
  production-log-inspection) or aggregated exception triage (Honeybadger MCP).
---

# AdminData production API

Two OAuth-authenticated JSON endpoints on production, added in `b323f97`:

- `GET https://bikeindex.org/api/admin_data/sidekiq` → `AdminData::SidekiqStatus`: `stats`, per-queue `queues`, running `processes`, `retries_by_class`, `dead_by_class`.
- `GET https://bikeindex.org/api/admin_data/pghero` → `AdminData::PgheroStatus`: `query_stats`, `database_size`, connection/query health, index usage, unused/invalid/duplicate indexes, sequence/txid/autovacuum danger, `settings`, etc. Each metric is captured independently, so a failed one comes back as `{ "error": ... }` in its slot instead of blanking the payload.

Auth is a Bearer token gated on an `admin_data` superuser ability **and** the admin Doorkeeper app. Controller: `app/controllers/api/admin_data_controller.rb`; auth concern: `app/controllers/concerns/api/token_authenticatable.rb`.

All operations go through the helper — run it from the repo root:

```
.claude/skills/admin-data-api/scripts/admin_data.sh <command>
```

## Fetch data

```
.claude/skills/admin-data-api/scripts/admin_data.sh get sidekiq
.claude/skills/admin-data-api/scripts/admin_data.sh get pghero
```

It reads `ADMIN_DATA_TOKEN` from `.env.development`, calls production, and prints `HTTP <status>` then the JSON body. Pipe the body to `jq` for specific fields. Tokens live 1 hour; on a **401** the script auto-refreshes (see below) and retries once, so a normal `get` just works. A **403** means the token's user lacks the `admin_data` superuser ability or the token is from the wrong app. Other non-200s exit non-zero.

Ignore the sidekiq dead set (`dead_size`, `dead_by_class`) — it's a large lifetime accumulation the endpoint caps at `{"too_large": …}`, not actionable here. Don't report it.

### Health-check flow

For a general "how's production" check, run `get sidekiq` first, then automatically run `get pghero` when sidekiq is clean — don't wait to be asked for the second one. For each, if nothing is abnormal, say so in one line and move on; only spell out the metrics that are actually off.

- **Sidekiq is abnormal** when any queue has a backlog (`size > 0`) or real `latency`, `retry_size > 0`, `enqueued` is climbing, a queue is `paused`, `processes` is empty (no workers), or every process is `quiet`. Empty queues with idle-but-running workers is normal — report "nothing abnormal."
- **PgHero is abnormal** when any metric came back as `{"error": …}`, `long_running_queries`/`blocked_queries` is non-empty, a danger metric fires (`sequence_danger`, `transaction_id_danger`, `autovacuum_danger`), there are `invalid_indexes`, or hit rates (`index_hit_rate`, `table_hit_rate`) drop below ~0.98. `unused_indexes`/`duplicate_indexes` are informational, not abnormal.

## Refreshing the token

`.env.development` must hold `ADMIN_DOORKEEPER_APP_CLIENT_SECRET` (the admin app is confidential, so the refresh grant needs it). With it, `get` refreshes automatically on a 401 — you rarely call this directly. To force a refresh:

```
.claude/skills/admin-data-api/scripts/admin_data.sh refresh
```

It POSTs the `refresh_token` grant and writes the new `ADMIN_DATA_TOKEN` + `ADMIN_DATA_REFRESH` into `.env.development` (values never printed).

### First-time setup / dead refresh token (browser flow)

Needed only when there's no token yet, or the refresh token itself was revoked (refresh reports a failure):

1. Print the authorize URL (fills in `ADMIN_DOORKEEPER_APP_CLIENT_ID`):
   ```
   .claude/skills/admin-data-api/scripts/admin_data.sh authorize-url
   ```
2. Ask the user to open it and approve. Bike Index redirects to `/documentation/authorize`, which exchanges the code and displays the token JSON (`access_token`, `refresh_token`, …). Ask the user to paste that response back.
3. Store both values:
   ```
   .claude/skills/admin-data-api/scripts/admin_data.sh set-tokens <access_token> <refresh_token>
   ```

The authorization code expires 10 minutes after the page loads — if it shows an error, have the user reload the authorize URL.

## Notes

- These hit **production** with a superuser token — read-only status only; never a substitute for the log or Honeybadger workflows for their jobs.
- `.env.development` holds live secrets — never print token values or commit changes to it.
