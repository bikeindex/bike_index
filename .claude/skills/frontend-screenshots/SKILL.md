---
name: frontend-screenshots
description: >-
  Capture desktop+mobile screenshots of Bike Index pages from the
  local `bin/dev` server via Playwright MCP, with a seeded-user identity gate
  that keeps PII out of uploaded images. Use whenever a task needs screenshots
  of local pages — PR documentation, bug repros, before/after comparisons
  across branches, design review, demos — including mid-interaction states
  like an open dropdown, a modal showing, a form mid-fill, or a hover. Use it
  even when the user just says "grab a screenshot" or "show me what this looks
  like" without naming Playwright. For a component that only renders under an
  env var / feature flag / hard-to-reach state (e.g. the review-app banner),
  screenshot its ViewComponent/Lookbook preview URL instead of a full page.
  **Also read the filename rule here before any
  `mcp__playwright__browser_take_screenshot` call**, including a one-off
  capture of some other site — it's what keeps PNGs out of the working tree.
allowed-tools: Bash, Read, ToolSearch, mcp__playwright__browser_navigate, mcp__playwright__browser_resize, mcp__playwright__browser_evaluate, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_snapshot, mcp__playwright__browser_wait_for, mcp__playwright__browser_console_messages, mcp__playwright__browser_click, mcp__playwright__browser_type, mcp__playwright__browser_press_key, mcp__playwright__browser_hover, mcp__playwright__browser_close
---

# Frontend screenshots

Drive Playwright MCP to capture screenshots of pages served by `bin/dev`. Callers
pass `(url-path, page-slug)` pairs, optionally with per-URL interaction steps, and
get back local PNG paths.

## Output filenames (load-bearing — callers parse these)

`tmp/pr_screenshots/<branch>-<page>-<timestamp>-{desktop,mobile}.png`, where `<branch>=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')` and `<timestamp>=$(date +%Y%m%d-%H%M%S)`. Cross-branch shots get an extra `-base-` segment.

**Every `browser_take_screenshot` anywhere passes a `filename:` starting with `tmp/`** — including a one-off `tmp/tooltip-hover.png` for visual verification that has nothing to do with a PR. The MCP tool's root is the project root, so a bare `tooltip.png` lands in the working tree and shows up in `git status`; `tmp/` is gitignored.

## Preflight

- `eval "$(ruby bin/env --export)"` so `$BASE_URL` is set.
- `curl -fs "$BASE_URL/" >/dev/null` — if it isn't, **stop and ask the user to start it**. `bin/env` resolves `$DEV_PORT`/`$BASE_URL` from the workspace ID, so the bin/dev the user starts will bind to the same port and DB this skill expects.
- If `mcp__playwright__*` tools aren't registered, tell the user to run `claude mcp add playwright -- npx -y @playwright/mcp@latest` and restart.

## Sign in (with the PII gate)

Pick the user the caller specified, or default to `user@bikeindex.org` (lowest privilege; most non-org-affiliated pages render for them). All seeded users use password `pleaseplease12`, and `db/seeds/seed_test_users.rb` is the list of record:

- `user@bikeindex.org` — no org memberships. Default. Use for personal pages (`/my_account`, `/bikes/new`) or to show how an org-less account sees a route.
- `member@brakebills.edu` — `member` (not admin) of Brakebills; the one seeded login that isn't `@bikeindex.org`. Use to capture the non-admin view of an org.
- `admin@bikeindex.org` — `SuperuserAbility`; effectively admin of every org. Use when capturing admin-only menu items, `/admin/...` routes, or org pages where you want the fully-loaded sidebar.
- `dev@bikeindex.org` — `SuperuserAbility` **and** `developer`. Use for the pages gated on both: the `Dev:` navbar entries and `/admin/organizations/:slug/custom_layouts/...`, which redirect for `admin@`.
- `:anonymous` — skip sign-in entirely. Use for public pages where the signed-out rendering is the point.

Signed-out is the normal starting state, **not** a blocker: if a page redirects to `/session/new` or `/session/magic_link` (or `#navUserSettingLink` has no email), sign in. In development every page carries a **"sign in as superadmin"** button in the top banner — one click, no credentials, and it lands on `/admin`; use it whenever the target needs a superuser. Otherwise drive the sign-in form via Playwright with the seed credentials above — don't ask the user to sign in manually, and don't skip the screenshot for lack of a session. It's two steps (email → Continue → password), and **both** submits need addressing by value — `input[name='commit'][value='Continue']` then `input[name='commit'][value='Log in']`. A `[type=submit]` selector fails strict mode on either, and so does `input[name='commit']` alone on the first step, where the banner's "sign in as superadmin" is the other match. **Only ever authenticate against the local dev server** (`$BASE_URL` / localhost) — never sign in to any other host, and never create, promote, or impersonate users to bypass auth.

**Picking an org slug.** When the URL is org-scoped (`/o/<slug>/...`) and the caller didn't specify a slug, default to `brakebills`

**Verify identity before capturing.** The gate isn't about *whether* to authenticate — signing in with seed credentials is expected. It's about confirming the session and its data are seed-only, so no PII lands in an uploaded image. After signing in, check:

```js
document.getElementById('navUserSettingLink')?.dataset.email
```

If it's set but not one of the seeded emails, **stop and ask** — you're signed in as a non-seed user (PII risk on upload). If it's `undefined` when you expected a session, sign-in didn't take (often the seeds haven't run — `bundle exec rails db:seed`); retry the sign-in, don't capture signed-out. For `:anonymous`, expect `undefined` and confirm before continuing.

The admin layout has no `#navUserSettingLink`, so on an `/admin/...` route it reads `undefined` for a session that's fine — reaching the page at all proves superuser. Confirm the data instead: every email the page renders should be `@bikeindex.org` or `@brakebills.edu`.

```js
(document.body.innerText.match(/[\w.+-]+@[\w.-]+/g) || []).slice(0, 8)
```

**Don't capture if any on-page data looks non-seeded.** Even signed in as a seed user, if a page shows records that don't look like seed data (unfamiliar names/emails, real-looking user content), stop and ask — the dev DB may have been loaded with production data, and screenshots are permanent once uploaded.

## Capture

Clear stale shots: `rm -f tmp/pr_screenshots/<branch>-<page>-*.png 2>/dev/null || true`.

Two viewports — resize once each, then walk every URL:
1. `browser_resize` 1440×900 → for each URL: navigate → settle → hide the footer → `browser_take_screenshot` (`fullPage: true`) to `...-desktop.png`.
2. `browser_resize` 390×844 → same loop, also `fullPage: true` → `...-mobile.png`.

**Full page, minus the footer, review-app banner and profiler badge, no `target:` arg.** Capture the whole page (`fullPage: true`) at **both** viewports so nothing below the fold is cut off, but first hide the site footer (identical on every page, just padding), the `#review-app-banner` topbar and the `.profiler-results` badge (both dev-only chrome that isn't part of the real page). **Keep the footer when the diff changes it** — the reason to hide it is that it carries no information, which stops being true the moment it's the subject. The profiler badge reports *this request's* timing, so leaving it in makes every before/after pair differ on a number no reviewer cares about. After each navigation (hiding doesn't persist across page loads), run:

```js
browser_evaluate: () => {
  document.querySelectorAll('.close, [data-dismiss="modal"], [aria-label="Close"]').forEach(c => c.click());
  document.querySelectorAll('.modal-backdrop').forEach(b => b.style.setProperty('display', 'none'));
  document.body.classList.remove('modal-open');
  document.querySelector('.primary-footer, footer, [role="contentinfo"]')?.style.setProperty('display', 'none');
  document.getElementById('review-app-banner')?.style.setProperty('display', 'none');
  document.querySelector('.profiler-results')?.style.setProperty('display', 'none');
  return document.body.scrollHeight; // content height with the chrome gone
}
```

The donation modal is why that starts with a dismiss: a seeded user who hasn't donated gets it over the page on `/my_account` and friends, and it covers the whole shot rather than sitting in a corner.

If the returned content height is **less than the viewport height**, `browser_resize` the height down to it before the shot (the `<html>` element's near-black background fills the gap otherwise), then resize back to the standard viewport before the next URL. Taller-than-viewport pages need no resize — `fullPage` scroll-stitches them.

**Viewport-only is the caller's call, never yours.** When the caller asks for it — "viewport only", "above the fold", "just the mobile viewport" — drop `fullPage` for the size they named and leave the other one full page. Absent that, full page is the default at both sizes: a tall page, a sliver in a PR table cell, or a page whose change sits above the fold are none of them reasons to crop on your own.

Element-only crops (`target:`) still slice context off — don't use them for page captures.

**Settle before the screenshot.** Stimulus + Chartkick render after document load; either `browser_wait_for` on a known element or pause ~500ms–1s. Otherwise charts capture mid-draw.

**Mid-interaction states are in scope.** When the caller asks for a dropdown open, a modal showing, a hover state, a partially-filled form, etc., drive Playwright between settle and the screenshot — `browser_click`, `browser_type`, `browser_press_key`, `browser_hover`, then wait for the UI to reach the target state (`browser_wait_for` on a marker element, or check via `browser_evaluate`) before `browser_take_screenshot`. Treat the interaction sequence as part of the page-slug — e.g. capture `combobox-open` after clicking + typing, distinct from a static `search-registrations` page-load shot. For cross-branch comparisons, run the *same* interaction sequence on each branch so the screenshots actually compare like-for-like.

**An element missing from the shot may be a stale asset build, not the code.** `bin/dev`'s watchers don't pick up a new `@theme` token, so a class keyed off one (`tw:navbar:block!`) is absent from what the server serves while the specs — whose builds you regenerated — pass. Confirm with `getComputedStyle` on the element, then run `bin/rails tailwindcss:build` (or `dartsass:build` for a `.scss` edit); sprockets serves the new digest on the next request, so this needs no `bin/dev` restart and isn't `assets:precompile`.

Sanity-check each PNG: under ~5 KB usually means the page errored. Pull `browser_console_messages` and look only for **uncaught exceptions from app code** (Stimulus registration failures, `TypeError`s in `app/javascript/**`) — Webpacker logs, asset 404s, third-party deprecation warnings are noise. To diagnose a failed capture: HTTP status via `curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/<path>"`, response body via `curl -s "$BASE_URL/<path>" | head -200`, full backtrace via `tail -200 log/development.log`.

**A 429 mid-capture is rack-attack, not a broken page.** `requests/ip` allows a burst per 20 seconds (`config/initializers/rack_attack.rb`), which a loop of `fetch`es from `browser_evaluate` blows through — navigate the pages you're capturing rather than probing them in bulk, and wait the window out rather than retrying.

## Component previews (when no page shows the state)

Some components only render in a context you can't reproduce on a normal dev page — gated by an env var (e.g. the review-app banner needs `REVIEW_APP`), a feature flag, or a hard-to-reach error/empty state. When a component has a ViewComponent/Lookbook preview, screenshot the **preview URL** instead of hunting for a page that happens to render it:

```
$BASE_URL/rails/view_components/<preview_path>/<scenario>
```

`<preview_path>` is the preview class underscored with the `Preview` suffix dropped, and `<scenario>` is the preview method. `PageBlock::ReviewAppBanner::ComponentPreview#superadmin_signed_in` → `/rails/view_components/page_block/review_app_banner/component/superadmin_signed_in`. If a scenario doesn't exist yet, add a method to the component's `*_preview.rb` first — a preview that renders the exact state (pass the args that trigger it) is often the fastest path to a clean shot.

Use this bare route, not Lookbook's `/lookbook/...`, which wraps the component in its own browser chrome.

The preview page loads Tailwind and renders the component standalone (no site chrome), so a preview that fits the viewport captures at `fullPage: false`; a small ViewComponent render-timing line at the bottom is harmless. **A preview taller than the viewport still captures `fullPage: true`** — page-sized components (a whole registration step, a long form) put the changed field below 900px, and cropping it out is the one thing the shot exists to show. Measure before choosing:

```js
() => document.querySelector('<selector for what changed>').getBoundingClientRect().top + window.scrollY
```

**A legacy-styled component needs the display option in the URL.** `layouts/component_preview` only includes `revised`/`kelsey_styles` when Lookbook passes it, and the bare route passes nothing — so a preview whose class carries `# @display legacy_stylesheet true` renders *unstyled* (the navbar's logo fills the viewport) unless you append it yourself:

```
$BASE_URL/rails/view_components/<preview_path>/<scenario>?lookbook%5Bdisplay%5D%5Blegacy_stylesheet%5D=true
```

Everything else still applies — same PII/seed-data gate, same `(url-path, page-slug)` naming (use a slug like `banner-signed-in`).

Previews that query the dev DB (e.g. `User.admins.first`) render nothing when that data is missing — if the state doesn't appear, seed first with `bundle exec rails db:seed`. This is component-only: a preview can't show layout/stacking against the rest of the page (e.g. a navbar z-index fix), so use a real page for those.

## Cross-branch comparison (optional)

When the caller wants before/after, repeat the capture loop against the base ref. The caller passes the base — `origin/main` by default, or the PR's actual base when it isn't `main` (a stacked PR's base often isn't). Set `BASE_REF` to that remote ref (e.g. `origin/main`, `origin/sethherr/feature-x`) and use it throughout; `git fetch origin` first so it's current.

**Capture the base at what the branch actually merged, not at the ref's tip.** A fetch moves `origin/main` to commits the branch hasn't taken, so a base capture there renders *the base's newer work* and the diff attributes it to this PR. Check `git rev-list --count HEAD..$BASE_REF` before detaching: non-zero means merge first, or detach at `$(git merge-base HEAD $BASE_REF)` instead. On a busy repo the base can move between the branch capture and the base capture of the same run.

**The detached checkout in step 3 is a sanctioned exception to "never change branch" — don't stop and ask for it.** It is the only one: it detaches at a *remote* ref, reads, and returns to the same branch within this section, committing nothing. The return to the original branch is part of that sequence, not a second exception. Every other reason to leave the current branch still needs the user's say-so — nothing here licenses checking out some other branch, `git checkout -b`, or a checkout that outlives the capture.

1. `git status` — abort if there are uncommitted changes.
2. Diff `db/migrate/` between the branch and `$BASE_REF`; abort if it changed — a branch-only migration leaves the DB schema ahead of the base's code, so base pages can error.
3. `BRANCH=$(git rev-parse --abbrev-ref HEAD)`, `git checkout --detach $BASE_REF` (detached — checking out a branch name fails if a sibling worktree holds it; detached HEAD at the remote ref is allowed concurrently and is the same code), navigate the browser to force Rails to reload the changed files, repeat capture into `...-base-...` filenames, then `git checkout $BRANCH`.

A `Gemfile.lock` diff is **not** a reason to abort.

**Don't call a pair identical with `cmp`.** Two captures of the *same* code routinely differ by a few dozen bytes, so byte-equality reports a change that isn't one (and its absence proves nothing). Compare pixels, and establish the noise floor before reading anything into a number — recapture one page without changing branches, and treat that count as zero:

```bash
magick compare -metric AE <base>.png <branch>.png null:   # differing pixel count
magick compare <base>.png <branch>.png -compose src d.png && magick identify -format '%@' d.png   # where they differ
```

The bounding box is what settles it: dev-only chrome that slipped past the hide step lands in one small box, a real change doesn't.

The seeded DB persists across checkouts, so the existing session usually still works. Preview routes (`/rails/view_components/...`, `/lookbook/...`) reload across the checkout like ordinary pages, so their before/after works against any `$BASE_REF` too.

## Clean up

Once every screenshot is captured, quit Chrome with `browser_close` — including when the capture failed partway. Leaving it running holds the shared browser profile lock, so the next `browser_navigate` (this skill or another) fails with "Browser is already in use".

**Who closes is decided by who invoked you, so you never have to be told.** Invoked by the user — "grab a screenshot of X" — you're the last one in the browser: close it. Invoked by a workflow that uploads what you captured (`github-pr-images`, and so the `pr` screenshot phase), leave it open; that skill drives the same session straight afterwards and closing between the two just pays the startup again.
