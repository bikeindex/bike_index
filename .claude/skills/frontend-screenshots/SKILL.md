---
name: frontend-screenshots
description: >-
  Capture desktop+mobile viewport screenshots of Bike Index pages from the
  local `bin/dev` server via Playwright MCP, with a seeded-user identity gate
  that keeps PII out of uploaded images. Use whenever a task needs screenshots
  of local pages — PR documentation, bug repros, before/after comparisons
  across branches, design review, demos — even when the user just says "grab
  a screenshot" or "show me what this looks like" without naming Playwright.
  Inputs: `(url-path, page-slug)` pairs. Output: local PNG paths.
allowed-tools: Bash, Read
---

# Frontend screenshots

Drive Playwright MCP to capture viewport screenshots of pages served by `bin/dev`.

## Output filenames (load-bearing — callers parse these)

`tmp/pr_screenshots/<branch>-<page>-<timestamp>-{desktop,mobile}.png`, where `<branch>=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')` and `<timestamp>=$(date +%Y%m%d-%H%M%S)`. Cross-branch shots get an extra `-main-` segment.

## Preflight

- `eval "$(ruby bin/env --export)"` so `$BASE_URL` is set.
- `curl -fs "$BASE_URL/" >/dev/null` — if not up, start `bin/dev` yourself in the background (`run_in_background: true`) from the workspace directory and wait for `$BASE_URL/` to become reachable before continuing. `bin/env` resolves `$DEV_PORT`/`$BASE_URL` from the workspace ID, so the bin/dev you start binds to the same port and DB the user expects.
- If `mcp__playwright__*` tools aren't registered, tell the user to run `claude mcp add playwright -- npx -y @playwright/mcp@latest` and restart.

## Sign in (with the PII gate)

Pick the user the caller specified, or default to `user@bikeindex.org` (lowest privilege; most non-org-affiliated pages render for them). All seeded users use password `pleaseplease12`:

- `user@bikeindex.org` — no org memberships. Default. Use for personal pages (`/my_account`, `/bikes/new`) or to show how an org-less account sees a route.
- `member@bikeindex.org` — `member` (not admin) of Hogwarts. Use to capture the non-admin view of an org.
- `admin@bikeindex.org` — `SuperuserAbility`; effectively admin of every org. Use when capturing admin-only menu items, `/admin/...` routes, or org pages where you want the fully-loaded sidebar.
- `:anonymous` — skip sign-in entirely. Use for public pages where the signed-out rendering is the point.

If a URL redirects to `/session/new` or `/session/magic_link`, drive the form via Playwright — don't ask the user to sign in manually.

**Picking an org slug.** When the URL is org-scoped (`/o/<slug>/...`) and the caller didn't specify a slug, default to `hogwarts`

**Verify identity before capturing.** The dev DB can contain real-looking data (see `feedback_no_programmatic_auth_for_screenshots.md`). Check:

```js
document.getElementById('navUserSettingLink')?.dataset.email
```

If it's set but not one of the three seeded emails, **stop and ask** — either you're signed in as a non-seed user (PII risk on upload) or the seeds haven't run (`bundle exec rails db:seed`). For `:anonymous`, expect `undefined` and confirm before continuing.

## Capture

Clear stale shots: `rm -f tmp/pr_screenshots/<branch>-<page>-*.png 2>/dev/null || true`.

Two viewports — resize once each, then walk every URL:
1. `browser_resize` 1440×900 → for each URL: navigate → settle → `browser_take_screenshot` (`fullPage: false`) to `...-desktop.png`.
2. `browser_resize` 390×844 → same loop → `...-mobile.png`.

**`fullPage: false` and no `target:` arg.** Reviewers need the page as a browser of that size actually renders it. `fullPage: true` produces a 2000–3000px scroll capture (not how mobile renders); element-only crops slice context off.

**Settle before the screenshot.** Stimulus + Chartkick render after document load; either `browser_wait_for` on a known element or pause ~500ms–1s. Otherwise charts capture mid-draw.

Sanity-check each PNG: under ~5 KB usually means the page errored. Pull `browser_console_messages` and look only for **uncaught exceptions from app code** (Stimulus registration failures, `TypeError`s in `app/javascript/**`) — Webpacker logs, asset 404s, third-party deprecation warnings are noise. To diagnose a failed capture: HTTP status via `curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/<path>"`, response body via `curl -s "$BASE_URL/<path>" | head -200`, full backtrace via `tail -200 log/development.log`.

## Cross-branch comparison (optional)

When the caller wants before/after, repeat the capture loop against `main`. **Only safe for view/CSS/Stimulus diffs** — if the branch has new `db/migrate/` files or `Gemfile.lock` changes, `git checkout main` leaves the running dev server inconsistent. Abort the main capture and tell the caller.

1. `git status` — abort if there are uncommitted changes.
2. Diff `db/migrate/` and `Gemfile.lock` between the branch and `main`; abort if either changed.
3. `BRANCH=$(git rev-parse --abbrev-ref HEAD)`, `git checkout main`, repeat capture into `...-main-...` filenames, `git checkout $BRANCH`.

The seeded DB persists across checkouts, so the existing session usually still works.

## Clean up

Once every screenshot is captured, quit Chrome with `browser_close`. Leaving it running holds the shared browser profile lock, so the next `browser_navigate` (this skill or another) fails with "Browser is already in use". Always close it before returning, even if the capture failed partway.
