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
allowed-tools: Bash(gh:*), Bash(rtk proxy gh:*), Bash(ruby .claude/skills/github-pr-images/assets/inline_attachments.rb:*), Bash(brew upgrade gh), Bash(cp:*), Bash(bash .claude/skills/github-pr-images/assets/commit_images.sh:*), Bash(curl -sI https://raw.githubusercontent.com/:*), Read, Write, mcp__github__list_pull_requests, mcp__github__get_me, mcp__github__issue_read, mcp__github__add_issue_comment, mcp__github__update_issue_comment
---

# Upload Image to PR

`gh pr comment`, `gh pr edit` and `gh pr create` take `--attach '<file>#<alt text>'`, up to 50 per command. A markdown `![alt](tmp/x.png)` reference to an attached path is rewritten in place to the uploaded `user-attachments/assets/` URL. **An `<img src="tmp/x.png">` isn't** — it keeps its path, and the upload is appended to the end as `![<basename>](url)`, as is any attached file the body doesn't reference.

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

Reference each image by its path from the repo root, the same in the body as in `--attach`. A path with special characters (Unicode narrow spaces from CleanShot X) goes through the project's `tmp/` first:

```bash
cp /path/to/CleanShot*keyword*.png tmp/screenshot.png
```

## Step 2: The body

A caller's body is posted verbatim — don't recompose it. Composing it yourself:

```
## Screenshots

<img src="tmp/screenshot.png" width="500">
```

Images in table cells want `<img … width=…>`; elsewhere `![alt](path)` is fine. Don't give an `<img>`'s file a `#alt` on `--attach` — step 3's script finds its upload by the basename gh uses as the default alt.

## Step 3: Post it

This skill owns the `## Screenshots` comment: one per PR, body starting `## Screenshots` even when what's under it isn't screenshots — retitle it and the next run can't find it.

```bash
gh api --paginate "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" \
  --jq ".[] | {id, login: .user.login, body: .body[:14]}"
```

The comment whose body starts `## Screenshots` is `$SCREENSHOT_COMMENT_ID`, **whoever posted it** — the web sandbox posts as a different account than local `gh`, so filtering on your own login misses a PR's sandbox-posted comment and adds a second. One by another login is never your last comment: update it through the stand-in below. `--paginate` matters — on a busy PR it often isn't on the first page.

A caller updating one page of a multi-page comment needs the current body to edit — hand it back on request: `gh api repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID --jq .body`.

Write the body to a file. **With images to upload**, attach one `--attach` per image the body references, and **update `$SCREENSHOT_COMMENT_ID` in place rather than replacing it** — a re-capture never posts a second comment. Which command depends on whether it's your last comment on the PR:

```bash
ME=$(gh api user --jq .login)
gh api --paginate "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" --jq ".[] | select(.user.login == \"$ME\") | .id" | tail -1
```

- **No `$SCREENSHOT_COMMENT_ID` yet** — post it: `rtk proxy gh pr comment $PR_NUMBER --body-file <file> --attach tmp/a.png --attach tmp/b.png`.
- **It's your last comment** — `--edit-last` takes `--attach`, so the same command with `--edit-last` edits it in place and keeps its id.
- **You've commented since** — `--edit-last` would hit that later one. Upload through a stand-in: post the body as a new comment with its `--attach`es, run the script below on it, write its body to a file (`gh api …/issues/comments/<stand-in-id> --jq .body`), PATCH that into `$SCREENSHOT_COMMENT_ID` as under **With nothing to upload**, then `gh api -X DELETE` the stand-in.

Then, on the comment the uploads landed on:

```bash
ruby .claude/skills/github-pr-images/assets/inline_attachments.rb {owner}/{repo} <comment-id>
```

`rtk proxy` because the hook reduces the output to "ok commented", and the comment URL it prints carries the id. The script moves each appended upload into its `<img src>` and PATCHes the comment; it stops without patching if a local `src` has no upload to take. An image already uploaded stays in the body as its asset URL — attach only what was recaptured.

**With nothing to upload**, edit in place: `gh api -X PATCH repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID -F body=@<absolute-path> --jq .html_url`. `-F` reads a file from `@`; `-f` would post the literal `@<file>`. The path is absolute because `gh` resolves `@` against the shell's cwd.

Only edit the PR description when the user explicitly asks: `gh pr edit $PR_NUMBER --body-file <file> --attach …`, referencing images as `![alt](path)` — the script patches comments only — with the existing body plus a `## Screenshots` section — replace that section if it's already there rather than adding a second. The `pr-guardrails` hook denies `gh pr edit` until the `pr` skill is loaded.

## Step 4: Verify

Read the posted body back:

```bash
gh api repos/{owner}/{repo}/issues/comments/<id> --jq .body
```

Pass: no `tmp/` path left, an `https://github.com/user-attachments/assets/` URL in place of each attached file, and still one `## Screenshots` comment on the PR — rerun Step 3's listing. Don't `curl` those URLs — they 302 to a session-signed S3 URL that 403s unauthenticated.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `unknown flag: --attach` | `brew upgrade gh` |
| `no upload matched: <path>` | The `<img>`'s file wasn't attached, or its `--attach` gave a `#alt` — the script matches on the default alt, the basename |
| File path with special characters (e.g., Unicode narrow spaces from CleanShot) | `cp /path/CleanShot*keyword*.png tmp/screenshot.png` |
| Upload refused | `--attach` needs push access to the repo, and takes images and video only |
