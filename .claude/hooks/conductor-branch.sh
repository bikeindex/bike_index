#!/bin/bash
# Conductor names a workspace's branch <name>-v1 when another worktree already
# holds <name>. Move this checkout onto <name> itself, so commits land on the
# branch the PR shows.
set -uo pipefail

ROOT=$(git -C "${CLAUDE_PROJECT_DIR:-$PWD}" rev-parse --show-toplevel 2>/dev/null) || exit 0
LOCAL=$(git -C "$ROOT" branch --show-current)
UPSTREAM=$(git -C "$ROOT" rev-parse --abbrev-ref '@{u}' 2>/dev/null) || exit 0
NAME=${UPSTREAM#origin/}
[[ "$LOCAL" =~ ^"$NAME"-v[0-9]+$ ]] || exit 0

HOLDER=$(git -C "$ROOT" worktree list --porcelain |
  awk -v ref="branch refs/heads/$NAME" '/^worktree /{path=substr($0, 10)} $0 == ref {print path}')
# detaching at the same commit leaves that worktree's files, staged or not, as they are
[[ -n "$HOLDER" ]] && git -C "$HOLDER" checkout -q --detach
reattach() { [[ -n "$HOLDER" ]] && git -C "$HOLDER" checkout -q "$NAME"; }

if ! git -C "$ROOT" checkout -q "$NAME"; then
  reattach
  echo "Couldn't switch $ROOT from $LOCAL to $NAME - fix that before committing anything."
  exit 0
fi
if ! git -C "$ROOT" merge -q --no-edit "$LOCAL"; then
  git -C "$ROOT" merge --abort
  git -C "$ROOT" checkout -q "$LOCAL"
  reattach
  echo "$LOCAL and $NAME have diverged and don't merge cleanly - still on $LOCAL. Merge it into $NAME by hand (the merge-conflicts skill), then delete $LOCAL."
  exit 0
fi
# -d also wants it merged into its upstream, which unpushed work on it isn't
git -C "$ROOT" merge-base --is-ancestor "$LOCAL" HEAD && git -C "$ROOT" branch -q -D "$LOCAL"
echo "Switched this checkout from $LOCAL to $NAME, merged $LOCAL in and deleted it${HOLDER:+ ($HOLDER was detached to free $NAME)}."
