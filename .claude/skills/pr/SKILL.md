---
name: pr
description: >-
  Create or update a pull request for the current branch. Trigger when the user
  asks to create/open/make a PR, or to edit/update/rewrite/fix the PR
  description, body, summary, or title — including bare phrasings like "update
  pr" or "update the PR" with no other object — for both new PRs and existing
  ones. Note this runs `/simplify`, `bin/lint`, a CLAUDE.md conformance pass and
  a merge from the base before writing the body — skipped when the ask is only to
  reword the description — and pushes the result. For
  frontend diffs, delegates the screenshot phase to `references/screenshots.md`,
  which captures desktop+mobile shots and posts them as a `## Screenshots` PR
  comment.
---

# Pull request workflow

Five sections, run in this order:

1. **Orient** — the working tree, and the base branch
2. **Prepare the branch** — merge, cleanup, migrations. Skipped for a description-only ask
3. **Publish** — read the final diff, write the body, push, create or update
4. **Screenshots** — frontend diffs only
5. **What this run taught you** — always last, whatever else ran

**Shell state does not persist between commands.** Each command below runs in its own shell, so a `BASE=main` in one is gone by the next. Substitute the real values into every command — write `origin/main`, not `origin/$BASE` — and carry the base branch and PR number in your head, not in the environment. Every `origin/main` below means "the base branch from **Orient**".

Run the `gh` commands as written. The appendix at the bottom covers the one environment that has no `gh`.

## Orient

### Check the working tree

`git status` (no `-uall`). Everything below diffs `origin/main...HEAD`, which only sees **committed** work, and the merge in **Prepare the branch** needs a clean tree — so the tree has to be clean before you go further.

- Uncommitted changes you made in this session: commit them now. Otherwise the cleanup, the classifier and the diff you describe all silently skip them, and the PR body describes the wrong diff.
- Uncommitted changes you didn't make: stop and ask. Don't sweep someone else's work into a commit.

### Determine the base branch

The base is the branch the PR goes off of — `main` by default. The head is always the current branch (`HEAD`), so the branch that sets the base is a *different* one the user points at: "a PR off of `release-2`", "base this on `release-2`", "onto/target `release-2`", "stacked on `<branch>`", or a `--base <branch>` argument. Naming the branch you're already on only identifies the head — the base stays `main`. If it's genuinely unclear whether a named branch is meant as the base, ask rather than guess. Never silently retarget an explicitly-named base to `main`.

When updating an **existing** PR, leave its base untouched — run `gh pr edit` without `--base`. Only retarget when the user explicitly asks.

## Prepare the branch

**Skipped in full when the ask is only to reword an existing PR's description** — fixing the wording shouldn't rewrite code. Everything else (creating a PR, "get this ready", an update after new commits) runs it.

### Update from the base

Bring the branch up to date so the PR reflects the current base and merges without surprises. Follow the `merge-conflicts` skill: `git fetch origin` then `git merge --no-edit origin/main`, merge (never rebase), keep the merge commit to just the merge, and resolve conflicts per that skill.

This has to happen before the cleanup below, which diffs against `origin/main`.

### Simplify, lint, and conform to CLAUDE.md

`references/pre-push-cleanup.md` has this in full: `/simplify`, `bin/lint` scoped to the branch's files, branch-scoped specs, a pass over the changed files against `CLAUDE.md`, the required spec and comment audits, and the cycle-type translation check. Commit everything it produces before re-dating migrations.

Both audits are required every run, not just when the diff looks messy. The spec one asks of every example the branch adds: *what bug does this fail on?* — and deletes the ones that only restate the code.

### Freshen stale migration timestamps

Migrations this branch adds have to be dated within the past 2 days, or the rollback/rename/re-migrate order in `references/pre-push-cleanup.md` re-dates them. Skip when the branch adds no migrations.

## Publish

### Gather branch state

Run in parallel:

- `git diff origin/main...HEAD --stat`
- `git diff origin/main...HEAD --name-only`
- `git log origin/main..HEAD --oneline`
- `gh pr view --json number,url,title,state`

Diff against `origin/main`, not the local base branch — in a Conductor worktree the local base often lags the remote, which would inflate or stale the diff. If you skipped **Prepare the branch**, `git fetch origin` first. If the branch has no commits ahead of `origin/main`, stop and tell the user.

`gh pr view` exits non-zero with "no pull requests found" when the branch has none — that's the answer to the create-or-update question below, not a broken command, and it's the normal case on a first run.

`gh pr view` returns MERGED and CLOSED PRs too. **Only a PR whose `state` is `OPEN` counts as existing** — for a merged or closed one, create a new PR rather than editing it. Note the number; the push and **Screenshots** both need it.

No `bin/env` eval is needed here — it's only relevant to the screenshot phase, and `frontend-screenshots` runs its own in preflight. Backend-only PRs never touch it.

### Classify the diff

The diff is frontend if a changed path matches one of these **and** renders a page a reviewer could look at:

- `app/views/**` (`.erb`, `.html.erb`, `.haml` — deprecated, but still most of the directory)
- `app/components/**` (ViewComponent templates or Ruby)
- `app/javascript/**`
- `app/assets/**`
- `config/tailwind*`, `tailwind.config.*`, `postcss.config.*`
- `*.scss`, `*.css`, `*.coffee`, `*.js`, `*.ts`

Excluded despite matching: mailer views (`app/views/*_mailer/**`, `app/views/user_emails/**`), API and JSON views (`app/views/api/**`, `*.json*`, `*.jbuilder`), and build config (`app/assets/config/manifest.js`, `esbuild.config.js`). A diff that only changes comments or non-rendering config isn't frontend either.

Record this as frontend true/false — it's what **Screenshots** gates on.

### Write the summary body

Write the body to a temp file. Read the last few merged PRs first — `gh pr list --state merged --limit 5 --json title,body` — they're the tone to match. The house shape is a short intro paragraph saying what was broken or what this is, then 2–4 bullets each opening with a bolded clause. Title under ~70 chars.

Rules:

- **Bias hard toward brevity.** Default to a one-line intro plus 2–3 bullets, not the maximum. A bullet that fits on one line beats one that wraps three times.
- **Cut anything visible in the diff.** Which HTTP client, file-mode flags, helper names, column renames, the exact files removed — that's the diff's job. Keep only what it doesn't make obvious: what the PR adds, the entry point a reviewer would use, and any non-obvious decision they'd otherwise reverse-engineer.
- **Describe the end state, not the journey.** No "first pass" / "second pass", no commit hashes for stages that all land in the same diff, no "originally we tried X then switched to Y". When updating an existing body, rewrite it to describe the current diff — don't append a changelog of edits since the last revision.
- **Reference branches by PR number.** A stacked base or a branch this builds on is `#3918`, not a branch name: `gh pr list --head <branch> --state all --json number --jq '.[0].number'`. Name the branch only when it has no PR.
- **No "Test plan" section unless the user asks.** Never list what CI already covers. Only reviewer-facing manual verification ("click X, confirm Y appears") qualifies, and only on request.
- **No generic "covered by tests" bullet.** That a change is tested is assumed, and naming test mechanics (a fixture, a cassette) goes stale. Mention tests only when *what* is verified is the reviewer-facing point ("adds a regression test for the UTF-8 download crash").
- **No Claude Code attribution footer**, here or in any comment this workflow posts. It should read like the human author wrote it.
- **Link the issue when there is one.** If the branch name, a commit message, or the user's request names an issue, close it from the body — `Closes #4103` on its own line. Don't invent a number.

If a bullet is turning into an essay, compress it to one sentence naming the *kind* of change.

### Push and create or update the PR

```bash
git push -u origin HEAD
```

Don't report the local branch name differing from the name in the invocation when the branch has no upstream — pushing `HEAD` creates a matching remote, so it's benign. Only flag a mismatch when the local branch already tracks a differently-named upstream. If the push is rejected as non-fast-forward, go back to **Prepare the branch**.

- **Open PR found above**: `gh pr edit <number> --title "..." --body-file <tmp-body-file>`. Refresh the title to match the current diff (that's what "update pr" expects) unless the user gave it a deliberate custom title — if unsure, keep the title and update only the body.

  **Read the current body before you replace it.** A human may have edited it since your last run — added a caveat, a reviewer note, a deploy instruction. Anything you can't account for as your own writing gets carried into the new body, or asked about. Don't overwrite it silently.
- **Otherwise**: `gh pr create --draft --base main --title "..." --body-file <tmp-body-file>`. Draft by default; only skip `--draft` if the user asks for ready-for-review. Note the new number for **Screenshots**.

Always pass the body via `--body-file`, not inline `--body`, to preserve formatting.

### What goes in a comment

This workflow posts **one kind of comment — the `## Screenshots` one — and at most one per PR**, edited in place on later runs. Everything else you have to say goes in the body when a reviewer needs it, and in your reply to the user otherwise. Findings, caveats, evidence you gathered, what you decided not to fix: none of those earn a comment of their own, however well they'd read as one. Don't invent a comment type because you have something to say.

The one that talks itself into existence is the "still accurate" update — a later push makes you wonder whether an earlier comment went stale, so you post that it hasn't. Re-run whatever produced it and edit that comment, or say nothing. Never reason your way to "it still holds" in place of re-running; whether a claim is still true is something to tell the user in chat.

## Screenshots

Two gates, either of which skips the section outright:

- **Not a frontend diff** — per the classifier above.
- **No `gh`, or no browser signed in to GitHub.** Then there is nowhere to host or post the images, so don't capture them and don't post anything in their place. Say so in your summary. The `gh`-less sandbox in the appendix is this case.

Otherwise read `references/screenshots.md` and follow it to capture before/after screenshots and post them as a PR comment. Screenshot tooling never blocks the PR — if it fails, report the failure and carry on to **What this run taught you**.

## What this run taught you

Last, before reporting the PR URL. Look back over the whole run and ask whether the repo's own instructions should change:

- **Did any skill mislead you?** A command that failed, a path or version that had moved, a step that didn't match what the repo does now — fix it in that skill. This skill included.
- **Did you work around something undocumented?** If the next run would hit the same wall, the fix belongs in the skill, not in your memory.
- **Did the branch establish a convention?** A new pattern, a rule you had to infer from existing code, or a guideline you found yourself explaining — that's `CLAUDE.md` (root, or the nested one nearest the code).
- **Did `/simplify` or the CLAUDE.md pass flag the same thing more than once?** A repeated correction is a missing written rule.

Most runs turn up nothing — say so and stop. When something does: if it's small and related to this PR, commit it onto the branch, push, and update the body if the change is worth a bullet. If it's larger or unrelated, tell the user what you'd change and where, and let them decide.

Then return the PR URL.

## Appendix: the sandbox with no `gh`

Only the Claude Code web sandbox (`/home/user/bike_index`) lacks the GitHub CLI; everywhere else the sections above run as written, and you shouldn't check. If a `gh` command comes back "command not found", swap in the GitHub MCP equivalents — the rest of the workflow is unchanged, including `git push`.

| Where | `gh` | MCP |
| --- | --- | --- |
| Publish | `gh pr view --json …,state` | `list_pull_requests`, `state: "open"`, `head: "bikeindex:<branch>"` |
| Publish | `gh pr list --state merged` | `list_pull_requests`, `state: "closed"` |
| Publish | `gh pr create --draft` | `create_pull_request`, `draft: true`, `head: "<branch>"` |
| Publish | `gh pr edit <n> --body-file` | `update_pull_request` |

Three traps in that column: `head` takes `owner:branch` when listing but a bare branch name when creating; the body is a string parameter, so `--body-file` has no equivalent; and `list_pull_requests` reports `merged: false` even for merged PRs (verified against #4122, which `pull_request_read` reports correctly) — which is why the branch-state query asks for open PRs rather than filtering `all` on that field.

**There is no Screenshots row because the section doesn't run here.** No `gh` means no browser session either, so nothing can be hosted or posted; skip it and say so, rather than reaching for `add_issue_comment` to post something in its place. PR #4126 is what that looks like when you don't: three comments telling one story, none of them replaceable by the next run.
