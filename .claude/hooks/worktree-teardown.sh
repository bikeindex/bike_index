#!/bin/bash
# A WorktreeRemove hook replaces git's removal, so this removes the worktree once bin/workspace_teardown has run
set -uo pipefail

WORKTREE=$(jq -r '.worktree_path // empty')
[[ "$WORKTREE" == */.claude/worktrees/* ]] || exit 0
MAIN=$(dirname "$(git -C "$WORKTREE" rev-parse --path-format=absolute --git-common-dir)")

# git worktree remove refuses a dirty worktree, so its databases stay with it
if [[ -n "$(git -C "$WORKTREE" status --porcelain)" ]]; then
  echo "$WORKTREE has uncommitted changes; leaving it and its databases" >&2
  exit 1
fi

[[ -x "$WORKTREE/bin/workspace_teardown" ]] && (cd "$WORKTREE" && bin/workspace_teardown >&2)
git -C "$MAIN" worktree remove "$WORKTREE" >&2
