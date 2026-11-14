# Hosting images from the Claude Code web sandbox

SKILL.md's route can't run here: there's no `gh`, so nothing can `--attach`.

So this route commits the images to the PR's branch instead, and posts through the
GitHub MCP tools. It stands in for **all** of SKILL.md: step 1's PR lookup and step
3's posting are the MCP calls below, the upload is one script, step 4 is `curl`.
Unlike `--attach`, the script hands back URLs before anything is posted, so the body
is composed with them rather than with local paths.

Use it only when `$CLAUDE_CODE_REMOTE` is `true`. Elsewhere `--attach`'s
`user-attachments` URLs are permanent and leave no commits behind.

## Probe the posting before capturing

Posting is the last step and the only one a capture round can't recover from. In some
sessions (#4792) the comment tools rewrite every URL in a body: each wrapped in
backticks, `<img` escaped to `&lt;img`, plain and reference-style links alike, and
the footer appended. No retry or body form got past it, and nothing here deletes a
comment — so find out first, before any capture or hosting commit.

1. Create the `## Screenshots` comment — or update the existing one — with this body:

   ```
   ## Screenshots

   <img alt="probe" src="https://raw.githubusercontent.com/bikeindex/bike_index/main/app/assets/images/logos/bikebook_icon.png" width="40" />
   ```

2. Read it back with `get_comments`. It posted if the body still holds a literal
   `<img ` and no backtick sits beside the URL. It was rewritten if it holds `&lt;img`
   or a backtick before `https://`.
3. **Rewritten: stop.** Don't capture, host or retry — every retry stacks another
   rewrite. Update the comment to a body with no URLs: `## Screenshots` and a line
   saying the screenshots couldn't be posted from this session (that goes through;
   the footer still gets appended). Then tell the user the sandbox's comment tools
   rewrite URLs, so the screenshots have to be captured and attached by hand — and
   skip the rest of this file.
4. **Posted: carry on.** The probe is the comment you edit in place with the real body.

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

**Post the tags verbatim — never rewrap them as `![](url)`.** Widths belong to the caller —
the `pr` skill's table wants `width="500"` desktop, `"250"` mobile. Create the comment
with `add_issue_comment`, then `update_issue_comment` it with the same body, and read
it back: whether either tool leaves an `<img>` alone depends on the session, which is
what the probe below is for.

**Call it once, after every capture including the base branch's.** Each call costs
two commits and a push, and it refuses on a detached HEAD, so it can't run mid-checkout
anyway.

It also refuses outside the sandbox, on `main`, on a **tracked** path (the cleanup
commit would leave that deleted), and on a **dirty index** (staged changes ride into
the screenshot commit and survive the cleanup). `git rm --cached` keeps the files on
disk for a later recapture.

## What it costs

The images live only in that branch's history. This repo squash-merges, so they
never reach `main` and no clone pays for them — but a deleted branch leaves them
unreachable and eventually collectable. **Good for review, not an archive**: for
permanence use a release asset uploaded by a workflow — the GitHub MCP tools this
session goes through can't upload one.

## Posting, without `gh`

Same rules as SKILL.md step 3 — one `## Screenshots` comment per PR, edited in place.
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
the tell is the session id in its link — and can backtick the URL inside an `<img src>`
too (#4474), leaving an image with no `src`. `update_issue_comment` does neither, so
create the comment with `## Screenshots` alone and put the body in with an update, then
read it back.

## Verifying

Unlike `user-attachments` URLs these are plain public files, so `curl` settles it:

```bash
curl -sI "<url>" -o /dev/null -w '%{http_code} %{content_type}\n'   # want: 200 image/png
```

A `404` means the push didn't land, or the URL names a branch rather than the sha —
a branch ref stops resolving the moment the cleanup commit lands.
