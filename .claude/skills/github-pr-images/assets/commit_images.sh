#!/bin/bash
# Host images for a PR comment from the Claude Code web sandbox, where GitHub's
# uploader is out of reach (no gh, and the MCP browser can't load github.com).
#
#   bash .claude/skills/github-pr-images/assets/commit_images.sh tmp/pr_screenshots/*.png
#
# Commits the files to the current branch, then deletes them in a second commit,
# and prints raw.githubusercontent URLs pinned to the FIRST commit's sha. Those
# keep serving after the deletion - the blob stays reachable through the branch's
# history - so the PR's Files changed stays empty while the images render.
#
# The images live only in the branch's history. This repo squash-merges, so they
# never reach main; once the branch is deleted they become unreachable, and the
# URLs last until GitHub garbage-collects them. Good enough for review, not an
# archive - see references/web-sandbox.md.
set -euo pipefail

[ "$#" -gt 0 ] || { echo "usage: $0 <image>..." >&2; exit 2; }

# Sandbox-only by design: anywhere else has the browser uploader, whose
# user-attachments URLs are permanent and leave no commits behind.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] ||
  { echo "not the web sandbox - use the browser uploader (SKILL.md steps 2-7)" >&2; exit 1; }

cd "$(git rev-parse --show-toplevel)"
BRANCH=$(git symbolic-ref --quiet --short HEAD) ||
  { echo "detached HEAD - check out the PR's branch first" >&2; exit 1; }
[ "$BRANCH" != "main" ] || { echo "refusing to commit images to main" >&2; exit 1; }

for image in "$@"; do
  [ -f "$image" ] || { echo "no such file: $image" >&2; exit 1; }
  # A tracked path would be left deleted by the cleanup commit, not restored
  git ls-files --error-unmatch "$image" >/dev/null 2>&1 &&
    { echo "$image is tracked - pass a throwaway copy under tmp/ instead" >&2; exit 1; }
done

# [skip ci] on both: ci.yml is `on: push` with no branch filter, so without it
# every screenshot post costs two full sharded runs.
git add -f -- "$@"
git commit -q -m "Add PR screenshots [skip ci]

Deleted in the next commit; the URLs in the screenshots comment are pinned
to this commit's sha, so they keep resolving."
SHA=$(git rev-parse HEAD)

# --cached: drop them from the index but leave the files on disk, so a caller
# mid-sequence (a base-branch recapture) still has them.
git rm -q --cached -- "$@"
git commit -q -m "Remove PR screenshots [skip ci]

Keeps the PR's Files changed empty; the blobs stay reachable at ${SHA:0:12}."

git push -q -u origin "$BRANCH"

REPO=$(git remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')
echo "hosted at $SHA (branch $BRANCH)"
for image in "$@"; do
  echo "![$(basename "$image")](https://raw.githubusercontent.com/$REPO/$SHA/$image)"
done
