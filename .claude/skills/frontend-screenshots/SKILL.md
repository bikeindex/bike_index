---
name: frontend-screenshots
description: >-
  Capture desktop+mobile screenshots of Bike Index pages from the running
  `bin/dev` server via Playwright MCP, with a built-in seeded-user identity
  gate that prevents the dev DB from leaking PII into uploaded images. Use
  this whenever a task needs viewport screenshots of local pages — PR
  documentation, bug repros, before/after comparisons across branches, design
  review, demos, even when the user just says "grab a screenshot" or "show me
  what this looks like" without naming Playwright. Handles dev-server check,
  sign-in with seeded credentials, viewport sizing (desktop 1440×900 +
  iPhone-class 390×844), per-PNG sanity checks, and optional cross-branch
  capture. The caller passes `(url-path, page-slug)` pairs; the skill returns
  local PNG paths.
allowed-tools: Bash, Read
---

# Capture frontend screenshots

Drive Playwright MCP to capture desktop and mobile screenshots of pages served by the user's `bin/dev`. Returns local file paths the caller can upload, embed, or diff.

## Inputs the caller supplies

- A list of `(url-path, page-slug)` pairs to capture. `url-path` is the path component (e.g. `/o/hogwarts/dashboard`). `page-slug` is a short identifier used in filenames (e.g. `hogwarts-dashboard`).
- Optionally: which seeded user to sign in as, or `:anonymous` to deliberately capture signed-out. Default to `admin@bikeindex.org` since its `SuperuserAbility` shortcut gives it access to every org and shows all admin-only menu items. Override when the caller specifically needs a non-admin perspective (e.g., `member@bikeindex.org` for a non-admin view of Hogwarts) or a signed-in-but-not-in-any-org perspective (`user@bikeindex.org` — useful for personal pages like `/my_account`, `/bikes/new`, or anything that should render without org context). Use `:anonymous` for public pages where the signed-out rendering is what matters (marketing pages, public bike show, public search).
- Optionally: a branch label, used in filenames. Defaults to the current branch. When the caller wants cross-branch comparison (step 6), passing `main` produces filenames with an extra `-main-` segment so the shots cluster with the originals but stay distinguishable.

## Output

PNG files at `tmp/pr_screenshots/<branch>-<page>-<timestamp>-{desktop,mobile}.png`, where `<branch>=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')` and `<timestamp>=$(date +%Y%m%d-%H%M%S)`. Cross-branch shots get an extra `-main-` segment: `<branch>-<page>-main-<timestamp>-{desktop,mobile}.png`.

Return the absolute paths, keyed by `(page-slug, viewport)`.

## Preconditions

These run first; if either fails the skill stops before touching Playwright.

**Playwright MCP is registered.** Check that `mcp__playwright__*` tools are available. If not, tell the user to run `claude mcp add playwright -- npx -y @playwright/mcp@latest` and restart the Claude Code session. Don't try to work around it.

**Dev server is up.** Run `eval "$(ruby bin/env --export)"` once so `$BASE_URL` is set, then `curl -fs "$BASE_URL/" >/dev/null`. Never start or stop `bin/dev` for the user — the dev server is the user's process; starting your own copy can land on a different DB, and stopping theirs interrupts work. If it isn't up, stop and ask the user to start it from their own terminal, then resume once they confirm.

## Workflow

### 1. Sign in (with the identity gate)

Pick the seeded user — the one the caller specified, or `admin@bikeindex.org` by default. Seeded credentials:

| User | Password | Role |
| --- | --- | --- |
| `admin@bikeindex.org` | `pleaseplease12` | `SuperuserAbility`; effectively admin of every org. Default. |
| `member@bikeindex.org` | `pleaseplease12` | `member` (not admin) of Hogwarts |
| `user@bikeindex.org` | `pleaseplease12` | Plain authenticated user, not a member of any org — use for personal pages (`/my_account`, `/bikes/new`, etc.) or to capture how an org-less account sees a route |

Navigate to the first URL. Three cases:

1. **Caller asked for `:anonymous`** — if the page redirects to `/session/new` or `/session/magic_link`, the caller picked an authenticated route by mistake; stop and ask them. Otherwise, confirm `document.getElementById('navUserSettingLink')?.dataset.email` is `undefined`, then capture as signed-out.
2. **Page redirects to `/session/new` or `/session/magic_link`** — sign in by driving the form via Playwright (don't ask the user to do it manually) with the chosen user's credentials.
3. **Page renders authenticated** (session already live from a prior call) — proceed straight to the identity check below.

After sign-in, **verify the signed-in identity is one of the seeded users before capturing anything**. The dev DB could leak PII — see `feedback_no_programmatic_auth_for_screenshots.md`. The application layout exposes the current user's email on `#navUserSettingLink` via a `data-email` attribute:

```js
const email = document.getElementById('navUserSettingLink')?.dataset.email;
const ok = ["admin@bikeindex.org", "member@bikeindex.org", "user@bikeindex.org"].includes(email);
```

If `email` is set but isn't one of the seeded users above, **stop and ask the user**. Two cases to distinguish:
- *Signed in as a non-seed user* — the dev DB may have some real data; uploading screenshots could leak PII.
- *Sign-in with seed credentials failed* — the seeds haven't run. Tell the user to run `bundle exec rails db:seed` (and re-sign in once it completes), then try again.

Don't proceed past this gate without the user's explicit go-ahead.

### 2. Capture loop

Before capturing, remove stale shots for the same `(branch, page)` prefix:

```bash
rm -f tmp/pr_screenshots/<branch>-<page>-*.png 2>/dev/null || true
```

Capture in two passes so each viewport is resized only once:

1. `browser_resize` → 1440×900 (desktop). For each page, `browser_navigate` to `$BASE_URL<url-path>`, wait for the page to settle (see below), then `browser_take_screenshot` to `...-desktop.png`.
2. `browser_resize` → 390×844 (iPhone-class mobile). Repeat the navigate-wait-screenshot loop, writing to `...-mobile.png`.

**Settle before each screenshot.** Stimulus controllers and chart libraries (Chartkick, etc.) finish rendering asynchronously after the document loads. Either `browser_wait_for` on a known element from the page (e.g., a chart's `.chartjs-render-monitor` or a heading specific to the page) or pause briefly (~500ms–1s) before capturing. Pages with lazy renderers will otherwise come out mid-draw.

**Always use `fullPage: false` and no `target:` arg.** The screenshot must show the page as it renders in a browser of that viewport size — `fullPage: true` produces an unrepresentative 2000–3000px scroll capture, and element-only crops slice context off (a sidebar nav becomes a 216×2025 column nobody can place). Both flatten the reviewer's mental model of where the change sits on the page.

### 3. Sanity-check each PNG and diagnose failures

A file under ~5 KB usually means the page errored. Also pull `browser_console_messages` and look for **uncaught exceptions from app code** — Stimulus controllers that fail to register, missing `data-controller` targets, `TypeError`s in `app/javascript/**`. Treat those as capture failures. Ignore noise: Webpacker logs, asset 404s, third-party deprecation warnings, the `404 chartjs-plugin-style-…` line that some chart libraries emit. They're routine and don't indicate the captured page is broken.

Diagnose a failed PNG:

1. `curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/<path>"` for the HTTP status.
2. `curl -s "$BASE_URL/<path>" | head -200` for the response body (usually a Rails error page with the exception and top of the backtrace).
3. `tail -200 log/development.log` for the full backtrace and any SQL involved.
4. Based on what you find: route missing → re-check the path; auth/redirect → sign in or pick a different URL; missing fixture → pick a different id or seed it; genuine bug in the diff → fix it or tell the user.

Only stop and surface to the user once you understand the cause and either (a) have a fix to propose, (b) need input they must provide (e.g., which URL to screenshot instead), or (c) concluded it's a real bug.

### 4. (Optional) Capture the same URLs on another branch

When the caller wants a before/after comparison, repeat steps 2–3 against a different branch — typically `main` for PR comparisons.

**This is safe for view/CSS/Stimulus diffs only.** If the branch has new database migrations or `Gemfile.lock` changes, `git checkout main` leaves the running server inconsistent — DB schema ahead of code, or a `LoadError` for a gem the branch added. In that case, skip the main capture and tell the caller the comparison isn't safe to take; capture only the branch shots.

To capture cleanly:

1. `git status` — confirm there are no uncommitted changes. If there are, stop and surface to the user.
2. Diff `db/migrate/` and `Gemfile.lock` between the branch and `main`. If either has changed, abort the main capture as above.
3. Note the current branch: `BRANCH=$(git rev-parse --abbrev-ref HEAD)`.
4. `git checkout main` — Rails dev mode auto-reloads on view/code changes; the dev server stays up.
5. Repeat step 2's two-viewport capture loop, writing to `tmp/pr_screenshots/<branch>-<page>-main-<timestamp>-{desktop,mobile}.png` (note: `<branch>` is still the original branch name, so the files cluster together by PR).
6. `git checkout $BRANCH` to return — verify the working tree is clean and on the original branch.

The seeded credentials and DB rows persist across checkouts, so re-signing in usually isn't needed; the identity gate from step 1 still applies if the session expired.

## Notes

- The MCP browser session persists across calls, so sign-in is a one-time step per Claude Code session.
- If Playwright MCP fails partway through, return whatever PNGs were successfully captured along with the failure context. The caller decides whether to retry or proceed without the missing shots.
- Filename convention is load-bearing: callers (the `pr` skill, `github-upload-image-to-pr`) infer page and viewport from the path. Don't reformat without updating callers.
