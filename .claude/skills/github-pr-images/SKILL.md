---
name: github-pr-images
description: >-
  Embed a local image file into an existing GitHub PR — either in the PR body or as a comment.
  Trigger when a request pairs a local image (screenshot, .png/.jpg, CleanShot capture, before/after)
  with an existing PR (by #number, URL, branch name, or "the open PR"), regardless of verb —
  attach, embed, add, put, post, drop, show, document. Also covers visually documenting test runs,
  bug repros, UI states, or CI failures on an existing PR. Uploads with `gh api` to GitHub's
  `user-attachments` endpoint. It also owns the PR's one `## Screenshots` comment — finding,
  creating, editing and verifying it — so other workflows (the `pr` skill's screenshot phase)
  hand it a composed body that references local image paths, and it posts it.
allowed-tools: Bash(gh:*), Bash(ruby .claude/skills/github-pr-images/assets/upload_attachments.rb:*), Bash(cp:*), Bash(bash .claude/skills/github-pr-images/assets/commit_images.sh:*), Bash(curl -sI https://raw.githubusercontent.com/:*), Read, Write, mcp__github__list_pull_requests, mcp__github__issue_read, mcp__github__add_issue_comment, mcp__github__update_issue_comment
---

# Upload Image to PR

`assets/upload_attachments.rb <body-file>` uploads every local path in an `<img src="…">` or `![alt](…)` to GitHub's REST upload endpoint (`POST https://uploads.github.com/user-attachments/assets`, the one `gh … --attach` uses) and swaps each for its permanent `https://github.com/user-attachments/assets/…` URL in the file. Nothing is posted, so the post is a plain `gh api` POST or PATCH.

## Who runs this

From a session with history, hand this skill to a subagent the way `AGENTS.md`'s **Who runs this** describes — `model: "haiku"` (the commands are all here) — briefed with the PR number and either a composed body file referencing local image paths or the images plus where they go. It replies with the comment (or PR) URL and Step 4's verification result.

## Preflight: can this session upload?

Callers run this before capturing anything. Anywhere but the web sandbox, `gh` is the answer: no `gh` → stop and say so, posting nothing.

**In the web sandbox** (`$CLAUDE_CODE_REMOTE` is `true`) `gh` refuses GraphQL (`HTTP 403: GitHub GraphQL is not available from Claude Code sessions`), but the upload and every post here are REST. Run the script on a body file holding one existing image, `![probe](app/assets/images/logos/bikebook.png)`:

- **It rewrites the path to a `user-attachments` URL**: follow this file as written, except step 1, which is `list_pull_requests` with `head: "bikeindex:<branch>"`, `state: "open"` — `gh pr view` is GraphQL.
- **No `gh`, or the upload is refused**: follow [references/web-sandbox.md](references/web-sandbox.md) for the **whole flow**, starting with its probe.

## Step 1: Resolve PR context

If the user didn't specify a PR number or URL, auto-detect it:

```bash
gh pr view --json number,url -q '"\(.number) \(.url)"'
```

Reference each image by its path from the repo root. A path with special characters (Unicode narrow spaces from CleanShot X) goes through the project's `tmp/` first:

```bash
cp /path/to/CleanShot*keyword*.png tmp/screenshot.png
```

## Step 2: The body

A caller's body is posted verbatim — don't recompose it. Composing it yourself:

```
## Screenshots

<img src="tmp/screenshot.png" width="500">
```

When a `## Screenshots` comment already exists (step 3 finds it), compose from its current body: a recapture **replaces** the image it supersedes in place — never a new "Updated"/"After merging main" section appended below the old shots. A state the comment doesn't show yet gets its own block, in the shape of the ones there.

Images in table cells want `<img … width=…>`; elsewhere `![alt](path)` is fine.

## Step 3: Post it

This skill owns the `## Screenshots` comment: one per PR, body starting `## Screenshots` even when what's under it isn't screenshots — retitle it and the next run can't find it.

```bash
gh api --paginate "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" \
  --jq ".[] | {id, login: .user.login, body: .body[:14]}"
```

The comment whose body starts `## Screenshots` is `$SCREENSHOT_COMMENT_ID`, **whoever posted it** — the web sandbox posts as a different account than local `gh`, so filtering on your own login misses a PR's sandbox-posted comment and adds a second. `--paginate` matters — on a busy PR it often isn't on the first page.

A caller updating one page of a multi-page comment needs the current body to edit — hand it back on request: `gh api repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID --jq .body`.

Write the body to a file and upload what it references, from the repo root:

```bash
ruby .claude/skills/github-pr-images/assets/upload_attachments.rb <file>
```

Only local paths upload, so an image already in the body as its asset URL stays put and only what was recaptured goes up. Then post the file with `-F` and an absolute path — `-F` reads `@`, `-f` would post the literal `@<file>`, and `gh` resolves `@` against the shell's cwd:

- **No `$SCREENSHOT_COMMENT_ID` yet**: `gh api repos/{owner}/{repo}/issues/$PR_NUMBER/comments -F body=@<absolute-path> --jq .html_url`
- **Otherwise edit it in place** — a re-capture never posts a second comment: `gh api -X PATCH repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID -F body=@<absolute-path> --jq .html_url`

Only edit the PR description when the user explicitly asks: run the script on a file holding the existing body plus a `## Screenshots` section — replace that section if it's already there rather than adding a second — then `gh pr edit $PR_NUMBER --body-file <file>`. The `pr-guardrails` hook denies `gh pr edit` until the `pr` skill is loaded.

## Step 4: Verify

Read the posted body back:

```bash
gh api repos/{owner}/{repo}/issues/comments/<id> --jq .body
```

Pass: no `tmp/` path left, an `https://github.com/user-attachments/assets/` URL in place of each local file, and still one `## Screenshots` comment on the PR — rerun Step 3's listing. Don't `curl` those URLs — they 302 to a session-signed S3 URL that 403s unauthenticated.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Upload 404s | The token can't write to the repo — the endpoint answers 404 rather than 403 |
| `unsupported type` | Images and video only — add the extension to the script's `CONTENT_TYPES` if GitHub takes it |
| File path with special characters (e.g., Unicode narrow spaces from CleanShot) | `cp /path/CleanShot*keyword*.png tmp/screenshot.png` |
