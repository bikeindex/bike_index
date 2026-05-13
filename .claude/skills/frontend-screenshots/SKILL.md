---
name: frontend-screenshots
description: >-
  Capture desktop+mobile screenshots of Bike Index pages in the running
  `bin/dev` server using Playwright MCP. Owns the capture mechanics: viewport
  sizing, sign-in via seeded credentials, the seeded-user identity gate that
  protects against PII leakage from the dev DB, sanity-checking PNGs, and
  (optionally) capturing the same URLs on a different branch for before/after
  comparison. Trigger when a task needs to produce viewport screenshots of
  local pages — PR documentation, bug repros, design review, demos. The
  caller decides which URLs to capture and what to do with the resulting
  files; this skill only produces them.
allowed-tools: Bash, Read
---

# Capture frontend screenshots

Drive Playwright MCP to capture desktop and mobile screenshots of pages served by the user's `bin/dev`. Returns local file paths the caller can upload, embed, or diff.

## Inputs the caller supplies

- A list of `(url-path, page-slug)` pairs to capture. `url-path` is the path component (e.g. `/o/hogwarts/dashboard`). `page-slug` is a short identifier used in filenames (e.g. `hogwarts-dashboard`).
- Optionally: a branch label (default: `<current-branch>`). When capturing the same URLs on `main` for comparison, pass `main` so the filenames are distinct from the branch shots.

## Output

PNG files at `tmp/pr_screenshots/<branch>-<page>-<timestamp>-{desktop,mobile}.png`, where:
- `<branch>=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')` (or the explicit label the caller passed for cross-branch capture, with `-main` appended)
- `<timestamp>=$(date +%Y%m%d-%H%M%S)`

Return the absolute paths, keyed by `(page-slug, viewport)`.

## Workflow

### 1. Verify Playwright MCP is available

Check that `mcp__playwright__*` tools are registered. If not, tell the user:

```
claude mcp add playwright -- npx -y @playwright/mcp@latest
```

…and that the Claude Code session must be restarted afterward.

### 2. Verify the dev server is up

Run `eval "$(ruby bin/env --export)"` once so `$BASE_URL` is set, then:

```bash
curl -fs "$BASE_URL/" >/dev/null
```

**Never start or stop `bin/dev` for the user.** The dev server is the user's process. Starting your own copy can land you on a different DB; stopping theirs interrupts work. If it isn't up, **stop and ask the user to start it** (`bin/dev` from their own terminal), then resume once they confirm.

### 3. Sign in if needed (with the identity gate)

Navigate to the first URL. If it lands on `/session/new` or `/session/magic_link`, sign in with seeded credentials by driving the form via Playwright (don't ask the user to do it manually). Pick the user that exposes the menus/views the caller needs:

- `admin@bikeindex.org` / `pleaseplease12` — has `SuperuserAbility`; the superuser shortcut makes them admin of every org (so they see admin-only menu items + the "Super Admin" link).
- `member@bikeindex.org` / `pleaseplease12` — `member` (not admin) of `Hogwarts`; useful for a non-admin perspective on the same fully-loaded org `admin@` uses.
- `cannondale@bikeindex.org` / `pleaseplease12` — admin of `Cannondale` (manufacturer org).

Seeded orgs to navigate to:
- **Hogwarts** (`/o/hogwarts/...`) has every org feature except `official_manufacturer` enabled — the right pick when you want the fully-loaded org sidebar/menu.
- **Ike's Bikes** (`/o/ikes`) has no features and no admin — useful for minimal-menu shots.
- **Cannondale** (`/o/cannondale`) has `official_manufacturer`.

**Verify the signed-in identity is one of the seeded users before continuing.** The dev DB could leak PII — see `feedback_no_programmatic_auth_for_screenshots.md`. The application layout renders the current user's email on `#navUserSettingLink` via a `data-email` attribute (`app/views/layouts/application.html.erb`), so any authenticated page works for the check:

```js
const email = document.getElementById('navUserSettingLink')?.dataset.email;
const ok = ["admin@bikeindex.org", "member@bikeindex.org", "cannondale@bikeindex.org"].includes(email);
```

If `email` is `undefined`, the page is unauthenticated — sign in first. If it's set but isn't one of the three, **stop and ask the user**. Two cases:
- *Signed in as a non-seed user* — the dev DB may have some real data; uploading screenshots could leak PII.
- *Sign-in with seed credentials failed* — the seeds haven't run. Tell the user to run `bundle exec rails db:seed` (and re-sign in once it completes), then try again.

Don't proceed past this gate without the user's explicit go-ahead.

### 4. Capture loop

Capture in two passes so each viewport is resized only once. Before capturing, remove stale shots for the same `(branch, page)` prefix (use a glob the shell may not match — guard with `2>/dev/null || true`).

1. `browser_resize` → 1440×900 (desktop). For each page, `browser_navigate` to `$BASE_URL<url-path>` then `browser_take_screenshot` to `...-desktop.png`.
2. `browser_resize` → 390×844 (iPhone-class mobile). For each page, `browser_navigate` to the same URL then `browser_take_screenshot` to `...-mobile.png`.

**Always use `fullPage: false` and never element-only (no `target:` arg).** The screenshot must show the page as it renders in a browser of that viewport size — the chrome around the changed element matters for context. Two failure modes to avoid:

- `fullPage: true` produces a "scroll-the-whole-page" image — on mobile that's typically 2000–3000px tall with the interesting content sitting in the first 800px and the rest just being a desaturated background scroll. Not how a phone renders.
- `target: <element ref>` (the element-only screenshot) crops to the bounding box of one DOM node. For something tall and narrow like a sidebar nav, that produces a comically thin column (e.g. 216×2025) sliced out of context. Reviewers can't tell where it sits on the page or whether the surrounding layout is right.

Both cases: capture the viewport instead.

### 5. Sanity-check each PNG and diagnose failures

A file under ~5 KB usually means the page errored. Also check `browser_console_messages` for uncaught JS errors. Diagnose:

1. `curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/<path>"` to get the HTTP status.
2. `curl -s "$BASE_URL/<path>" | head -200` to see the response body (usually a Rails error page with the exception and top of the backtrace).
3. `tail -200 log/development.log` for the full backtrace and any SQL involved.
4. Based on what you find: route missing → re-check the path; auth/redirect → pick a URL that doesn't require login or sign in; missing fixture → pick a different id or seed it; genuine bug in the diff → fix it or tell the user.

Only stop and surface to the user once you understand the cause and either (a) have a fix to propose, (b) need input they must provide (e.g. which URL to screenshot instead), or (c) concluded it's a real bug.

### 6. (Optional) Capture the same URLs on another branch

When the caller wants a before/after comparison, repeat steps 4–5 against a different branch — typically `main` for PR comparisons. Do this without disturbing the user's working tree or dev server:

1. `git status` — confirm there are no uncommitted changes. If there are, stop and surface to the user.
2. Note the current branch: `BRANCH=$(git rev-parse --abbrev-ref HEAD)`.
3. `git checkout main` — Rails dev mode auto-reloads on file changes; the dev server stays up.
4. Repeat step 4's two-viewport capture loop, this time writing to `tmp/pr_screenshots/<branch>-<page>-main-<timestamp>-{desktop,mobile}.png` (note the extra `-main` segment — `<branch>` is still the original branch name, so the files cluster together by PR).
5. `git checkout $BRANCH` to return — verify the working tree is clean and on the original branch.

The seeded credentials and DB persist across checkouts, so re-signing in usually isn't needed; the identity gate from step 3 still applies if the session expired.

## Notes

- The MCP browser session persists across calls, so sign-in is a one-time step per Claude Code session.
- If Playwright MCP fails partway through, return whatever PNGs were successfully captured along with the failure context. The caller decides whether to retry or proceed without the missing shots.
- Filename convention is load-bearing: callers (the `pr` skill, `github-upload-image-to-pr`) infer page and viewport from the path. Don't reformat without updating callers.
