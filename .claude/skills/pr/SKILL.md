---
name: pr
description: >-
  Create or update a pull request for the current branch. Trigger when the user
  asks to create/open/make a PR, or to edit/update/rewrite/fix the PR
  description, body, summary, or title — including bare update phrasings like
  "update pr", "update this pr", or "update the PR" with no other object — for
  both new PRs (`gh pr create`) and existing ones (`gh pr edit`). For frontend
  diffs, delegates to the `frontend-screenshots` skill to capture
  desktop+mobile screenshots and embeds them under a `## Screenshots` section.
  Use for any verb that lands on a PR's text content: "open a PR", "make a PR",
  "update pr", "update this pr", "update the PR description", "rewrite the PR
  body", "fix the description".
allowed-tools: Bash, Read, Glob, Grep
---

# Pull request workflow

Create or update a pull request for the current branch. If the diff contains frontend changes, delegate screenshot capture to the `frontend-screenshots` skill and embed the results in the PR body under a `## Screenshots` section.

The workflow below (steps 0–3) always runs and creates or updates the PR. When the diff is frontend, a second phase captures before/after screenshots and posts them as a PR comment — that machinery lives in `references/screenshots.md`, read only when step 3 sends you there.

## Workflow

### 0. Simplify, lint, and conform to CLAUDE.md

Invoke the `/simplify` command to review the changed code for reuse, simplification, and efficiency cleanups and apply them. Do this first, before writing the PR up, so the body describes the diff's final shape rather than a first draft. It's quality-only — it won't touch correctness — so it's safe to run unattended here; if it reports nothing to clean up, move on.

Then run `bin/lint` to auto-format the code (it also picks up whatever `/simplify` just changed). Always use `bin/lint`, never another formatter or `standardrb` directly.

Then review the changed files against the repo's `CLAUDE.md` (root and any nested ones in touched directories) and fix anything that doesn't conform — code-style guidelines (functional style, no argument mutation, omitted hash values like `{x:}`, private methods, unabbreviated names, pithy comments), testing conventions, and frontend rules. Only touch lines this branch already changed; don't reformat unrelated code.

Any edits from this step get picked up by the branch-state and push steps below — don't separately commit them here; the normal commit/push in step 3 handles it.

### 0.5. Determine the base branch

The base is the branch this PR goes off of — `main` by default, or a specific branch when the user names one to target. The head is always the current branch (`HEAD`), so the branch that determines the base is a *different* one the user points at: "a PR off of `release-2`", "base this on `release-2`", "onto/target `release-2`", "stacked on `<branch>`", or a `--base <branch>` argument all set the base to that branch. Naming the branch you're already on just identifies the head — the base stays `main`. If it's genuinely unclear whether a named branch is meant as the base, ask rather than guess. Set `BASE` accordingly (default `main`) and use it everywhere below: step 1 refers to `origin/$BASE`, and step 3 passes `gh pr create --base "$BASE"`. Never silently retarget an explicitly-named base to `main`.

When updating an **existing** PR, leave its base untouched — run `gh pr edit` without `--base` (which preserves the current base). Only retarget an existing PR's base when the user explicitly asks.

### 1. Update from the base, then gather branch state

First bring the branch up to date with the base (`$BASE` from step 0.5) so the PR reflects the current base and merges without surprises. Follow the `merge-conflicts` skill: `git fetch origin` then `git merge --no-edit "origin/$BASE"`, merge (never rebase), keep the merge commit to just the merge (the step 0 edits ride along as ordinary commits), and resolve any conflicts per that skill.

Then gather state — run in parallel:
- `git status` (no `-uall`)
- `git diff "origin/$BASE"...HEAD --stat`
- `git diff "origin/$BASE"...HEAD --name-only`
- `git log "origin/$BASE"..HEAD --oneline`
- `EXISTING_PR=$(gh pr view --json number,url,title 2>/dev/null)` — capture for step 3. When non-empty, parse the PR number with `PR_NUMBER=$(echo "$EXISTING_PR" | jq -r .number)`; step 3 and the screenshot phase reuse it.

Diff against `origin/$BASE`, not the local base branch — in a Conductor worktree the local base often lags the remote, which would inflate or stale the diff (the `git fetch` above refreshes `origin/$BASE`). If the branch has no commits ahead of `origin/$BASE`, stop and tell the user.

No `bin/env` eval is needed here — it's only relevant to the screenshot phase, and `frontend-screenshots` runs its own in preflight. Backend-only PRs never touch it.

### 2. Classify the diff

A change is "frontend" if any changed path matches:
- `app/views/**` (`.erb`, `.html.erb`)
- `app/components/**` (ViewComponent templates or Ruby)
- `app/javascript/**`
- `app/assets/**`
- `config/tailwind*`, `tailwind.config.*`, `postcss.config.*`
- `*.scss`, `*.css`, `*.coffee`, `*.js`, `*.ts`

Record this as `FRONTEND=true|false` for the screenshot decision at the end of step 3.

### 3. Build the summary body and create/update the PR

Write a summary of the change (2–5 bullets based on the diff and recent commits) to a temp file. Follow the repo's existing PR body style — look at the last few merged PRs (`gh pr list --state merged --limit 5 --json body,title`) to match tone and length. Keep the title under ~70 chars.

Bias hard toward brevity — default to a one-line intro plus ~2-3 bullets, not the 5-bullet maximum. Reviewers skim. A bullet that fits on one line beats one that wraps three times — push detail down to the diff or commit log, not the body. If a per-file bullet starts feeling like an essay, compress to a single sentence naming the *kind* of change (e.g., "tightened description, trimmed unused allowed-tools, consolidated duplicated snippets") rather than enumerating each edit.

Cut anything the reviewer can see in the diff. Implementation mechanics — which HTTP client, file-mode flags, helper-method names, column renames, the exact tasks/files removed — belong to the diff, not the body. Keep only what the diff *doesn't* make obvious: what the PR adds, the single entry point a reviewer would use, and any non-obvious behavior or decision they'd otherwise have to reverse-engineer. When in doubt, leave it out and let the code speak. Aim for under ~6 bullets total including nested ones; if you're past that, regroup by category — but most PRs should land well under that.

Describe the end state, not the journey. Reviewers want to know what the PR does *now* — the diff that will land — not the order in which it was built. Avoid framings like "first pass" / "second pass", commit-hash references for stages of work that all merge into the same shipped diff, "originally we tried X then switched to Y", or play-by-play of how the conversation evolved. The git log preserves that. If a discarded approach is genuinely load-bearing context for the reviewer (e.g., explains why the chosen approach is structured oddly), one line is enough; otherwise omit. The same applies when *updating* an existing PR body: rewrite to describe the current diff, don't append a changelog of edits made since the last revision.

**No "Test plan" section unless the user asks.** Don't list things CI already covers — `bundle exec rspec ...`, `bin/lint`, `bin/dev` boots cleanly, etc. Those belong to CI, not the PR body. Only add a Test plan when there's reviewer-facing manual verification a human needs to do (e.g. "click X, confirm Y appears"), and only when the user requests it.

**No generic "covered by tests" bullet.** Drop summary bullets like "Covered by specs and a fixture" / "Added tests" / "Includes specs" — that a change is tested is assumed, so the bullet adds no information, and it names test *mechanics* (a fixture, a VCR cassette, an inline `StringIO`) that quietly go stale when the test approach changes mid-PR. Mention tests in the body only when *what* is verified is itself the reviewer-facing point (e.g. "adds a regression test for the UTF-8 download crash"), not merely that tests exist.

**No Claude Code attribution footer.** Don't append the "🤖 Generated with [Claude Code](https://claude.com/claude-code)" line (or any variant of it) to the body. The PR body should read like the human author wrote it.

Push the branch: `git push -u origin HEAD`.

- If `$EXISTING_PR` from step 1 was non-empty: `gh pr edit "$PR_NUMBER" --title "..." --body-file <tmp-body-file>` (`$PR_NUMBER` was parsed in step 1). Refresh the title to match the current diff (this is what an "update pr" request expects) unless the user already gave the PR a deliberate custom title you'd be clobbering — if unsure, keep the existing title and only update the body.
- Otherwise: `gh pr create --draft --base "$BASE" --title "..." --body-file <tmp-body-file>` (`$BASE` from step 0.5). Create as a draft by default; only omit `--draft` (or mark ready) if the user explicitly asks for a ready-for-review PR. Capture the new PR number into `PR_NUMBER` from the output for the screenshot phase.

Always pass the body via `--body-file` (not inline `--body`) to preserve formatting.

**If `FRONTEND=false`, stop here and return the PR URL.** If `FRONTEND=true`, read `references/screenshots.md` and follow it to capture before/after screenshots and post them as a PR comment (it uses `$EXISTING_PR`/`$PR_NUMBER` from the steps above). Screenshot tooling never blocks the PR — if it fails, return the PR URL and report the failure.
