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

It reads `ADMIN_DATA_TOKEN` from `.env.development`, calls production, and prints `HTTP <status>` then the JSON body. Pipe the body to `jq` for specific fields. On a non-200 the script exits non-zero — a **401** (`OAuth token required`) means the token is missing or expired (tokens live 1 hour); a **403** means the token's user lacks the `admin_data` superuser ability or the token is from the wrong app.

## Get / refresh the token (401 or expired)

The token is a standard authorization-code grant. The reliable path is the browser flow:

1. Print the authorize URL (fills in `ADMIN_DOORKEEPER_APP_CLIENT_ID` from `.env.development`):
   ```
   .claude/skills/admin-data-api/scripts/admin_data.sh authorize-url
   ```
2. Ask the user to open it and sign in / approve. Bike Index redirects to `/documentation/authorize`, which exchanges the code and displays the token JSON (`access_token`, `refresh_token`, `expires_in`, …). Ask the user to paste that response back.
3. Store both values:
   ```
   .claude/skills/admin-data-api/scripts/admin_data.sh set-tokens <access_token> <refresh_token>
   ```
   This upserts `ADMIN_DATA_TOKEN` and `ADMIN_DATA_REFRESH` in `.env.development`.
4. Re-run the `get`.

The authorization code expires in 10 minutes — if step 2 shows an expired/error response, have the user reload the authorize URL for a fresh one.

### Optional: refresh without the browser

If `.env.development` also has `ADMIN_DOORKEEPER_APP_CLIENT_SECRET` (the admin app is confidential, so the refresh grant needs it), skip the browser:

```
.claude/skills/admin-data-api/scripts/admin_data.sh refresh
```

It POSTs the `refresh_token` grant and prints the new token JSON; feed the returned `access_token`/`refresh_token` into `set-tokens`. Without the secret this exits with a note to use the browser flow.

## Notes

- These hit **production** with a superuser token — read-only status only; never a substitute for the log or Honeybadger workflows for their jobs.
- `.env.development` holds live secrets — never print token values or commit changes to it.
