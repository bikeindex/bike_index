---
name: frontend-screenshots
description: >-
  Capture desktop+mobile viewport screenshots of Bike Index pages from the
  local `bin/dev` server via Playwright MCP, with a seeded-user identity gate
  that keeps PII out of uploaded images. Use whenever a task needs screenshots
  of local pages — PR documentation, bug repros, before/after comparisons
  across branches, design review, demos — including mid-interaction states
  like an open dropdown, a modal showing, a form mid-fill, or a hover. Use it
  even when the user just says "grab a screenshot" or "show me what this looks
  like" without naming Playwright. For a component that only renders under an
  env var / feature flag / hard-to-reach state (e.g. the review-app banner),
  screenshot its ViewComponent/Lookbook preview URL instead of a full page.
  Inputs: `(url-path, page-slug)` pairs, optionally with per-URL interaction
  steps. Output: local PNG paths.
allowed-tools: Bash, Read
---

# Frontend screenshots

Drive Playwright MCP to capture viewport screenshots of pages served by `bin/dev`.

## Output filenames (load-bearing — callers parse these)

`tmp/pr_screenshots/<branch>-<page>-<timestamp>-{desktop,mobile}.png`, where `<branch>=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')` and `<timestamp>=$(date +%Y%m%d-%H%M%S)`. Cross-branch shots get an extra `-base-` segment.

## Preflight

- `eval "$(ruby bin/env --export)"` so `$BASE_URL` is set.
- `curl -fs "$BASE_URL/" >/dev/null` — if it isn't, **stop and ask the user to start it**. `bin/env` resolves `$DEV_PORT`/`$BASE_URL` from the workspace ID, so the bin/dev the user starts will bind to the same port and DB this skill expects.
- If `mcp__playwright__*` tools aren't registered, tell the user to run `claude mcp add playwright -- npx -y @playwright/mcp@latest` and restart.

## Sign in (with the PII gate)

Pick the user the caller specified, or default to `user@bikeindex.org` (lowest privilege; most non-org-affiliated pages render for them). All seeded users use password `pleaseplease12`:

- `user@bikeindex.org` — no org memberships. Default. Use for personal pages (`/my_account`, `/bikes/new`) or to show how an org-less account sees a route.
- `member@bikeindex.org` — `member` (not admin) of Brakebills. Use to capture the non-admin view of an org.
- `admin@bikeindex.org` — `SuperuserAbility`; effectively admin of every org. Use when capturing admin-only menu items, `/admin/...` routes, or org pages where you want the fully-loaded sidebar.
- `:anonymous` — skip sign-in entirely. Use for public pages where the signed-out rendering is the point.

Signed-out is the normal starting state, **not** a blocker: if a page redirects to `/session/new` or `/session/magic_link` (or `#navUserSettingLink` has no email), drive the sign-in form via Playwright with the seed credentials above — don't ask the user to sign in manually, and don't skip the screenshot for lack of a session. **Only ever authenticate against the local dev server** (`$BASE_URL` / localhost) — never sign in to any other host, and never create, promote, or impersonate users to bypass auth.

**Picking an org slug.** When the URL is org-scoped (`/o/<slug>/...`) and the caller didn't specify a slug, default to `brakebills`

**Verify identity before capturing.** The gate isn't about *whether* to authenticate — signing in with seed credentials is expected. It's about confirming the session and its data are seed-only, so no PII lands in an uploaded image. After signing in, check:

```js
document.getElementById('navUserSettingLink')?.dataset.email
```

If it's set but not one of the seeded emails, **stop and ask** — you're signed in as a non-seed user (PII risk on upload). If it's `undefined` when you expected a session, sign-in didn't take (often the seeds haven't run — `bundle exec rails db:seed`); retry the sign-in, don't capture signed-out. For `:anonymous`, expect `undefined` and confirm before continuing.

**Don't capture if any on-page data looks non-seeded.** Even signed in as a seed user, if a page shows records that don't look like seed data (unfamiliar names/emails, real-looking user content), stop and ask — the dev DB may have been loaded with production data, and screenshots are permanent once uploaded.

## Capture

Clear stale shots: `rm -f tmp/pr_screenshots/<branch>-<page>-*.png 2>/dev/null || true`.

Two viewports — resize once each, then walk every URL:
1. `browser_resize` 1440×900 → for each URL: navigate → settle → hide the footer → `browser_take_screenshot` (`fullPage: true`) to `...-desktop.png`.
2. `browser_resize` 390×844 → same loop → `...-mobile.png`.

**Full page, minus the footer and review-app banner, no `target:` arg.** Capture the whole page (`fullPage: true`) so nothing below the fold is cut off, but first hide the site footer (identical on every page, just padding) and the `#review-app-banner` topbar (dev/review-app-only chrome that isn't part of the real page). After each navigation (hiding doesn't persist across page loads), run:

```js
browser_evaluate: () => {
  document.querySelector('.primary-footer, footer, [role="contentinfo"]')?.style.setProperty('display', 'none');
  document.getElementById('review-app-banner')?.style.setProperty('display', 'none');
  return document.body.scrollHeight; // content height with the footer + banner gone
}
```

If the returned content height is **less than the viewport height**, `browser_resize` the height down to it before the shot (the `<html>` element's near-black background fills the gap otherwise), then resize back to the standard viewport before the next URL. Taller-than-viewport pages need no resize — `fullPage` scroll-stitches them.

Element-only crops (`target:`) still slice context off — don't use them for page captures.

**Settle before the screenshot.** Stimulus + Chartkick render after document load; either `browser_wait_for` on a known element or pause ~500ms–1s. Otherwise charts capture mid-draw.

**Mid-interaction states are in scope.** When the caller asks for a dropdown open, a modal showing, a hover state, a partially-filled form, etc., drive Playwright between settle and the screenshot — `browser_click`, `browser_type`, `browser_press_key`, `browser_hover`, then wait for the UI to reach the target state (`browser_wait_for` on a marker element, or check via `browser_evaluate`) before `browser_take_screenshot`. Treat the interaction sequence as part of the page-slug — e.g. capture `combobox-open` after clicking + typing, distinct from a static `search-registrations` page-load shot. For cross-branch comparisons, run the *same* interaction sequence on each branch so the screenshots actually compare like-for-like.

Sanity-check each PNG: under ~5 KB usually means the page errored. Pull `browser_console_messages` and look only for **uncaught exceptions from app code** (Stimulus registration failures, `TypeError`s in `app/javascript/**`) — Webpacker logs, asset 404s, third-party deprecation warnings are noise. To diagnose a failed capture: HTTP status via `curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/<path>"`, response body via `curl -s "$BASE_URL/<path>" | head -200`, full backtrace via `tail -200 log/development.log`.

## Component previews (when no page shows the state)

Some components only render in a context you can't reproduce on a normal dev page — gated by an env var (e.g. the review-app banner needs `REVIEW_APP`), a feature flag, or a hard-to-reach error/empty state. When a component has a ViewComponent/Lookbook preview, screenshot the **preview URL** instead of hunting for a page that happens to render it:

```
$BASE_URL/rails/view_components/<preview_path>/<scenario>
```

`<preview_path>` is the preview class underscored with the `Preview` suffix dropped, and `<scenario>` is the preview method. `PageBlock::ReviewAppBanner::ComponentPreview#superadmin_signed_in` → `/rails/view_components/page_block/review_app_banner/component/superadmin_signed_in`. If a scenario doesn't exist yet, add a method to the component's `*_preview.rb` first — a preview that renders the exact state (pass the args that trigger it) is often the fastest path to a clean shot.

Use this bare route, not Lookbook's `/lookbook/...`, which wraps the component in its own browser chrome.

The preview page loads Tailwind and renders the component standalone (no site chrome), so capture the viewport as usual (`fullPage: false`); a small ViewComponent render-timing line at the bottom is harmless. Everything else still applies — same PII/seed-data gate, same `(url-path, page-slug)` naming (use a slug like `banner-signed-in`).

Previews that query the dev DB (e.g. `User.admins.first`) render nothing when that data is missing — if the state doesn't appear, seed first with `bundle exec rails db:seed`. This is component-only: a preview can't show layout/stacking against the rest of the page (e.g. a navbar z-index fix), so use a real page for those.

## Cross-branch comparison (optional)

When the caller wants before/after, repeat the capture loop against the base ref. The caller passes the base — `origin/main` by default, or the PR's actual base when it isn't `main` (a stacked PR's base often isn't). Set `BASE_REF` to that remote ref (e.g. `origin/main`, `origin/sethherr/feature-x`) and use it throughout; `git fetch origin` first so it's current.

1. `git status` — abort if there are uncommitted changes.
2. Check the branch's migrations, and abort if one takes something away from the base's code rather than adding to it. Read the `up`/`change` body only — nearly every additive migration undoes itself in `down`, so scanning whole files false-aborts on all of them:

   ```bash
   for f in $(git diff "$BASE_REF"...HEAD --name-only --diff-filter=AM -- db/migrate db/analytics_migrate); do
     git show "HEAD:$f" | sed -E -n '/def (up|change)/,/^  end/p' |
       grep -E 'remove_|rename_|drop_|change_column|null: false' | sed "s|^|$f: |"
   done
   ```

   Judge the hits, don't count them — this surfaces candidates, it doesn't reach the verdict. Dropping, renaming or retyping a column or table aborts, because the base still selects it. An index change doesn't, since no query names an index. `null: false` aborts only without a `default:`, which would break the base's writes rather than its reads.

   Never roll a migration back to capture the base — that churns the dev DB for a screenshot.
3. `BRANCH=$(git rev-parse --abbrev-ref HEAD)`, `git checkout --detach $BASE_REF` (detached — checking out a branch name fails if a sibling worktree holds it; detached HEAD at the remote ref is allowed concurrently and is the same code), navigate the browser to force Rails to reload the changed files, repeat capture into `...-base-...` filenames, then `git checkout $BRANCH`.

A `Gemfile.lock` diff is **not** a reason to abort.

The seeded DB persists across checkouts, so the existing session usually still works — and the base renders rows the branch created, which is worth a line in the PR comment when that makes the base mislabel one. Preview routes (`/rails/view_components/...`, `/lookbook/...`) reload across the checkout like ordinary pages, so their before/after works against any `$BASE_REF` too.

## Clean up

Once every screenshot is captured, quit Chrome with `browser_close`. Leaving it running holds the shared browser profile lock, so the next `browser_navigate` (this skill or another) fails with "Browser is already in use". Always close it before returning, even if the capture failed partway.
