#!/bin/bash
# Host images for a PR comment from the Claude Code web sandbox, where GitHub's
# uploader is out of reach (no gh, and the MCP browser can't load github.com).
#
#   bash .claude/skills/github-pr-images/assets/commit_images.sh tmp/pr_screenshots/*.png
#
# Commits the files to the current branch, then deletes them in a second commit,
# and prints <img> tags whose src is pinned to the FIRST commit's sha. Those keep
# serving after the deletion - the blob stays reachable through the branch's
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
  { echo "not the web sandbox - use the browser uploader (SKILL.md steps 2-8)" >&2; exit 1; }

ROOT=$(git rev-parse --show-toplevel)
BRANCH=$(git symbolic-ref --quiet --short HEAD) ||
  { echo "detached HEAD - check out the PR's branch first" >&2; exit 1; }
[ "$BRANCH" != "main" ] || { echo "refusing to commit images to main" >&2; exit 1; }

# Resolve each argument against the CURRENT directory before moving to the root,
# and carry it as a root-relative path: that is what the raw URL needs, so an
# absolute path would otherwise produce `…/<sha>//home/user/…` and 404.
for image in "$@"; do
  [ -f "$image" ] || { echo "no such file: $image" >&2; exit 1; }
done
mapfile -t PATHS < <(realpath --relative-to="$ROOT" -- "$@")
for relative in "${PATHS[@]}"; do
  case "$relative" in
    ../*) echo "outside the repository: $relative" >&2; exit 1 ;;
  esac
done
cd "$ROOT"

# A tracked path would be left deleted by the cleanup commit, not restored
TRACKED=$(git ls-files -- "${PATHS[@]}")
[ -z "$TRACKED" ] ||
  { echo "already tracked - pass throwaway copies under tmp/ instead: $TRACKED" >&2; exit 1; }

# Anything already staged would ride into the screenshot commit, which the
# cleanup commit then doesn't remove. A pathspec on the commits would scope them,
# but `git commit -- <paths>` re-reads the working tree and so commits nothing
# after `git rm --cached` below - a clean index is what keeps both honest.
git diff --cached --quiet ||
  { echo "the index has staged changes - commit or reset them first" >&2; exit 1; }

# The push below carries every unpushed commit, and its tip is a skip-ci one, so
# CI would be skipped for real code riding along in the same push.
if UNPUSHED=$(git rev-list '@{u}..HEAD' 2>/dev/null); then
  [ -z "$UNPUSHED" ] ||
    { echo "unpushed commits on $BRANCH - push them first, or CI skips them too" >&2; exit 1; }
else
  echo "$BRANCH has no upstream - push it first, or CI skips every commit on it" >&2
  exit 1
fi

# skip-ci markers on both: ci.yml is `on: push` with no branch filter, so without
# them every screenshot post costs two full sharded runs.
git add -f -- "${PATHS[@]}"
git commit -q -m "Add PR screenshots [skip ci]

Deleted in the next commit; the URLs in the screenshots comment are pinned
to this commit's sha, so they keep resolving."
SHA=$(git rev-parse HEAD)

# --cached: drop them from the index but leave the files on disk, so a caller
# mid-sequence (a base-branch recapture) still has them.
git rm -q --cached -- "${PATHS[@]}"
git commit -q -m "Remove PR screenshots [skip ci]

Keeps the PR's Files changed empty; the blobs stay reachable at ${SHA:0:12}."

git push -q origin "$BRANCH"

REPO=$(git remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')
echo "hosted at $SHA (branch $BRANCH)"
# HTML rather than `![](url)`: the GitHub MCP server neutralizes a markdown image
# by backticking its URL, which posts an <img> with no src. Links and <img> survive.
# Encoding matters here too - a space or `#` in a filename truncates an unescaped src.
python3 - "$REPO" "$SHA" "${PATHS[@]}" <<'ENCODE'
import html, sys, urllib.parse
repo, sha, *paths = sys.argv[1:]
for path in paths:
    src = f"https://raw.githubusercontent.com/{repo}/{sha}/{urllib.parse.quote(path)}"
    print(f'<img alt="{html.escape(path.rsplit("/", 1)[-1], quote=True)}" src="{src}" />')
ENCODE
echo "note: the PR's head is now a skip-ci commit, so it shows no checks until the next code push" >&2
