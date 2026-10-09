#!/bin/bash
set -uo pipefail

ROOT=$(git -C "$(jq -r .cwd)" rev-parse --show-toplevel 2>/dev/null) || exit 0
[[ "$ROOT" == */.claude/worktrees/* && ! -f "$ROOT/.workspace_id" ]] || exit 0

# see mise-shims.sh
command -v mise >/dev/null && eval "$(mise activate bash --shims)"

# bin/setup backgrounds redis-server, which would hold a captured stdout open;
# tmp/ because bin/setup's log:clear truncates log/*.log
LOG="$ROOT/tmp/workspace_setup.log"
if (cd "$ROOT" && bin/workspace_setup --without_seeds) >"$LOG" 2>&1; then
  echo "This worktree was set up by bin/workspace_setup --without_seeds (WORKSPACE_ID $(<"$ROOT/.workspace_id")). The database is unseeded."
else
  echo "bin/workspace_setup --without_seeds failed in this worktree - see $LOG, fix it and re-run it before using bin/env, rspec or the dev server."
fi
