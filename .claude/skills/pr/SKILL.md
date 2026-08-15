---
name: pr
description: >-
  Create or update a pull request for the current branch. Trigger when the user
  asks to create/open/make a PR, or to edit/update/rewrite/fix the PR
  description, body, summary, or title — including bare phrasings like "update
  pr" or "update the PR" with no other object — for both new PRs and existing
  ones. Note this runs `/simplify`, `bin/lint`, a CLAUDE.md conformance pass and
  a merge from the base before writing the body, and pushes the result. For
  frontend diffs, delegates the screenshot phase to `references/screenshots.md`,
  which captures desktop+mobile shots and posts them as a `## Screenshots` PR
  comment.
---

# Pull request workflow

Steps 1–10 run in order. Step 11 always runs last.

**Shell state does not persist between commands.** Each command below runs in its own shell, so a `BASE=main` in one is gone by the next. Substitute the real values into every command — write `origin/main`, not `origin/$BASE` — and carry the base branch and PR number in your head, not in the environment. Every `origin/main` below means "the base branch from step 2".

**No `gh` in the Claude Code web sandbox** (`/home/user/bike_index`). Check with `command -v gh`; if it's missing, every `gh` command below becomes its GitHub MCP equivalent — see the "No `gh` in the web sandbox" section of the `sandbox-test-setup` skill for the mapping.

### 1. Check the working tree and what's being asked

`git status` (no `-uall`). Every step below diffs `origin/main...HEAD`, which only sees **committed** work, and step 3's merge needs a clean tree — so the tree has to be clean before step 2.

- Uncommitted changes you made in this session: commit them now. Otherwise steps 4, 5 and 7 silently skip them and the PR body describes the wrong diff.
- Uncommitted changes you didn't make: stop and ask. Don't sweep someone else's work into a commit.

Then pick the mode:

- **Body-only** — the user asked to edit/rewrite/fix the description, body, summary or title of an existing PR and nothing else. Skip steps 3, 4 and 5 (no merge, no code edits, no migration re-dating) and go 1 → 2 → 6 → 7 → 8 → 9. A request to reword the description shouldn't rewrite code.
- **Full** — everything else (creating a PR, "get this ready", or an update after new commits). Run every step.

### 2. Determine the base branch

The base is the branch the PR goes off of — `main` by default. The head is always the current branch (`HEAD`), so the branch that sets the base is a *different* one the user points at: "a PR off of `release-2`", "base this on `release-2`", "onto/target `release-2`", "stacked on `<branch>`", or a `--base <branch>` argument. Naming the branch you're already on only identifies the head — the base stays `main`. If it's genuinely unclear whether a named branch is meant as the base, ask rather than guess. Never silently retarget an explicitly-named base to `main`.

When updating an **existing** PR, leave its base untouched — run `gh pr edit` without `--base`. Only retarget when the user explicitly asks.

### 3. Update from the base

Bring the branch up to date so the PR reflects the current base and merges without surprises. Follow the `merge-conflicts` skill: `git fetch origin` then `git merge --no-edit origin/main`, merge (never rebase), keep the merge commit to just the merge, and resolve conflicts per that skill.

This has to happen before step 4, which diffs against `origin/main`.

### 4. Simplify, lint, and conform to CLAUDE.md

Invoke the `/simplify` command to review the changed code for reuse, simplification, and efficiency cleanups and apply them. It's quality-only — it won't touch correctness — so it's safe to run unattended; if it reports nothing to clean up, move on.

Then run `bin/lint` to auto-format (it also picks up whatever `/simplify` just changed). Always `bin/lint`, never another formatter or `standardrb` directly. Scope it to the branch's files rather than walking the whole repo:

```bash
bin/lint $(git diff --name-only --diff-filter=d origin/main...HEAD)
```

`--diff-filter=d` drops deleted paths so they don't show up as "Not found". Files with no linter (`.haml`, `.scss`, `.md`) are skipped, so a branch touching none of the lintable types exits cleanly rather than looking like a failure. It takes directories too, so `bin/lint app/components/foo` works while you're still iterating. Never revert what the linter wrote — if a too-broad run reformats files outside the branch, those fixes stay in the diff.

Scope specs the same way — the ones covering what the branch changed, never a bare `bundle exec rspec` or a whole top-level directory (see the `rspec-testing` skill). CI runs the full suite; a green PR isn't your job to prove locally.

Then review the changed files against the repo's `CLAUDE.md` (root and any nested ones in touched directories) and fix what doesn't conform — code style (functional style, no argument mutation, omitted hash values like `{x:}`, private methods, unabbreviated names), testing conventions, and frontend rules. Only touch lines this branch already changed.

Class methods go in a `class << self` block when the class has more than 5 of them, or when any of them should be private — `BugReport` is the pattern.

**Then review every comment the branch adds or edits — this is required, not conditional on the diff looking clean.** List them with their files:

```bash
git diff origin/main...HEAD -U0 -- '*.rb' '*.erb' '*.js' '*.ts' '*.coffee' '*.scss' '*.css' '*.rake' |
  grep -E '^(\+\+\+ |\+.*(#|//|<%#|/\*))'
```

The `+++ b/…` lines keep each hit attached to its file; the code-path filter keeps markdown headings out. It catches trailing comments too, and over-matches on `#{}` interpolation — that's fine, the list is candidates to judge, not verdicts.

Judge each against the **Comments** section of `CLAUDE.md` and reach a verdict of keep / razor / delete on every line — a comment survives only by carrying a *why* the code can't. Deleting is the common outcome, razoring the next most common; leaving a block untouched should be the exception you can justify. Watch hardest for the ones you wrote to explain your own reasoning as you worked: narration of the change, mechanism the code already shows, and a second sentence justifying the first.

Then check the branch's translations for a hardcoded "bike" where the string means the registration's cycle type — a registration is as often an e-scooter, a stroller or a wheelchair:

```bash
git diff origin/main...HEAD -- '*.en.yml' 'config/locales/en.yml' | grep -in '^+[^+].*bike'
```

Read each hit. Key names (`about_this_bike:`), the product name ("Bike Index"), and copy that really is bike-only are fine; a value saying "bike" about the registration is not. Fix it by interpolating `%{bike_type}` in the value and passing `bike_type: bike.type` at the call site — `Registrations::Show::CurrentAlerts::ClaimImpound` and `Registrations::Show::WrapperConsumer` are the pattern, and `spec/components/registrations/show/current_alerts/claim_impound/component_spec.rb` shows how to cover it. After hand-editing a `component.en.yml`, run `bundle exec rails prepare_translations` — `bin/lint` doesn't normalize YAML.

Commit these edits before continuing.

### 5. Freshen stale migration timestamps

Every migration this branch adds must be dated within the past 2 days.

```bash
git diff origin/main...HEAD --name-only --diff-filter=A -- db/migrate db/analytics_migrate
date -d '2 days ago' +%Y%m%d%H%M%S 2>/dev/null || date -v-2d +%Y%m%d%H%M%S
```

(GNU `date` takes `-d`, BSD/macOS `date` takes `-v` — the fallback covers both.) Compare each filename's leading timestamp against that cutoff. No added migrations, nothing stale, or a timestamp in the *future* → skip this step. The rollback below needs a working local database; if it isn't reachable, say so and leave the timestamps alone rather than failing mid-workflow.

For each stale migration, in this order (rollback must happen while the old version is still on disk):

1. Roll it back: `bin/rails db:migrate:down:primary VERSION=<old-timestamp>` (`db:migrate:down:analytics` for `db/analytics_migrate` files) — the un-namespaced `db:migrate:down` refuses in this multi-database app.
2. `git mv` the file to the same name with a fresh `date +%Y%m%d%H%M%S` timestamp — when re-dating several, keep their relative order with incrementing timestamps.
3. `bin/rails db:migrate` to re-apply and regenerate the structure files — never hand-edit `db/structure.sql`.
4. Commit the renames together with the regenerated structure files.

### 6. Gather branch state

Run in parallel:

- `git diff origin/main...HEAD --stat`
- `git diff origin/main...HEAD --name-only`
- `git log origin/main..HEAD --oneline`
- `gh pr view --json number,url,title,state`

Diff against `origin/main`, not the local base branch — in a Conductor worktree the local base often lags the remote, which would inflate or stale the diff. In body-only mode (step 1), `git fetch origin` first, since step 3 didn't run. If the branch has no commits ahead of `origin/main`, stop and tell the user.

`gh pr view` returns MERGED and CLOSED PRs too. **Only a PR whose `state` is `OPEN` counts as existing** — for a merged or closed one, create a new PR in step 9 rather than editing it. Note the number for steps 9 and 10.

Without `gh`, ask for open PRs only — `mcp__github__list_pull_requests` with `state: "open"` and `head: "bikeindex:<branch>"`. Don't list `all` and filter on the `merged` field: the list endpoint reports `merged: false` even for merged PRs (verified against #4122, which `pull_request_read` correctly reports as merged). `state: "open"` sidesteps it.

No `bin/env` eval is needed here — it's only relevant to the screenshot phase, and `frontend-screenshots` runs its own in preflight. Backend-only PRs never touch it.

### 7. Classify the diff

The diff is frontend if a changed path matches one of these **and** renders a page a reviewer could look at:

- `app/views/**` (`.erb`, `.html.erb`)
- `app/components/**` (ViewComponent templates or Ruby)
- `app/javascript/**`
- `app/assets/**`
- `config/tailwind*`, `tailwind.config.*`, `postcss.config.*`
- `*.scss`, `*.css`, `*.coffee`, `*.js`, `*.ts`

Excluded despite matching: mailer views (`app/views/*_mailer/**`, `app/views/user_emails/**`), API and JSON views (`app/views/api/**`, `*.json*`, `*.jbuilder`), and build config (`app/assets/config/manifest.js`, `esbuild.config.js`). A diff that only changes comments or non-rendering config isn't frontend either.

Record this as frontend true/false for step 10.

### 8. Write the summary body

Write the body to a temp file. Read the last few merged PRs first (`gh pr list --state merged --limit 5 --json title,body`; without `gh`, `mcp__github__list_pull_requests` with `state: "closed"`) — they're the tone to match. The house shape is a short intro paragraph saying what was broken or what this is, then 2–4 bullets each opening with a bolded clause. Title under ~70 chars.

Rules:

- **Bias hard toward brevity.** Default to a one-line intro plus 2–3 bullets, not the maximum. A bullet that fits on one line beats one that wraps three times.
- **Cut anything visible in the diff.** Which HTTP client, file-mode flags, helper names, column renames, the exact files removed — that's the diff's job. Keep only what it doesn't make obvious: what the PR adds, the entry point a reviewer would use, and any non-obvious decision they'd otherwise reverse-engineer.
- **Describe the end state, not the journey.** No "first pass" / "second pass", no commit hashes for stages that all land in the same diff, no "originally we tried X then switched to Y". When updating an existing body, rewrite it to describe the current diff — don't append a changelog of edits since the last revision.
- **Reference branches by PR number.** A stacked base or a branch this builds on is `#3918`, not a branch name: `gh pr list --head <branch> --state all --json number --jq '.[0].number'`. Name the branch only when it has no PR.
- **No "Test plan" section unless the user asks.** Never list what CI already covers. Only reviewer-facing manual verification ("click X, confirm Y appears") qualifies, and only on request.
- **No generic "covered by tests" bullet.** That a change is tested is assumed, and naming test mechanics (a fixture, a cassette) goes stale. Mention tests only when *what* is verified is the reviewer-facing point ("adds a regression test for the UTF-8 download crash").
- **No Claude Code attribution footer.** The body should read like the human author wrote it.

If a bullet is turning into an essay, compress it to one sentence naming the *kind* of change.

### 9. Push and create or update the PR

```bash
git push -u origin HEAD
```

Don't report the local branch name differing from the name in the invocation when the branch has no upstream — pushing `HEAD` creates a matching remote, so it's benign. Only flag a mismatch when the local branch already tracks a differently-named upstream. If the push is rejected as non-fast-forward, go back to step 3.

- **Open PR from step 6**: `gh pr edit <number> --title "..." --body-file <tmp-body-file>`. Refresh the title to match the current diff (that's what "update pr" expects) unless the user gave it a deliberate custom title — if unsure, keep the title and update only the body.
- **Otherwise**: `gh pr create --draft --base main --title "..." --body-file <tmp-body-file>`. Draft by default; only skip `--draft` if the user asks for ready-for-review. Note the new number for step 10.

Always pass the body via `--body-file`, not inline `--body`, to preserve formatting.

### 10. Screenshots (frontend diffs only)

If step 7 said not frontend, skip this step. Otherwise read `references/screenshots.md` and follow it to capture before/after screenshots and post them as a PR comment. Screenshot tooling never blocks the PR — if it fails, report the failure and carry on to step 11.

### 11. Review what this run taught you

Last, before reporting the PR URL. Look back over the whole run and ask whether the repo's own instructions should change:

- **Did any skill mislead you?** A command that failed, a path or version that had moved, a step that didn't match what the repo does now — fix it in that skill. This skill included.
- **Did you work around something undocumented?** If the next run would hit the same wall, the fix belongs in the skill, not in your memory.
- **Did the branch establish a convention?** A new pattern, a rule you had to infer from existing code, or a guideline you found yourself explaining — that's `CLAUDE.md` (root, or the nested one nearest the code).
- **Did `/simplify` or the CLAUDE.md pass flag the same thing more than once?** A repeated correction is a missing written rule.

Most runs turn up nothing — say so and stop. When something does: if it's small and related to this PR, commit it onto the branch, push, and update the body if the change is worth a bullet. If it's larger or unrelated, tell the user what you'd change and where, and let them decide.

Then return the PR URL.
