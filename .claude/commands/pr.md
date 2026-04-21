---
description: Create a pull request, with desktop+mobile screenshots for frontend changes
allowed-tools: Bash, Read, Glob, Grep
---

Create a pull request for the current branch. If the diff contains frontend changes, capture desktop and mobile screenshots of the affected pages and embed them in the PR body under a `## Screenshots` section.

## Workflow

### 1. Gather branch state

Run in parallel:
- `git status` (no `-uall`)
- `git diff main...HEAD --stat`
- `git diff main...HEAD --name-only`
- `git log main..HEAD --oneline`
- `gh pr view --json number,url,title 2>/dev/null` — is there already a PR?

If the branch has no commits ahead of `main`, stop and tell the user.

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

If the dev server is not already running on `http://localhost:3042` (or `$DEV_PORT` / `$CONDUCTOR_PORT`), start it yourself in the background with `bin/dev` before continuing — the user always wants it running before commits so Tailwind / JS assets are rebuilt. Wait for the server to respond (`curl -fs http://localhost:$DEV_PORT/ >/dev/null`) before taking screenshots.

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

After capture, check file sizes — a PNG under ~5KB usually means the page errored. If so, curl the URL, surface the error to the user, and stop.

### 5. Host the images

Use [`gh-attach`](https://github.com/Addono/gh-attach) with the `release-asset` strategy. It uploads each image to a single reused prerelease tagged `_gh-attach-assets` in the repo, and returns a public URL — no branch commits, no browser session.

First-time setup (check once, install if missing):
```
gh extension list | grep -q Addono/gh-attach || gh extension install Addono/gh-attach
```

The PR needs to exist before uploading (gh-attach targets a specific PR number). So reorder:
1. Push the branch: `git push -u origin HEAD`
2. Create a draft PR first with a placeholder body so you have a number: `gh pr create --base main --draft --title "..." --body "uploading screenshots..."`. Capture the PR number from the returned URL.
3. For each screenshot, upload and capture the markdown:
   ```
   gh attach upload tmp/pr_screenshots/<name>-desktop.png \
     --target <owner>/<repo>#<pr-number> \
     --strategy release-asset
   ```
   The command prints a URL like `https://github.com/<owner>/<repo>/releases/download/_gh-attach-assets/<file>`. Capture it.
4. Build the final PR body (step 6) using those URLs.
5. Update the PR with the final body and promote from draft: `gh pr edit <num> --body-file <tmp-body-file>` then `gh pr ready <num>`.

If `gh-attach` install or upload fails, fall back to creating the PR without screenshots and surface the error to the user — don't block PR creation on screenshot hosting.

### 6. Build the PR body

Structure:

```markdown
<summary of the change — 1–3 short paragraphs or bullets, written by you based on the diff and recent commits>

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

### 7. Finalize the PR

Branching on which path you took:

- **Frontend path (draft PR was created in step 5):** `gh pr edit <num> --title "..." --body-file <tmp-body-file>` with the final body, then `gh pr ready <num>`.
- **No-frontend path:** push the branch, then `gh pr create --base main --title "..." --body-file <tmp-body-file>`. If `gh pr view` already found an existing PR, use `gh pr edit` instead (don't overwrite the title unless the user asks).

Always pass the body via `--body-file` (not inline `--body`) to preserve formatting. Return the PR URL at the end.

## Notes

- Always ensure `bin/dev` is running (start it in the background if not) before committing, so Tailwind and JS assets are rebuilt. Don't ask the user to start it.
- Do not skip hooks (`--no-verify`) on any commits or pushes.
- `gh-attach`'s release-asset strategy creates a single prerelease tagged `_gh-attach-assets` in the repo on first use and reuses it forever — this is expected, don't treat it as an error.
- If headless Chrome fails (missing binary, crash) or `gh-attach` fails, report the failure clearly and fall back to creating the PR without screenshots — don't block PR creation on screenshot tooling.
