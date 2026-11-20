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
# It hosts copies under tmp/pr_hosted/ with the branch prefix and any run of six or more
# digits dropped from the name: some sessions' comment tools mangle a URL holding the
# `<branch>-<page>-20261120-174501-desktop.png` names frontend-screenshots writes (#4847).
# The printed alt keeps the name you passed, so each tag still pairs with its shot.
#
# The images live only in the branch's history. This repo squash-merges, so they
# never reach main; once the branch is deleted they become unreachable, and the
# URLs last until GitHub garbage-collects them. Good enough for review, not an
# archive - see references/web-sandbox.md.
set -euo pipefail

[ "$#" -gt 0 ] || { echo "usage: $0 <image>..." >&2; exit 2; }

# Sandbox-only by design: anywhere else has gh --attach, whose
# user-attachments URLs are permanent and leave no commits behind.
[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] ||
  { echo "not the web sandbox - use gh --attach (SKILL.md)" >&2; exit 1; }

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

# Host copies under short names; see the header for why
BRANCH_PREFIX="${BRANCH//\//-}-"
ORIGINALS=("${PATHS[@]}")
PATHS=()
mkdir -p tmp/pr_hosted
for original in "${ORIGINALS[@]}"; do
  name=$(basename "$original")
  name=${name#"$BRANCH_PREFIX"}
  name=$(printf '%s' "$name" | sed -E 's/-?[0-9]{6,}//g')
  PATHS+=("tmp/pr_hosted/$name")
done
DUPLICATES=$(printf '%s\n' "${PATHS[@]}" | sort | uniq -d)
[ -z "$DUPLICATES" ] ||
  { echo "two images would be hosted under the same name: $DUPLICATES" >&2; exit 1; }
for index in "${!ORIGINALS[@]}"; do
  [ "${ORIGINALS[$index]}" = "${PATHS[$index]}" ] || cp -f "${ORIGINALS[$index]}" "${PATHS[$index]}"
done

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

git add -f -- "${PATHS[@]}"
git commit -q -m "Add PR screenshots

Deleted in the next commit; the URLs in the screenshots comment are pinned
to this commit's sha, so they keep resolving."
SHA=$(git rev-parse HEAD)

# --cached: drop them from the index but leave the files on disk, so a caller
# mid-sequence (a base-branch recapture) still has them.
git rm -q --cached -- "${PATHS[@]}"
git commit -q -m "Remove PR screenshots

Keeps the PR's Files changed empty; the blobs stay reachable at ${SHA:0:12}."

git push -q origin "$BRANCH"

REPO=$(git remote get-url origin | sed -E 's#^.*github\.com[:/]##; s#\.git$##')
echo "hosted at $SHA (branch $BRANCH)"
# HTML rather than `![](url)`: the GitHub MCP server neutralizes a markdown image
# by backticking its URL, which posts an <img> with no src. Links and <img> survive.
# Encoding matters here too - a space or `#` in a filename truncates an unescaped src.
python3 - "$REPO" "$SHA" "${#ORIGINALS[@]}" "${ORIGINALS[@]}" "${PATHS[@]}" <<'ENCODE'
import html, sys, urllib.parse
repo, sha, count, *rest = sys.argv[1:]
count = int(count)
for original, path in zip(rest[:count], rest[count:]):
    src = f"https://raw.githubusercontent.com/{repo}/{sha}/{urllib.parse.quote(path)}"
    print(f'<img alt="{html.escape(original.rsplit("/", 1)[-1], quote=True)}" src="{src}" />')
ENCODE
