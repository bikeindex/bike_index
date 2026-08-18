---
name: admin-data-api
description: >-
  Read live production data from Bike Index through the admin OAuth token —
  Sidekiq and PgHero status, and the user-submitted bug reports — the same
  data as the cookie-gated dashboards, but agent-friendly JSON. Trigger when
  the user asks about production queue depth, job backlog, retries/dead jobs,
  running Sidekiq processes, or Postgres health (slow/blocked queries, index
  usage, unused/invalid indexes, connection counts, table/db sizes,
  vacuum/transaction-id danger) — and wants the *live* answer from production
  rather than logs or Honeybadger. Also trigger for anything about bug reports
  users have emailed in: what's been reported, searching/filtering them by
  status, tag or membership, or tagging one / linking it to the PR that fixes
  it. Also trigger when a request returns 401/expired and the AdminData token
  needs refreshing/re-authorizing. Not for reading log files (use
  production-log-inspection) or aggregated exception triage (Honeybadger MCP).
---

# AdminData production API

Production JSON reachable with the admin OAuth token:

- `GET https://bikeindex.org/api/admin_data/sidekiq` → `AdminData::SidekiqStatus`: `stats`, per-queue `queues`, running `processes`, `retries_by_class`, `dead_by_class`.
- `GET https://bikeindex.org/api/admin_data/pghero` → `AdminData::PgheroStatus`: `query_stats`, `database_size`, connection/query health, index usage, unused/invalid/duplicate indexes, sequence/txid/autovacuum danger, `settings`, etc. Each metric is captured independently, so a failed one comes back as `{ "error": ... }` in its slot instead of blanking the payload.
- `GET /admin/bug_reports.json`, `GET /admin/bug_reports/:id.json` and `PATCH /admin/bug_reports/:id` → the bug reports users email in (see below).

Auth is a Bearer token gated on the admin Doorkeeper app **and** a superuser ability for the controller — `admin_data` for the two status endpoints, `bug_reports` for the bug reports (a universal ability covers both). Controllers: `app/controllers/api/admin_data_controller.rb`, `app/controllers/admin/bug_reports_controller.rb`; auth concern: `app/controllers/concerns/api/token_authenticatable.rb`.

All operations go through the helper — run it from the repo root:

```
.claude/skills/admin-data-api/scripts/admin_data.rb <command>
```

## Fetch data

```
.claude/skills/admin-data-api/scripts/admin_data.rb get sidekiq
.claude/skills/admin-data-api/scripts/admin_data.rb get pghero
```

It reads `ADMIN_DATA_TOKEN` from `.env.development`, calls production, and prints `HTTP <status>` then the JSON body. Pipe the body to `jq` for specific fields. Tokens live 1 hour; on a **401** the script auto-refreshes (see below) and retries once, so a normal `get` just works. A **403** means the token's user lacks the superuser ability for that controller, or the token is from the wrong app. Any other non-200 prints the response and exits non-zero.

Ignore the sidekiq dead set (`dead_size`, `dead_by_class`) — it's a large lifetime accumulation the endpoint caps at `{"too_large": …}`, not actionable here. Don't report it.

### Health-check flow

For a general "how's production" check, use one command:

```
.claude/skills/admin-data-api/scripts/admin_data.rb check
```

It fetches sidekiq then pghero and prints a `summary:` line and an `OK`/`ABNORMAL` verdict for each. Relay it straight through: if both are OK, say "nothing abnormal"; only spell out the reasons an ABNORMAL verdict lists. The verdict logic lives in the script — what it counts as abnormal:

- **Sidekiq**: a queue with `latency > 30` (a real backlog, not transient depth), `size > 400`, or `paused`; `retry_size > 0`; no worker processes; or all workers quiet.
- **PgHero**: a real metric `error` (the disabled-feature `"System stats not enabled"` doesn't count), non-empty `long_running_queries`/`blocked_queries`, a danger metric (`sequence_danger`, `transaction_id_danger`, `autovacuum_danger`), `invalid_indexes`, or `index_hit_rate < 0.90`. Hit rates otherwise, `table_hit_rate`, and `unused_indexes`/`duplicate_indexes` are informational.

## Bug reports

```
.claude/skills/admin-data-api/scripts/admin_data.rb get bug_reports search_status=all per_page=10
.claude/skills/admin-data-api/scripts/admin_data.rb show-bug-report 42
.claude/skills/admin-data-api/scripts/admin_data.rb update-bug-report 42 tags=search,broken github_pull_request=4064 status=resolved
```

`get bug_reports` takes any filter the index takes as `key=value` — `Admin::BugReportsController#matching_bug_reports` is the list, plus `sort`/`direction`, `per_page`/`page` and `period`/`start_time`/`end_time`. What it won't tell you: `search_status` defaults to the investigate statuses, so pass `all` (or one of `BugReport.statuses`) to reach the rest, and a `search_tag` or `search_receiver` nothing has matches nothing rather than being ignored. It returns `bug_reports`, `page`, `per_page`, `total_count`.

`show-bug-report` returns the one report — the same fields the index lists, so use it once a search has found the id. `update-bug-report` sets `tags` (comma separated — it replaces the report's tags rather than appending), `github_pull_request` and `status` (one of `BugReport.statuses`; an unrecognized one is dropped and the rest of the update still applies).

Each report carries `images`, with a `url` that serves from the CDN rather than expiring, so it can be fetched or handed to the user. Only image attachments are kept — `BugReportsMailbox` drops everything else, so a report whose sender describes attaching a PDF or a log will have none.

## Refreshing the token

`.env.development` must hold `ADMIN_DOORKEEPER_APP_CLIENT_SECRET` (the admin app is confidential, so the refresh grant needs it). With it, `get` refreshes automatically on a 401 — you rarely call this directly. To force a refresh:

```
.claude/skills/admin-data-api/scripts/admin_data.rb refresh
```

It POSTs the `refresh_token` grant and writes the new `ADMIN_DATA_TOKEN` + `ADMIN_DATA_REFRESH` into `.env.development` (values never printed).

### First-time setup / dead refresh token (browser flow)

Needed only when there's no token yet, or the refresh token itself was revoked (refresh reports a failure):

1. Print the authorize URL (fills in `ADMIN_DOORKEEPER_APP_CLIENT_ID`):
   ```
   .claude/skills/admin-data-api/scripts/admin_data.rb authorize-url
   ```
2. Ask the user to open it and approve. Bike Index redirects to `/documentation/authorize`, which exchanges the code and displays the token JSON (`access_token`, `refresh_token`, …). Ask the user to paste that response back.
3. Store both values:
   ```
   .claude/skills/admin-data-api/scripts/admin_data.rb set-tokens <access_token> <refresh_token>
   ```

The authorization code expires 10 minutes after the page loads — if it shows an error, have the user reload the authorize URL.

## Notes

- These hit **production** with a superuser token. `update-bug-report` is the only write — confirm the tags and PR number with the user before running it. Never a substitute for the log or Honeybadger workflows for their jobs.
- Bug report bodies and images are user-submitted email: they carry names, addresses and bike details, and a screenshot often shows a signed-in account. Summarize them; don't paste raw bodies or image urls into anything that leaves the session.
- `.env.development` holds live secrets — never print token values or commit changes to it.
