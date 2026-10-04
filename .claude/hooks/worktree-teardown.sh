#!/bin/bash
# A WorktreeRemove hook replaces git's removal, so bin/workspace_teardown does the removing
set -uo pipefail

WORKTREE=$(jq -r '.worktree_path // empty')
[[ "$WORKTREE" == */.claude/worktrees/* && -x "$WORKTREE/bin/workspace_teardown" ]] || exit 0

cd "$WORKTREE" && bin/workspace_teardown >&2
