# Hosting images from the Claude Code web sandbox

SKILL.md's browser route can't run here: the MCP browser can't verify github.com,
and the uploader needs a logged-in session no headless browser can get — fixing the
first buys nothing while the second stands.

So this route commits the images to the PR's branch instead, and posts through the
GitHub MCP tools. It stands in for **all** of SKILL.md: step 1's PR lookup and step
8's posting are the MCP calls below, steps 2 to 7 are one script, step 9 is `curl`.

Use it only when `$CLAUDE_CODE_REMOTE` is `true`. Elsewhere the browser uploader's
`user-attachments` URLs are permanent and leave no commits behind.

## Hosting

```bash
bash .claude/skills/github-pr-images/assets/commit_images.sh tmp/pr_screenshots/*.png
```

It commits the images, deletes them in a second commit, pushes once, and prints one
`<img>` per file pinned to the **first** commit's sha:

```
hosted at 9223ff3fa4… (branch claude/…)
<img alt="homepage-desktop.png" src="https://raw.githubusercontent.com/…/9223ff3fa4…/tmp/pr_screenshots/homepage-desktop.png" />
```

The blob stays reachable through the branch's history, so those URLs keep serving
after the deletion while the PR's **Files changed** stays empty.

**Post the tags verbatim — never rewrap them as `![](url)`.** The MCP server
backticks a markdown image's URL, posting an `<img>` with no `src`; links and HTML
`<img>` pass through untouched. Widths belong to the caller — the `pr` skill's table
wants `width="500"` desktop, `"250"` mobile.

**Call it once, after every capture including the base branch's.** Each call costs
two commits and a push, and it refuses on a detached HEAD, so it can't run mid-checkout
anyway.

It also refuses outside the sandbox, on `main`, on a **tracked** path (the cleanup
commit would leave that deleted), on a **dirty index** (staged changes ride into the
screenshot commit and survive the cleanup), and on **unpushed commits** (the push
carries them under a skip-ci tip, so CI skips real code). `git rm --cached` keeps the
files on disk for a later recapture.

Both commits carry `[skip ci]`, since `ci.yml` is `on: push` with no branch filter.
That leaves the PR's head on a skip-ci commit showing **no checks** until the next
code push — say so, or a reviewer reads it as a CI failure.

## What it costs

The images live only in that branch's history. This repo squash-merges, so they
never reach `main` and no clone pays for them — but a deleted branch leaves them
unreachable and eventually collectable. **Good for review, not an archive**: for
permanence use a release asset uploaded by a workflow, since the API isn't reachable
from here.

## Posting, without `gh`

Same rules as SKILL.md step 8 — one `## Screenshots` comment per PR, edited in place.
Find it by `get_me`'s login and a body starting `## Screenshots`, paging through
`get_comments` since on a busy PR it won't be on the first page.

| SKILL.md | here |
| --- | --- |
| `gh pr view --json number` | `list_pull_requests`, `head: "bikeindex:<branch>"`, `state: "open"` |
| `gh api user --jq .login` | `get_me` |
| `gh api …/issues/N/comments` | `issue_read`, `method: "get_comments"` |
| `gh pr comment` | `add_issue_comment` |
| `gh api -X PATCH …/comments/ID` | `update_issue_comment` |

`add_issue_comment` appends a Claude Code attribution footer the `pr` skill forbids —
the tell is the session id in its link. `update_issue_comment` doesn't, so read the
comment back and strip it.

## Verifying

Unlike `user-attachments` URLs these are plain public files, so `curl` settles it:

```bash
curl -sI "<url>" -o /dev/null -w '%{http_code} %{content_type}\n'   # want: 200 image/png
```

A `404` means the push didn't land, or the URL names a branch rather than the sha —
a branch ref stops resolving the moment the cleanup commit lands.
