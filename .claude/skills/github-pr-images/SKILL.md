---
name: github-pr-images
description: >-
  Embed a local image file into an existing GitHub PR — either in the PR body or as a comment.
  Trigger when a request pairs a local image (screenshot, .png/.jpg, CleanShot capture, before/after)
  with an existing PR (by #number, URL, branch name, or "the open PR"), regardless of verb —
  attach, embed, add, put, post, drop, show, document. Also covers visually documenting test runs,
  bug repros, UI states, or CI failures on an existing PR. Uploads through `gh`'s `--attach` flag —
  except in the Claude Code web sandbox, which has no `gh` and hosts images through the PR branch's
  history instead. It also owns the PR's one `## Screenshots` comment — finding, creating, editing
  and verifying it — so other workflows (the `pr` skill's screenshot phase) hand it a composed body
  that references local image paths, and it posts it.
allowed-tools: Bash(gh:*), Bash(brew upgrade gh), Bash(cp:*), Bash(bash .claude/skills/github-pr-images/assets/commit_images.sh:*), Bash(curl -sI https://raw.githubusercontent.com/:*), Read, Write, mcp__github__list_pull_requests, mcp__github__get_me, mcp__github__issue_read, mcp__github__add_issue_comment, mcp__github__update_issue_comment
---

# Upload Image to PR

`gh pr comment`, `gh pr edit` and `gh pr create` take `--attach '<file>#<alt text>'`, up to 50 per command. A body reference to an attached path — `![alt](tmp/x.png)` or `<img src="tmp/x.png">` — is rewritten in place to the uploaded `user-attachments/assets/` URL. An attached file the body doesn't reference is appended to the end.

**There's no upload-only call**: assets upload as part of posting, so callers hand over a body that references local paths, never URLs they need back first.

## Preflight: which route this run takes

`$CLAUDE_CODE_REMOTE` decides which, before anything else here.

**`true`** — the web sandbox, which has no `gh` and follows [references/web-sandbox.md](references/web-sandbox.md) for the **whole flow**.

**Unset** — make sure `gh` has `--attach`:

```bash
gh help pr comment | grep -q -- --attach || brew upgrade gh
```

`gh help pr comment`, not `gh pr comment --help` — the rtk hook swallows the latter's output. Still missing after the upgrade, or no `gh` at all → stop and say so, posting nothing.

## Step 1: Resolve PR context

If the user didn't specify a PR number or URL, auto-detect it:

```bash
gh pr view --json number,url -q '"\(.number) \(.url)"'
```

Reference each image by a path **relative to the repo root, spelled identically in the body and in `--attach`** — that's the match the rewrite keys on. A path with special characters (Unicode narrow spaces from CleanShot X) goes through the project's `tmp/` first:

```bash
cp /path/to/CleanShot*keyword*.png tmp/screenshot.png
```

## Step 2: The body

A caller's body is posted verbatim — don't recompose it. Composing it yourself:

```
## Screenshots

<img src="tmp/screenshot.png" width="500">
```

Images in table cells want `<img … width=…>`; elsewhere `![alt](path)` is fine. Alt text is the filename unless `--attach` gives `#alt` or the body reference has its own.

## Step 3: Post it

This skill owns the `## Screenshots` comment: one per PR, authored by you, body starting `## Screenshots` even when what's under it isn't screenshots — retitle it and the next run can't find it.

```bash
ME=$(gh api user --jq .login)
gh api --paginate "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" \
  --jq ".[] | select(.user.login == \"$ME\") | {id, body: .body[:14]}"
```

The comment whose body starts `## Screenshots` is `$SCREENSHOT_COMMENT_ID`; whether it's the **last** of yours decides the route below. `--paginate` matters — on a busy PR it often isn't on the first page.

A caller updating one page of a multi-page comment needs the current body to edit — hand it back on request: `gh api repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID --jq .body`.

Write the body to a file, then, with one `--attach` per image the body references:

| State | Command |
| --- | --- |
| No screenshots comment | `gh pr comment $PR_NUMBER --body-file <file> --attach tmp/a.png --attach tmp/b.png` |
| It's your last comment | same, plus `--edit-last` |
| It isn't, and the body has images to upload | post a new one as in the first row, **then** `gh api -X DELETE repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID` |
| Body has nothing to upload | `gh api -X PATCH repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID -F body=@<absolute-path> --jq .html_url` |

`--edit-last` is the only edit that attaches, so an older comment is replaced rather than edited. Post before deleting, so a failed upload never loses the existing screenshots.

For the PATCH: `-F` reads a file from `@`; `-f` would post the literal `@<file>`. The path is absolute because `gh` resolves `@` against the shell's cwd.

Only edit the PR description when the user explicitly asks: `gh pr edit $PR_NUMBER --body-file <file> --attach …`, with the existing body plus a `## Screenshots` section — replace that section if it's already there rather than adding a second. The `pr-guardrails` hook denies `gh pr edit` until the `pr` skill is loaded.

## Step 4: Verify

Read the posted body back:

```bash
gh api repos/{owner}/{repo}/issues/comments/<id> --jq .body
```

Pass: no `tmp/` path left, and one `https://github.com/user-attachments/assets/` URL per attached file. Don't `curl` those URLs — they 302 to a session-signed S3 URL that 403s unauthenticated.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `unknown flag: --attach` | `brew upgrade gh` |
| Path left in the body, image appended at the end instead | The body's path and the `--attach` path differ — spell them identically |
| File path with special characters (e.g., Unicode narrow spaces from CleanShot) | `cp /path/CleanShot*keyword*.png tmp/screenshot.png` |
| Upload refused | `--attach` needs push access to the repo, and takes images and video only |
