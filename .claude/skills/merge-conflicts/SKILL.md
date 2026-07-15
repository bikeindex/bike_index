---
name: merge-conflicts
description: >-
  How to bring a branch up to date and resolve git merge conflicts the way this
  repo expects — merge (never rebase or force-push), understand each side's
  intent before choosing, ask when a resolution isn't clear-cut, and keep the
  merge commit to just the merge. Trigger whenever you're about to run
  `git merge`/`git pull`, sync a branch with `main`, "update from main", or
  resolve conflict markers left by a merge, cherry-pick, or interrupted pull —
  including bare phrasings like "fix the conflicts", "merge main in", or "this
  branch is behind". Not for merging data/files (PDFs, CSVs) or algorithms
  (merge sort) — this is strictly about git branch integration.
allowed-tools: Bash, Read, Glob, Grep
---

# Resolving merge conflicts

This repo's target base is `origin/main`. When a branch needs to catch up with the base, or a merge/cherry-pick/pull leaves conflict markers, follow this — the goal is a clean, honest integration that a reviewer can trust and that never rewrites shared history.

## Bring a branch up to date

- `git fetch origin`, then `git merge --no-edit origin/main`.
- **Merge, never rebase.** Rebasing rewrites the branch's history; if the branch is already pushed, republishing it needs a force-push, and we never force-push. A merge commit keeps the real history and is always safe to push on top of.
- If uncommitted work blocks the merge, commit that work first (it belongs to the branch anyway), then merge.
- Already up to date → nothing to do.

## Keep the merge commit to *just* the merge

A merge commit should contain **only** the reconciliation of the two histories — nothing else. Don't fold in lint fixes, refactors, renames, or "while I'm here" cleanups. Those are real changes a reviewer needs to see on their own; buried inside a merge they're invisible in most diff views and impossible to revert independently. Land them as separate commits *after* the merge.

## Resolving conflicts

When git leaves `<<<<<<<` / `=======` / `>>>>>>>` markers:

- **Understand each side before choosing.** The version on `main` and the version on the branch each exist for a reason. Read enough of both to know what each is trying to do — don't mechanically keep "ours" or "theirs." The correct resolution is often a combination, not one side wholesale.
- **Consider the branch's purpose.** What is this branch trying to accomplish? A conflict resolution that quietly drops the branch's intent (or reverts something `main` deliberately changed) is a bug, even if it compiles.
- **Ask when it isn't clear-cut.** If you can't confidently tell which side should win, or the two changes are semantically entangled, stop and ask the user rather than guessing. A wrong silent resolution is worse than a question.
- After resolving, verify the result actually makes sense — the merged code should reflect both intents, not just parse. Run the relevant tests if the conflict touched logic.

## Never force-push

No exceptions, even on a personal branch. If history has already diverged from the remote and you're tempted to force-push, stop — recover with `git reset --soft <origin-branch>` to get the pushed commits back, then add follow-up work as new commits and push normally.
