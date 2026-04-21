---
description: Create a pull request, with desktop+mobile screenshots for frontend changes
allowed-tools: Bash, Read, Glob, Grep
---

Create a pull request for the current branch. If the diff contains frontend changes, capture desktop and mobile screenshots of the affected pages and embed them in the PR body under a `## Screenshots` section.

## Workflow

### 1. Gather branch state and start bin/dev

Run `eval "$(ruby bin/env --export)"` once so `$DEV_PORT` (and `$BASE_URL`, `$REDIS_URL`) are set with the right CONDUCTOR_PORT fallback. Then run in parallel:
- `git status` (no `-uall`)
- `git diff main...HEAD --stat`
- `git diff main...HEAD --name-only`
- `git log main..HEAD --oneline`
- `EXISTING_PR=$(gh pr view --json number,url,title 2>/dev/null)` — capture for step 7.
- `curl -fs "$BASE_URL/" >/dev/null` — is `bin/dev` already up?

If the branch has no commits ahead of `main`, stop and tell the user.

If `bin/dev` isn't responding, start it in the background with `bin/dev` — Tailwind and JS assets need to rebuild before any commit.

### 2. Classify the diff

A change is "frontend" if any changed path matches:
- `app/views/**` (`.erb`, `.html.erb`)
- `app/components/**` (ViewComponent templates or Ruby)
- `app/javascript/**`
- `app/assets/**`
- `config/tailwind*`, `tailwind.config.*`, `postcss.config.*`
- `*.scss`, `*.css`, `*.coffee`, `*.js`, `*.ts`

If there are no frontend changes, skip steps 3–5 and go straight to step 6 (no Screenshots section).

### 3. Decide which URLs to screenshot

From the changed files, infer the affected routes. Heuristics:
- A view at `app/views/bikes/show.html.erb` → `/bikes/:id` (pick a representative id from the dev db, e.g. `Bike.last.id`)
- A component touched by a specific page → screenshot that page
- A shared component (header, footer, UI::Badge, etc.) → screenshot 1–2 representative pages that exercise it
- Admin views → `/admin/...`
- If unclear, ask the user which URLs to capture before proceeding. Do not guess blindly — 1–3 well-chosen URLs beats 10 random ones.

Before screenshots, poll `curl -fs "$BASE_URL/" >/dev/null` until it succeeds — Foreman takes a few seconds to come up.

### 4. Capture screenshots

Call `bin/screenshot_dev <url-path> <page-slug>` for each page. It captures desktop (1440×900) and mobile (390×844) PNGs to `tmp/pr_screenshots/<branch>-<page>-{desktop,mobile}.png` and prints the two paths. The branch prefix keeps filenames unique across PRs so release-asset uploads don't collide.

`<page-slug>` should be a short identifier for the page (e.g. `bike-show`, `admin-strava-activities`). `<url-path>` starts with `/` (e.g. `/bikes/42`).

After capture, check file sizes — a PNG under ~5KB usually means the page errored. Diagnose it:

1. `curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/<path>"` to get the HTTP status.
2. `curl -s "$BASE_URL/<path>" | head -200` to see the response body (usually a Rails error page with the exception and top of the backtrace).
3. `tail -200 log/development.log` for the full backtrace and any SQL involved.
4. Based on what you find: route missing → re-check the path; auth/redirect → pick a URL that doesn't require login or log in via a seed account; missing fixture → pick a different id or seed it; genuine bug in the diff → this is what you want to know before shipping — fix it or tell the user.

Only stop and surface to the user once you understand the cause and either (a) have a fix to propose, (b) need input they must provide (e.g. which URL to screenshot instead), or (c) concluded it's a real bug in the PR.

### 5. Host the images

Run `bin/upload_pr_screenshots`. It uploads every PNG in `tmp/pr_screenshots/` to a reused prerelease tagged `_pr-screenshots` (creating it on first use) and prints the public URL for each file. Capture the output for step 6.

### 6. Build the PR body

Structure:

```markdown
<summary of the change — 2–5 bullets written by you based on the diff and recent commits>

## Screenshots

### <page name>

| Desktop | Mobile |
| --- | --- |
| <img src="<desktop-url>" width="600"> | <img src="<mobile-url>" width="300"> |
```

Rules for the Screenshots section:
- Omit the whole `## Screenshots` section if there are no frontend changes.
- Each page gets a `### <page name>` subheading followed by its own 1-row table — desktop on the left, mobile on the right.
- Use `<img src=... width=...>` rather than `![]()` so the widths render predictably in GitHub's table cells.

Follow the repo's existing PR body style — look at the last few merged PRs (`gh pr list --state merged --limit 5 --json body,title`) to match tone and length. Keep the title under ~70 chars.

### 7. Create or update the PR

Push the branch: `git push -u origin HEAD`.

- If `$EXISTING_PR` from step 1 was non-empty: `gh pr edit <num> --body-file <tmp-body-file>` (don't overwrite the title unless the user asks).
- Otherwise: `gh pr create --base main --title "..." --body-file <tmp-body-file>`.

Always pass the body via `--body-file` (not inline `--body`) to preserve formatting. Return the PR URL at the end.

## Notes

- If headless Chrome or the release upload fails, report the failure clearly and fall back to creating the PR without screenshots — don't block PR creation on screenshot tooling.
