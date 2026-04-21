---
description: Create a pull request, with desktop+mobile screenshots for frontend changes
allowed-tools: Bash, Read, Glob, Grep
---

Create a pull request for the current branch. If the diff contains frontend changes, capture desktop and mobile screenshots of the affected pages and embed them in the PR body under a `## Screenshots` section.

## Workflow

### 1. Gather branch state and start bin/dev

Run in parallel:
- `git status` (no `-uall`)
- `git diff main...HEAD --stat`
- `git diff main...HEAD --name-only`
- `git log main..HEAD --oneline`
- `gh pr view --json number,url,title 2>/dev/null` — is there already a PR?
- `curl -fs "http://localhost:${DEV_PORT:-3042}/" >/dev/null` — is `bin/dev` already up?

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

If you started `bin/dev` in step 1, poll `curl -fs "http://localhost:${DEV_PORT:-3042}/" >/dev/null` until it succeeds before taking screenshots — Foreman takes a few seconds to come up.

### 4. Capture screenshots

Use headless Chrome. Save to `tmp/pr_screenshots/` (create if missing).

Desktop (1440x900):
```
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless --disable-gpu --hide-scrollbars \
  --window-size=1440,900 \
  --screenshot="tmp/pr_screenshots/<name>-desktop.png" \
  "http://localhost:$DEV_PORT/<path>"
```

Mobile (390x844, iPhone-ish):
```
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --headless --disable-gpu --hide-scrollbars \
  --window-size=390,844 \
  --user-agent="Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1" \
  --screenshot="tmp/pr_screenshots/<name>-mobile.png" \
  "http://localhost:$DEV_PORT/<path>"
```

`<name>` should be a short slug derived from the page (e.g. `bike-show`, `admin-strava-activities`). One desktop + one mobile per page.

After capture, check file sizes — a PNG under ~5KB usually means the page errored. Diagnose it:

1. `curl -s -o /dev/null -w "%{http_code}\n" "http://localhost:$DEV_PORT/<path>"` to get the HTTP status.
2. `curl -s "http://localhost:$DEV_PORT/<path>" | head -200` to see the response body (usually a Rails error page with the exception and top of the backtrace).
3. `tail -200 log/development.log` for the full backtrace and any SQL involved.
4. Based on what you find: route missing → re-check the path; auth/redirect → pick a URL that doesn't require login or log in via a seed account; missing fixture → pick a different id or seed it; genuine bug in the diff → this is what you want to know before shipping — fix it or tell the user.

Only stop and surface to the user once you understand the cause and either (a) have a fix to propose, (b) need input they must provide (e.g. which URL to screenshot instead), or (c) concluded it's a real bug in the PR.

### 5. Host the images

Upload screenshots as release assets on a reused prerelease in the repo, using only `gh` (for auth) and `curl` (for the binary upload). No branch commits, no third-party dependencies.

The strategy: find or create a single prerelease tagged `_pr-screenshots`, then POST each PNG to its `uploads.github.com` endpoint. GitHub returns a public `browser_download_url` for each asset.

```bash
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)

# Find or create the screenshots prerelease (one-time per repo; reused forever)
RELEASE_ID=$(gh api "repos/$REPO/releases/tags/_pr-screenshots" --jq '.id' 2>/dev/null)
if [ -z "$RELEASE_ID" ]; then
  RELEASE_ID=$(gh api "repos/$REPO/releases" -X POST \
    -f tag_name=_pr-screenshots \
    -f name="PR screenshots" \
    -F prerelease=true \
    -f body="Auto-uploaded PR screenshots — do not delete; image embeds reference these assets." \
    --jq '.id')
fi

# Upload one file, printing its public URL
upload_screenshot() {
  local path="$1"
  local name="pr-$(date +%s)-$(basename "$path")"  # timestamp prefix avoids name collisions across PRs
  curl -sS -f -X POST \
    -H "Authorization: Bearer $(gh auth token)" \
    -H "Content-Type: image/png" \
    --data-binary "@$path" \
    "https://uploads.github.com/repos/$REPO/releases/$RELEASE_ID/assets?name=$name" \
    | jq -r '.browser_download_url'
}
```

Run `upload_screenshot` once per file and capture the URL. URLs look like `https://github.com/<owner>/<repo>/releases/download/_pr-screenshots/<name>` and are publicly accessible.

If an upload fails, surface the error and fall back to creating the PR without screenshots — don't block PR creation on screenshot hosting.

### 6. Build the PR body

Structure:

```markdown
<summary of the change — 2–5 bullets written by you based on the diff and recent commits>

## Screenshots

| Desktop | Mobile |
| --- | --- |
| <img src="<desktop-raw-url>" width="600"> | <img src="<mobile-raw-url>" width="300"> |

<one row per screenshotted page; add a caption row above each table if there are multiple pages>
```

Rules for the Screenshots section:
- Omit the whole `## Screenshots` section if there are no frontend changes.
- Each screenshotted page gets its own table (so desktop and mobile for the same page sit side-by-side).
- If there are multiple pages, precede each table with a `### <page name>` subheading.
- Use `<img src=... width=...>` rather than `![]()` so the widths render predictably in GitHub's table cells.

Follow the repo's existing PR body style — look at the last few merged PRs (`gh pr list --state merged --limit 5 --json body,title`) to match tone and length. Keep the title under ~70 chars.

### 7. Create or update the PR

Push the branch: `git push -u origin HEAD`.

- If `gh pr view` returned an existing PR earlier: `gh pr edit <num> --body-file <tmp-body-file>` (don't overwrite the title unless the user asks).
- Otherwise: `gh pr create --base main --title "..." --body-file <tmp-body-file>`.

Always pass the body via `--body-file` (not inline `--body`) to preserve formatting. Return the PR URL at the end.

## Notes

- Do not skip hooks (`--no-verify`) on any commits or pushes.
- The first run in a repo creates a prerelease tagged `_pr-screenshots`; every run after that reuses it. This is expected — don't treat the `404 → create` flow as an error.
- If headless Chrome fails (missing binary, crash) or an upload fails, report the failure clearly and fall back to creating the PR without screenshots — don't block PR creation on screenshot tooling.
