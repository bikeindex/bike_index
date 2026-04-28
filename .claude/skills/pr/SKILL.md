---
name: pr
description: >-
  Create or update a pull request for the current branch. Trigger when the user
  asks to create/open/make a PR, or to edit/update/rewrite/fix the PR
  description, body, or summary — for both new PRs (`gh pr create`) and
  existing ones (`gh pr edit --body-file`). For frontend diffs, captures
  desktop+mobile screenshots with Playwright MCP and embeds them under a
  `## Screenshots` section. Use for any verb that lands on a PR's text
  content: "open a PR", "make a PR", "update the PR description", "rewrite
  the PR body", "fix the description".
allowed-tools: Bash, Read, Glob, Grep
---

# Pull request workflow

Create or update a pull request for the current branch. If the diff contains frontend changes, capture desktop and mobile screenshots of the affected pages with Playwright and embed them in the PR body under a `## Screenshots` section.

The workflow is ordered so the always-runs phase (steps 1–3) happens first, then the screenshot phase (steps 4–7) runs only when needed. Each step ends with the conditions under which you stop and return.

## Workflow

### 1. Gather branch state

Run `eval "$(ruby bin/env --export)"` once so `$DEV_PORT` (and `$BASE_URL`, `$REDIS_URL`) are set with the right CONDUCTOR_PORT fallback. Then run in parallel:
- `git status` (no `-uall`)
- `git diff main...HEAD --stat`
- `git diff main...HEAD --name-only`
- `git log main..HEAD --oneline`
- `EXISTING_PR=$(gh pr view --json number,url,title 2>/dev/null)` — capture for step 3.

If the branch has no commits ahead of `main`, stop and tell the user.

### 2. Classify the diff

A change is "frontend" if any changed path matches:
- `app/views/**` (`.erb`, `.html.erb`)
- `app/components/**` (ViewComponent templates or Ruby)
- `app/javascript/**`
- `app/assets/**`
- `config/tailwind*`, `tailwind.config.*`, `postcss.config.*`
- `*.scss`, `*.css`, `*.coffee`, `*.js`, `*.ts`

Record this as `FRONTEND=true|false` for the screenshot decision in step 4.

### 3. Build the summary body and create/update the PR

Write a summary of the change (2–5 bullets based on the diff and recent commits) to a temp file. Follow the repo's existing PR body style — look at the last few merged PRs (`gh pr list --state merged --limit 5 --json body,title`) to match tone and length. Keep the title under ~70 chars.

**Bias toward brevity.** Reviewers skim. A bullet that fits on one line beats one that wraps three times — push detail down to the diff or commit log, not the body. If a per-file bullet starts feeling like an essay, compress to a single sentence naming the *kind* of change (e.g., "tightened description, trimmed unused allowed-tools, consolidated duplicated snippets") rather than enumerating each edit. Aim for under ~6 bullets total across the whole body, including any nested ones; if you're past that, regroup by category until you fit.

**Describe the end state, not the journey.** Reviewers want to know what the PR does *now* — the diff that will land — not the order in which it was built. Avoid framings like "first pass" / "second pass", commit-hash references for stages of work that all merge into the same shipped diff, "originally we tried X then switched to Y", or play-by-play of how the conversation evolved. The git log preserves that. If a discarded approach is genuinely load-bearing context for the reviewer (e.g., explains why the chosen approach is structured oddly), one line is enough; otherwise omit. The same applies when *updating* an existing PR body: rewrite to describe the current diff, don't append a changelog of edits made since the last revision.

**No "Test plan" section unless the user asks.** Don't list things CI already covers — `bundle exec rspec ...`, `bin/lint`, `bin/dev` boots cleanly, etc. Those belong to CI, not the PR body. Only add a Test plan when there's reviewer-facing manual verification a human needs to do (e.g. "click X, confirm Y appears"), and only when the user requests it.

Push the branch: `git push -u origin HEAD`.

- If `$EXISTING_PR` from step 1 was non-empty: `gh pr edit <num> --body-file <tmp-body-file>` (don't overwrite the title unless the user asks).
- Otherwise: `gh pr create --base main --title "..." --body-file <tmp-body-file>`. Capture the PR number from the output.

Always pass the body via `--body-file` (not inline `--body`) to preserve formatting.

**Stop here and return the PR URL** unless step 4's gate says screenshots are needed.

### 4. Decide whether screenshots are needed

Only continue past this step when there's a real reason to capture. Otherwise return the PR URL.

- New PR + `FRONTEND=false` → done.
- New PR + `FRONTEND=true` → continue; capture every affected page.
- Existing PR + `FRONTEND=false` → done.
- Existing PR + `FRONTEND=true` → continue only if the captures in the existing body are stale: a commit since the last capture touched a page already screenshotted, or a new affected page now appears in the diff. Limit step 5 to those pages. If nothing has moved, done.

From the changed files, infer the affected routes. Heuristics:
- A view at `app/views/bikes/show.html.erb` → `/bikes/:id` (pick a representative id from the dev db, e.g. `Bike.last.id`)
- A component touched by a specific page → screenshot that page
- A shared component (header, footer, UI::Badge, etc.) → screenshot 1–2 representative pages that exercise it
- Admin views → `/admin/...`
- If unclear, ask the user which URLs to capture before proceeding. Do not guess blindly — 1–3 well-chosen URLs beats 10 random ones.

If `bin/dev` isn't already up (`curl -fs "$BASE_URL/" >/dev/null` fails), start it in the background — Tailwind and JS need to compile before screenshots will render correctly. Then poll the same `curl` until it succeeds.

### 5. Capture screenshots

Use Playwright MCP (`mcp__playwright__*`) to capture desktop and mobile screenshots. The MCP browser session persists across calls, so dev-server sign-in is a one-time manual step.

Paths: `tmp/pr_screenshots/<branch>-<page>-<timestamp>-{desktop,mobile}.png`, where `<branch>=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')` and `<timestamp>=$(date +%Y%m%d-%H%M%S)`. Before capturing, remove stale shots: `rm -f tmp/pr_screenshots/<branch>-<page>-*.png`. `<page-slug>` is a short identifier (e.g. `bike-show`, `admin-strava-activities`).

Capture in two passes so each viewport is resized only once:

1. `browser_resize` → 1440×900. For each page, `browser_navigate` to `$BASE_URL<url-path>` then `browser_take_screenshot` to `...-desktop.png`.
2. `browser_resize` → 390×844 (mobile viewport). For each page, `browser_navigate` to the same URL then `browser_take_screenshot` to `...-mobile.png`.

If a navigation lands on `/session/new`, ask the user to sign in via the visible Playwright MCP browser window, then continue.

After capture, sanity-check each PNG. A file under ~5KB usually means the page errored; also check `browser_console_messages` for uncaught JS errors. Diagnose:

1. `curl -s -o /dev/null -w "%{http_code}\n" "$BASE_URL/<path>"` to get the HTTP status.
2. `curl -s "$BASE_URL/<path>" | head -200` to see the response body (usually a Rails error page with the exception and top of the backtrace).
3. `tail -200 log/development.log` for the full backtrace and any SQL involved.
4. Based on what you find: route missing → re-check the path; auth/redirect → pick a URL that doesn't require login or sign in; missing fixture → pick a different id or seed it; genuine bug in the diff → fix it or tell the user.

Only stop and surface to the user once you understand the cause and either (a) have a fix to propose, (b) need input they must provide (e.g. which URL to screenshot instead), or (c) concluded it's a real bug in the PR.

### 6. Upload screenshots and get inline URLs

Invoke the `github-upload-image-to-pr` skill to upload each PNG from step 5 to the PR's comment textarea — GitHub mints persistent `user-attachments/assets/` URLs that render inline in the browser (release assets would force a download on click). The skill clears the textarea without submitting the comment.

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

When updating an existing body, replace the existing `### <url-path>` block for any page you recaptured; leave other pages' blocks alone.

Return the PR URL.

## Notes

- If Playwright MCP or the upload skill fails, report the failure clearly and leave the PR without screenshots — don't block PR creation on screenshot tooling.
- If Playwright MCP tools aren't registered (`mcp__playwright__*` missing), tell the user to install: `claude mcp add playwright -- npx -y @playwright/mcp@latest` and restart the session.
