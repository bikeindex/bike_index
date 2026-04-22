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
- `EXISTING_PR=$(gh pr view --json number,url,title 2>/dev/null)` — capture for step 5.
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

If there are no frontend changes, skip steps 3–4 and 6–7 — step 5 still creates the PR, just without a Screenshots section.

### 3. Decide which URLs to screenshot

From the changed files, infer the affected routes. Heuristics:
- A view at `app/views/bikes/show.html.erb` → `/bikes/:id` (pick a representative id from the dev db, e.g. `Bike.last.id`)
- A component touched by a specific page → screenshot that page
- A shared component (header, footer, UI::Badge, etc.) → screenshot 1–2 representative pages that exercise it
- Admin views → `/admin/...`
- If unclear, ask the user which URLs to capture before proceeding. Do not guess blindly — 1–3 well-chosen URLs beats 10 random ones.

Before screenshots, poll `curl -fs "$BASE_URL/" >/dev/null` until it succeeds — Foreman takes a few seconds to come up.

### 4. Capture screenshots

Call `bin/screenshot_dev <url-path> <page-slug>` for each page. It captures desktop (1440×900) and mobile (390×844) PNGs to `tmp/pr_screenshots/<branch>-<page>-<timestamp>-{desktop,mobile}.png` and prints the two paths.

`<page-slug>` should be a short identifier for the page (e.g. `bike-show`, `admin-strava-activities`). `<url-path>` starts with `/` (e.g. `/bikes/42`).

After capture, check file sizes — a PNG under ~5KB usually means the page errored. Diagnose it:

1. `curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/<path>"` to get the HTTP status.
2. `curl -s "$BASE_URL/<path>" | head -200` to see the response body (usually a Rails error page with the exception and top of the backtrace).
3. `tail -200 log/development.log` for the full backtrace and any SQL involved.
4. Based on what you find: route missing → re-check the path; auth/redirect → pick a URL that doesn't require login or log in via a seed account; missing fixture → pick a different id or seed it; genuine bug in the diff → this is what you want to know before shipping — fix it or tell the user.

Only stop and surface to the user once you understand the cause and either (a) have a fix to propose, (b) need input they must provide (e.g. which URL to screenshot instead), or (c) concluded it's a real bug in the PR.

### 5. Build the summary body and create/update the PR

Write a summary of the change (2–5 bullets based on the diff and recent commits) to a temp file. Follow the repo's existing PR body style — look at the last few merged PRs (`gh pr list --state merged --limit 5 --json body,title`) to match tone and length. Keep the title under ~70 chars.

If there are no frontend changes, this is the final body — skip steps 6–7.

Push the branch: `git push -u origin HEAD`.

- If `$EXISTING_PR` from step 1 was non-empty: `gh pr edit <num> --body-file <tmp-body-file>` (don't overwrite the title unless the user asks).
- Otherwise: `gh pr create --base main --title "..." --body-file <tmp-body-file>`. Capture the PR number from the output.

Always pass the body via `--body-file` (not inline `--body`) to preserve formatting.

### 6. Upload screenshots and get inline URLs

Invoke the `github-upload-image-to-pr` skill to upload each PNG from step 4 to the PR's comment textarea — GitHub mints persistent `user-attachments/assets/` URLs that render inline in the browser (release assets would force a download on click). The skill clears the textarea without submitting the comment.

Collect the returned URLs, keyed by which file they correspond to (desktop vs. mobile, per page).

### 7. Append the Screenshots section to the PR body

Append this to the existing body and `gh pr edit <num> --body-file <tmp-body-file>` again:

```markdown

## Screenshots

### <url-path>

| Desktop | Mobile |
| --- | --- |
| <img src="<desktop-user-attachments-url>" width="600"> | <img src="<mobile-user-attachments-url>" width="300"> |
```

Rules:
- Each page gets a `### <url-path>` subheading (the literal path, e.g. `/`, `/bikes/42`, `/admin/strava_activities`) followed by its own 1-row table — desktop on the left, mobile on the right.
- Use `<img src=... width=...>` rather than `![]()` so the widths render predictably in GitHub's table cells.

Return the PR URL at the end.

## Notes

- If headless Chrome or the skill upload fails, report the failure clearly and leave the PR without screenshots — don't block PR creation on screenshot tooling.
