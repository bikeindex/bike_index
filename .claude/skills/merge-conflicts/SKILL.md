---
name: merge-conflicts
description: >-
  How to bring a branch up to date and resolve git merge conflicts the way this
  repo expects — merge (never rebase or force-push), understand each side's
  intent before choosing, ask when a resolution isn't clear-cut, keep the merge
  commit to just the merge, and audit what merged *cleanly* before committing.
  Trigger whenever you're about to run
  `git merge`/`git pull`, sync a branch with `main`, "update from main", or
  resolve conflict markers left by a merge, cherry-pick, or interrupted pull —
  including bare phrasings like "fix the conflicts", "merge main in", or "this
  branch is behind". Not for merging data/files (PDFs, CSVs) or algorithms
  (merge sort) — this is strictly about git branch integration.
allowed-tools: Bash, Read, Edit, Write, Glob, Grep
---

# Resolving merge conflicts

When a branch needs to catch up with its base, or a merge/cherry-pick/pull leaves conflict markers, follow this — the goal is a clean, honest integration that a reviewer can trust and that never rewrites shared history.

## Determine the base branch first — don't assume `main`

"Update from base", "sync with main", "this branch is behind", "merge the base in" all need a base branch to merge *from*. **Don't default to `main`.** A branch is often stacked on another feature branch, and merging `main` instead silently pulls the wrong history — the diff looks "already up to date" against `main` while the real base has commits you're missing. Resolve the base in this order:

1. **A branch the user names** — "update from X" / "base is X" wins outright.
2. **An open PR's base** — `gh pr view <branch> --json baseRefName`. Also check the base of any feature branch you recently merged into this one (`gh pr view <that-branch> --json baseRefName`); a stack's branches usually share the same base.
3. **The upstream tracking ref**, if it names a branch other than this one's own remote mirror (`git rev-parse --abbrev-ref @{u}`).
4. **The Conductor workspace target branch** (from the workspace/system instructions) — a default hint, *not* the last word.

**Re-resolve the base every time — it moves.** When a base branch's PR merges, GitHub retargets the child PR (usually to `main`), so what you merged from last time may no longer be the base. Check `gh pr view <branch> --json baseRefName`, and `gh pr list` for whether the old base still has an open PR. A base whose PR has merged often keeps accumulating commits behind no PR at all; those aren't yours to integrate.

If 1–3 turn up nothing and the branch clearly builds on another feature branch — it was created by merging one in, was cut from `main` but layers work that lives on an unmerged branch, or the user talks about it as part of a stack — **ask which branch to update from (offer the likely candidate) rather than merging `main`.** Confirm before running the merge; a wrong base is expensive to unwind. Note that being 0-behind `main` proves nothing here — a stacked branch is normally 0-behind `main` and still far behind its real base.

## Bring a branch up to date

- `git fetch origin`, then `git merge --no-edit origin/<base>` (the base resolved above, not reflexively `main`).
- **Merge, never rebase.** Rebasing rewrites the branch's history; if the branch is already pushed, republishing it needs a force-push, and we never force-push. A merge commit keeps the real history and is always safe to push on top of.
- If uncommitted work blocks the merge, commit that work first (it belongs to the branch anyway), then merge.
- Already up to date → nothing to do.

### Base already merged? Merge its final commit *before* `main`

This repo squash-merges, so a merged base lands on `main` as one commit sharing no ancestry with the base's real commits. Merge `main` straight into the stacked branch and every file the base *added* comes back as an **add/add** conflict — git has no common ancestor to three-way merge against, so it hands you files you never touched.

Merge the base's tip first, then `main`:

```bash
gh pr view <base-pr> --json headRefOid --jq .headRefOid  # tip survives branch deletion
git fetch origin <sha>                                   # or refs/pull/<base-pr>/head
git merge --no-edit <sha>
git merge --no-edit origin/main
```

That makes your side byte-identical to what the squash put on `main`, so the add/add conflicts collapse and you're left only with files this branch actually changed. Measured on one base sitting a single commit ahead: 3 conflicts (`.env`, `bin/binx_hb`, a skill file) became 1 — the one real edit.

The branch is usually deleted locally *and* on the remote by then, so don't look for `origin/<base>`; `headRefOid` and `refs/pull/<n>/head` are how you reach the commit.

## Keep the merge commit to *just* the merge

A merge commit should contain **only** the reconciliation of the two histories — nothing else. Don't fold in lint fixes, refactors, renames, or "while I'm here" cleanups. Those are real changes a reviewer needs to see on their own; buried inside a merge they're invisible in most diff views and impossible to revert independently. Land them as separate commits *after* the merge.

## Resolving conflicts

When git leaves `<<<<<<<` / `=======` / `>>>>>>>` markers:

- **Understand each side before choosing.** The version on `main` and the version on the branch each exist for a reason. Read enough of both to know what each is trying to do — don't mechanically keep "ours" or "theirs." The correct resolution is often a combination, not one side wholesale.
- **Consider the branch's purpose.** What is this branch trying to accomplish? A conflict resolution that quietly drops the branch's intent (or reverts something `main` deliberately changed) is a bug, even if it compiles.
- **Ask when it isn't clear-cut.** If you can't confidently tell which side should win, or the two changes are semantically entangled, stop and ask the user rather than guessing. A wrong silent resolution is worse than a question.
- **Both sides added at the same spot? Order matters.** Keeping both isn't enough when either block has side effects. If the incoming block ends by reloading the page, anything of yours that depends on unsaved state has to come *after* it — concatenated the other way it still passes while testing nothing.
- **Don't blanket-replace a renamed string.** Two call sites that shared a string can have legitimately diverged; `sed`-ing the whole file changes the one that shouldn't move.
- After resolving, verify the result actually makes sense — the merged code should reflect both intents, not just parse. Run the relevant tests if the conflict touched logic.

## The dangerous part is what merged *cleanly*

Conflict markers are the easy case — git is asking for help. The silent breakages come from hunks it merged without asking, because a three-way merge keeps *your* side of any line it can't attribute to a common ancestor. A base that arrived as a **squash-merge** has history unrelated to yours, so git will cheerfully resurrect code that base deliberately deleted, in files it reports as auto-merged.

After every merge, before committing:

```bash
git diff origin/<base> -- app/ lib/ config/   # then account for every file listed
```

Every differing file must be explainable as *this branch's work* (or a sibling branch you're intentionally stacked on). Anything else is a resurrection or a stray. For a file that's mostly wrong, don't hand-patch hunks — `git checkout origin/<base> -- <file>` and re-apply your change on top.

**Resolving two files to opposite sides breaks the interface between them**, and neither one looks wrong on its own. Taking the base's version of a component while the helper that calls it auto-merges keeping your argument is an unknown-keyword error on every render, past a file-level audit that reports both as expected. Whenever you `checkout --theirs` something with callers, grep the arguments you dropped: `git grep -n '<kwarg>' -- app` should come back empty, or come back only where the base still accepts it.

This is what it catches, all of which has actually happened here:

- **Deleted code coming back.** A constant, predicate, or callback the base removed reappears, along with the call sites that reference it — reintroducing behavior the base decided against.
- **Another branch's change riding along.** A retention window, a flag, a tweak that came in when you merged a sibling branch and the base never took. Not yours to carry; reset it.
- **Committed churn in generated files.** `git checkout --` reverts to HEAD, not to the base — so once churn is committed it survives every later revert. Check VCR cassettes and lockfiles specifically; a diff that's only timestamps/nonces should be reset to the base.
- **Your side calling an API the base deleted.** Nothing conflicts: your file is untouched by the merge and the base's deletion lands cleanly, so the break is a `NoMethodError` at load. Fix it in the commit after the merge, never in it.

## Run the linter, not just the specs

`bin/lint` after every merge. A bad auto-merge that duplicates a method or strands a constant parses fine and passes its specs — `Lint/DuplicateMethods` is what catches it.

Then run specs for the merged area, **including the browser ones**. The base renaming or moving something your branch calls produces no conflict marker at all: a method that moved to a service, a route reshaped into a query param, copy your specs assert on. Those only surface at runtime.

`bin/rails db:migrate` too, when the merge brought migrations — the test database is maintained from the schema, so the specs stay green while every page in the browser is an `ActiveRecord::PendingMigrationError`.

## Never force-push

No exceptions, even on a personal branch. If history has already diverged from the remote and you're tempted to force-push, stop — recover with `git reset --soft <origin-branch>` to get the pushed commits back, then add follow-up work as new commits and push normally.
