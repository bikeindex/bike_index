---
name: pr
description: >-
  Create or update a pull request for the current branch. Trigger when the user
  asks to create/open/make a PR, or to edit/update/rewrite/fix the PR
  description, body, or summary — for both new PRs (`gh pr create`) and
  existing ones (`gh pr edit --body-file`). For frontend diffs, delegates to
  the `frontend-screenshots` skill to capture desktop+mobile screenshots and
  embeds them under a `## Screenshots` section. Use for any verb that lands on
  a PR's text content: "open a PR", "make a PR", "update the PR description",
  "rewrite the PR body", "fix the description".
allowed-tools: Bash, Read, Glob, Grep
---

# Pull request workflow

Create or update a pull request for the current branch. If the diff contains frontend changes, delegate screenshot capture to the `frontend-screenshots` skill and embed the results in the PR body under a `## Screenshots` section.

The workflow is ordered so the always-runs phase (steps 1–3) happens first, then the screenshot phase (steps 4–7) runs only when needed. Each step ends with the conditions under which you stop and return.

## Workflow

### 1. Gather branch state

Run `eval "$(ruby bin/env --export)"` once so `$DEV_PORT` (and `$BASE_URL`, `$REDIS_URL`) are set with the right WORKSPACE_ID fallback. Then run in parallel:
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

Bias hard toward brevity — default to a one-line intro plus ~2-3 bullets, not the 5-bullet maximum. Reviewers skim. A bullet that fits on one line beats one that wraps three times — push detail down to the diff or commit log, not the body. If a per-file bullet starts feeling like an essay, compress to a single sentence naming the *kind* of change (e.g., "tightened description, trimmed unused allowed-tools, consolidated duplicated snippets") rather than enumerating each edit.

Cut anything the reviewer can see in the diff. Implementation mechanics — which HTTP client, file-mode flags, helper-method names, column renames, the exact tasks/files removed — belong to the diff, not the body. Keep only what the diff *doesn't* make obvious: what the PR adds, the single entry point a reviewer would use, and any non-obvious behavior or decision they'd otherwise have to reverse-engineer. When in doubt, leave it out and let the code speak. Aim for under ~6 bullets total including nested ones; if you're past that, regroup by category — but most PRs should land well under that.

Describe the end state, not the journey. Reviewers want to know what the PR does *now* — the diff that will land — not the order in which it was built. Avoid framings like "first pass" / "second pass", commit-hash references for stages of work that all merge into the same shipped diff, "originally we tried X then switched to Y", or play-by-play of how the conversation evolved. The git log preserves that. If a discarded approach is genuinely load-bearing context for the reviewer (e.g., explains why the chosen approach is structured oddly), one line is enough; otherwise omit. The same applies when *updating* an existing PR body: rewrite to describe the current diff, don't append a changelog of edits made since the last revision.

**No "Test plan" section unless the user asks.** Don't list things CI already covers — `bundle exec rspec ...`, `bin/lint`, `bin/dev` boots cleanly, etc. Those belong to CI, not the PR body. Only add a Test plan when there's reviewer-facing manual verification a human needs to do (e.g. "click X, confirm Y appears"), and only when the user requests it.

**No generic "covered by tests" bullet.** Drop summary bullets like "Covered by specs and a fixture" / "Added tests" / "Includes specs" — that a change is tested is assumed, so the bullet adds no information, and it names test *mechanics* (a fixture, a VCR cassette, an inline `StringIO`) that quietly go stale when the test approach changes mid-PR. Mention tests in the body only when *what* is verified is itself the reviewer-facing point (e.g. "adds a regression test for the UTF-8 download crash"), not merely that tests exist.

**No Claude Code attribution footer.** Don't append the "🤖 Generated with [Claude Code](https://claude.com/claude-code)" line (or any variant of it) to the body. The PR body should read like the human author wrote it.

Push the branch: `git push -u origin HEAD`.

- If `$EXISTING_PR` from step 1 was non-empty: `gh pr edit <num> --body-file <tmp-body-file>` (don't overwrite the title unless the user asks).
- Otherwise: `gh pr create --base main --title "..." --body-file <tmp-body-file>`. Capture the PR number from the output.

Always pass the body via `--body-file` (not inline `--body`) to preserve formatting.

**Stop here and return the PR URL** unless step 4's gate says screenshots are needed.

### 4. Decide whether screenshots are needed and which URLs to capture

Only continue past this step when there's a real reason to capture. Otherwise return the PR URL.

- New PR + `FRONTEND=false` → done.
- New PR + `FRONTEND=true` → continue; capture every affected page.
- Existing PR + `FRONTEND=false` → done.
- Existing PR + `FRONTEND=true` → continue only if the captures in the existing screenshots comment are stale: a commit since the last capture touched a page already screenshotted, or a new affected page now appears in the diff. Limit step 5 to those pages. If nothing has moved, done.

From the changed files, infer the affected routes. Heuristics:
- A view at `app/views/bikes/show.html.erb` → `/bikes/:id` (pick a representative id from the dev db, e.g. `Bike.last.id`)
- A component touched by a specific page → screenshot that page
- A shared component (header, footer, UI::Badge, etc.) → screenshot 1–2 representative pages that exercise it
- Admin views → `/admin/...`
- If unclear, ask the user which URLs to capture before proceeding. Do not guess blindly — 1–3 well-chosen URLs beats 10 random ones.

### 5. Capture branch screenshots

Invoke the `frontend-screenshots` skill with the `(url-path, page-slug)` pairs from step 4. It handles dev-server check, sign-in, the seeded-user identity gate, viewport sizing, and per-PNG sanity checks. It returns local paths under `tmp/pr_screenshots/<branch>-<page>-<timestamp>-{desktop,mobile}.png`.

If `frontend-screenshots` returns failures it couldn't diagnose, surface them and stop — don't post partial screenshots.

### 6. Upload branch screenshots and get inline URLs

Invoke the `github-upload-image-to-pr` skill to upload each PNG from step 5 to the PR's comment textarea — GitHub mints persistent `user-attachments/assets/` URLs that render inline in the browser (release assets would force a download on click). The skill clears the textarea without submitting the comment.

Collect the returned URLs, keyed by `(page-slug, viewport)`.

### 6.5 Capture and upload the same URLs on `main`

Capture the **base-branch** version of every screenshot from step 5 so the section becomes a before/after comparison instead of "here's how it looks now." This is the default for every screenshot captured — if you reached step 5 at all, the diff is frontend, and the comparison is informative (a same-screenshot pair documents visual parity for a refactor; a different pair documents the actual visual change).

Skip per-page only when the URL didn't exist on `main` (a brand-new route or page added in this PR) — there's nothing to compare to.

Re-invoke `frontend-screenshots` with the same `(url-path, page-slug)` pairs and tell it to capture against `main` (its step 6 — git checkout dance, captures into `...-main-...` filenames, returns to the original branch). Then re-invoke `github-upload-image-to-pr` for those PNGs.

### 7. Post the Screenshots section as the first PR comment

Post the screenshots as a **PR comment**, not in the PR body. This keeps the description tight and skimmable — reviewers see the human-written summary first, with screenshots one scroll down. It also avoids re-editing the body (and its notification noise) every time screenshots are recaptured.

On a fresh PR, this comment is naturally the first one. On an update, find the existing screenshots comment (the one authored by you whose body starts with `## Screenshots`) and edit it in place rather than posting a new one:

```bash
SCREENSHOT_COMMENT_ID=$(gh api repos/{owner}/{repo}/issues/{PR_NUMBER}/comments \
  --jq '.[] | select(.body | startswith("## Screenshots")) | .id' | head -1)
```

- If `$SCREENSHOT_COMMENT_ID` is empty: `gh pr comment <num> --body-file <tmp-comment-file>`.
- Otherwise: `gh api -X PATCH repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID -f body=@<tmp-comment-file>`.

**Headers are always `| Desktop | Mobile |`** — that stays the same regardless of whether there's a main comparison. The main shots and branch shots stack as additional rows, with a small indicator row between them when both are present.

Default (with main comparison):

```markdown
## Screenshots

### <url-path>

| Desktop | Mobile |
| --- | --- |
| <img src="<main-desktop-url>" width="500"> | <img src="<main-mobile-url>" width="250"> |
| main 👆 | this branch 👇 |
| <img src="<branch-desktop-url>" width="500"> | <img src="<branch-mobile-url>" width="250"> |
```

Brand-new page (URL didn't exist on `main` — see step 6.5), no comparison row:

```markdown
### <url-path>

| Desktop | Mobile |
| --- | --- |
| <img src="<branch-desktop-url>" width="500"> | <img src="<branch-mobile-url>" width="250"> |
```

Rules:
- Each page gets a `### <url-path>` subheading (the literal path, e.g. `/`, `/bikes/42`, `/admin/strava_activities`) followed by its own table.
- **Headers are always `| Desktop | Mobile |`** — never `| main | this branch |` or any per-PR variation. Reviewers should see the same column meaning across every PR.
- Use `<img src=... width=...>` rather than `![]()` so the widths render predictably in GitHub's table cells. ~500 for desktop, ~250 for mobile fits a side-by-side cell layout cleanly.

When updating an existing screenshots comment, replace the existing `### <url-path>` block for any page you recaptured; leave other pages' blocks alone.

Return the PR URL.

## Notes

- If `frontend-screenshots` or `github-upload-image-to-pr` fails, report the failure clearly and leave the PR without screenshots — don't block PR creation on screenshot tooling.
