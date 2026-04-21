---
description: Create a pull request, with desktop+mobile screenshots for frontend changes
allowed-tools: Bash, Read, Glob, Grep
---

Create a pull request for the current branch. If the diff contains frontend changes, capture desktop and mobile screenshots of the affected pages and embed them in the PR body under a `## Screenshots` section.

## Workflow

### 1. Gather branch state and start bin/dev

Set `DEV_PORT=${DEV_PORT:-3042}` once and reuse it below. Run in parallel:
- `git status` (no `-uall`)
- `git diff main...HEAD --stat`
- `git diff main...HEAD --name-only`
- `git log main..HEAD --oneline`
- `EXISTING_PR=$(gh pr view --json number,url,title 2>/dev/null)` — capture for step 7.
- `curl -fs "http://localhost:$DEV_PORT/" >/dev/null` — is `bin/dev` already up?

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

Before screenshots, poll `curl -fs "http://localhost:$DEV_PORT/" >/dev/null` until it succeeds — Foreman takes a few seconds to come up.

### 4. Capture screenshots

Use headless Chrome. Save to `tmp/pr_screenshots/`.

Filename convention: `<branch-slug>-<page-slug>-<device>.png`, where `<branch-slug>` is `$(git rev-parse --abbrev-ref HEAD | tr '/' '-')`, `<page-slug>` is derived from the page (e.g. `bike-show`, `admin-strava-activities`), and `<device>` is `desktop` or `mobile`. The branch prefix makes filenames unique across PRs so release-asset uploads don't collide.

Desktop (1440x900):
```
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless --disable-gpu --hide-scrollbars \
  --window-size=1440,900 \
  --screenshot="tmp/pr_screenshots/<filename>.png" \
  "http://localhost:$DEV_PORT/<path>"
```

Mobile (390x844, iPhone-ish):
```
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless --disable-gpu --hide-scrollbars \
  --window-size=390,844 \
  --user-agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1" \
  --screenshot="tmp/pr_screenshots/<filename>.png" \
  "http://localhost:$DEV_PORT/<path>"
```

After capture, check file sizes — a PNG under ~5KB usually means the page errored. Diagnose it:

1. `curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:$DEV_PORT/<path>"` to get the HTTP status.
2. `curl -s "http://localhost:$DEV_PORT/<path>" | head -200` to see the response body (usually a Rails error page with the exception and top of the backtrace).
3. `tail -200 log/development.log` for the full backtrace and any SQL involved.
4. Based on what you find: route missing → re-check the path; auth/redirect → pick a URL that doesn't require login or log in via a seed account; missing fixture → pick a different id or seed it; genuine bug in the diff → this is what you want to know before shipping — fix it or tell the user.

Only stop and surface to the user once you understand the cause and either (a) have a fix to propose, (b) need input they must provide (e.g. which URL to screenshot instead), or (c) concluded it's a real bug in the PR.

### 5. Host the images

Upload screenshots as release assets on a reused prerelease in the repo, using `gh` subcommands — no `curl`, no third-party deps.

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
TAG=_pr-screenshots

gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1 \
  || gh release create "$TAG" --repo "$REPO" --prerelease \
       --title "PR screenshots" \
       --notes "Auto-uploaded PR screenshots — do not delete."

gh release upload "$TAG" tmp/pr_screenshots/*.png --repo "$REPO"
```

First run in a repo creates the prerelease; subsequent runs reuse it. URLs follow the stable pattern `https://github.com/<owner>/<repo>/releases/download/_pr-screenshots/<filename>`, so you can construct them without parsing any API response.

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
