# Hosting images from the Claude Code web sandbox

SKILL.md's browser route can't run here, for two independent reasons: the MCP
browser can't verify github.com, and GitHub's uploader needs a logged-in web
session that can't be established headlessly. Fixing the first buys nothing
while the second stands. The `sandbox-test-setup` skill's `references/web-sandbox.md`
is where the browser's limits are described; don't re-derive them here.

So this route hosts the images **in the branch's own history** instead, and posts
through the GitHub MCP tools rather than `gh`, which isn't installed here.

Use it only when `$CLAUDE_CODE_REMOTE` is `true`. Everywhere else the browser
uploader is better: its `user-attachments/assets/` URLs are permanent and leave no
commits behind.

## What it does

`assets/commit_images.sh` commits the images to the PR's branch, then deletes them
in a second commit, and prints raw URLs pinned to the **first** commit's sha:

```bash
bash .claude/skills/github-pr-images/assets/commit_images.sh tmp/pr_screenshots/*.png
```

```
hosted at 9691ad9c48a924fcc42be3e384f9801ce7b79d1f (branch claude/…)
![probe-desktop.png](https://raw.githubusercontent.com/bikeindex/bike_index/9691ad9…/tmp/pr_screenshots/probe-desktop.png)
```

A blob stays reachable through the branch's history after the file is deleted, so
those URLs keep serving `image/png` — which is what GitHub's camo needs to render
them in a comment. The two commits cancel out, so the PR's **Files changed** stays
empty; only the commit list shows the pair.

The script pushes once, for both commits. It also:

- refuses outside the sandbox, on `main`, and on a detached HEAD
- refuses a **tracked** path, which its cleanup commit would leave deleted
- `git rm --cached`, so the images stay on disk for a caller mid-sequence (the
  base-branch recapture in the `pr` skill's screenshot phase needs them)
- puts `[skip ci]` on both commits — `ci.yml` is `on: push` with no branch filter,
  so without it one screenshot post costs two full sharded runs

## What it costs

The images live only in that branch's history. This repo squash-merges, so they
never reach `main` and no clone pays for them — but once the branch is deleted
the commits are unreachable, and the URLs last only until GitHub garbage-collects
them. Unreachable objects usually survive a long time and GitHub's camo caches
what it has rendered, neither of which is a guarantee.

**That makes this good enough for review, not an archive.** If a merged PR's
screenshots need to still be there in a year, host them somewhere ref-independent
— a release asset, uploaded by a workflow, since the API isn't reachable from
here.

## Posting the comment without `gh`

Same rules as SKILL.md step 8 — one `## Screenshots` comment per PR, edited in
place rather than duplicated — with the MCP tools in place of `gh`:

| SKILL.md | here |
| --- | --- |
| `gh pr view --json number` | `mcp__github__list_pull_requests` with `head: "bikeindex:<branch>"`, `state: "open"` |
| `gh api user --jq .login` | `mcp__github__get_me` |
| `gh api …/issues/N/comments` | `mcp__github__issue_read` with `method: "get_comments"` (paginate with `page`) |
| `gh pr comment` | `mcp__github__add_issue_comment` |
| `gh api -X PATCH …/comments/ID` | `mcp__github__update_issue_comment` |

Find the existing comment the same way — authored by `get_me`'s login, body
starting `## Screenshots` — and page through `get_comments`, since on a busy PR it
won't be on the first page.

## Verifying

Unlike `user-attachments/assets/` URLs, these are plain public files, so `curl`
settles it and no browser is needed:

```bash
curl -sI "<url>" -o /dev/null -w '%{http_code} %{content_type}\n'   # want: 200 image/png
```

A `404` means the push didn't land, or the URL names a branch rather than the sha
— a branch ref stops resolving the moment the cleanup commit removes the file,
which is the whole reason the script pins the sha.
