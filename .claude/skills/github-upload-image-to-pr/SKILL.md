---
name: github-upload-image-to-pr
description: >-
  Embed a local image file into an existing GitHub PR — either in the PR body or as a comment.
  Trigger when a request pairs a local image (screenshot, .png/.jpg, CleanShot capture, before/after)
  with an existing PR (by #number, URL, branch name, or "the open PR"), regardless of verb —
  attach, embed, add, put, post, drop, show, document. Also covers visually documenting test runs,
  bug repros, UI states, or CI failures on an existing PR. The `gh` CLI cannot upload images;
  this skill drives a real browser to GitHub's user-attachments uploader.
allowed-tools: Bash(gh:*), Bash(cp:*), ToolSearch, Read
---

# Upload Image to PR

Browser-driven workflow for embedding local images in a GitHub PR — the GitHub API does not support image uploads, so this drives Playwright MCP to GitHub's user-attachments uploader instead.

## How It Works

Since the GitHub API does not support direct image uploads, this skill uses the **PR comment textarea as a staging area for GitHub's image hosting** — uploading files there to obtain persistent `user-attachments/assets/` URLs, then updating the PR description or posting a comment via the `gh` CLI.

## Step 1: Resolve PR context

If the user didn't specify a PR number or URL, auto-detect it:

```bash
# Get PR number from the current branch
gh pr view --json number,url -q '"\(.number) \(.url)"'
```

If multiple repos or branches are involved, confirm with the user which PR to target.

Also, normalize the image paths to absolute paths. If a path contains special characters (e.g., Unicode narrow spaces from CleanShot X), copy the file to `/tmp/` first:

```bash
# e.g., to handle glob-matched paths with special chars
cp /path/to/CleanShot*keyword*.png /tmp/screenshot.png
```

## Step 2: Verify Playwright MCP is available

Use `ToolSearch` with a query like `"browser navigate upload"` to confirm `mcp__playwright__*` tools are registered.

Playwright MCP attaches to or spawns a browser with a fresh profile, so **the user will need to sign into github.com the first time** in the spawned window. The session then persists across reuse.

### If Playwright MCP is not installed

Recommend the user install it:

```bash
claude mcp add playwright -- npx -y @playwright/mcp@latest
```

After install, the Claude Code session must be restarted for `mcp__playwright__*` tools to register.

## Step 3: Navigate to PR page and check login state

Navigate and immediately take a snapshot to verify login state:

```js
browser_navigate({ url: "https://github.com/{owner}/{repo}/pull/{number}" })
browser_snapshot()
```

**If an SSO authentication screen appears:** locate the "Continue" button in the snapshot and click it.

## Step 4: Locate the file upload input

Take a snapshot and scroll to the bottom to find the comment area. GitHub renders a file upload input in the comment form. Either find the `ref` directly from the snapshot, or run JS to detect it (GitHub's UI can change — try selectors in order):

```javascript
() => {
  const selectors = [
    'input[type="file"][id*="comment"]',
    'input[type="file"][id="fc-new_comment_field"]',
    '#new_comment_field',
    'input[type="file"]'
  ];
  for (const sel of selectors) {
    const el = document.querySelector(sel);
    if (el) return { found: true, id: el.id, selector: sel };
  }
  return { found: false };
}
```

## Step 5: Upload images one by one

Upload each image with `browser_file_upload` (takes the element ref and a file paths array). Wait **2–3 seconds between uploads** so GitHub can process each file, then **3–5 seconds after the last upload** before reading URLs in step 6 — GitHub injects the markdown asynchronously after each file finishes processing.

For multiple images, upload them all to the same comment textarea before extracting URLs — this is more efficient than navigating between uploads.

**Important:** Always use absolute file paths.

## Step 6: Retrieve uploaded image URLs

Read the textarea value via `browser_evaluate` — GitHub injects markdown image syntax like `![description](https://github.com/user-attachments/assets/...)` after each upload finishes processing.

The **standard textarea selector** (referenced again in step 7) prefers the known ID and falls back to a substring match in case GitHub renames it:

```javascript
() => {
  const ta = document.getElementById('new_comment_field')
          || document.querySelector('textarea[id*="comment"]');
  return ta ? ta.value : 'textarea not found';
}
```

The response contains URLs in the format:
```
![image](https://github.com/user-attachments/assets/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
```

Extract all image URLs/markdown from the textarea value before clearing it.

## Step 7: Clear the textarea (do not submit the comment)

Use the **standard textarea selector** from step 6, then assign `ta.value = ""`:

```javascript
() => {
  const ta = document.getElementById('new_comment_field')
           || document.querySelector('textarea[id*="comment"]');
  if (ta) { ta.value = ""; return "cleared"; }
  return "textarea not found";
}
```

## Step 8: Embed images in the PR

**Option A — Update PR description** (append images to existing body):
```bash
EXISTING_BODY=$(gh pr view {PR_NUMBER} --json body -q .body)

gh pr edit {PR_NUMBER} --body "$(printf '%s\n\n## Screenshots\n\n%s' "$EXISTING_BODY" "![screenshot](https://github.com/user-attachments/assets/...)")"
```

If `$EXISTING_BODY` already contains a `## Screenshots` heading (e.g., on re-runs), this will create a duplicate section. Check first with `grep -q "^## Screenshots" <<< "$EXISTING_BODY"` and either replace the existing section or post as a comment (Option B) instead.

**Option B — Post as a new comment**:
```bash
gh pr comment {PR_NUMBER} --body "## Screenshots

![screenshot](https://github.com/user-attachments/assets/...)"
```

Use Option A by default unless the user explicitly asks for a comment, or if the PR description is already long and a comment would be cleaner.

## Step 9: Verify the result

Reload the page and take a screenshot to confirm the images are displayed correctly.

## Tips

- **Image sizing**: Control display size via HTML `<img>` tags: `<img width="800" alt="description" src="..." />`
- **Multiple images**: Upload all images in one session to the same textarea; extract all URLs before clearing

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Not logged in | SSO screen may appear — take snapshot, find "Continue" button, click it |
| File path with special characters (e.g., Unicode narrow spaces from CleanShot) | Copy file to `/tmp/` with a simple name: `cp /path/CleanShot*keyword*.png /tmp/screenshot.png` |
| File upload fails | Ensure the file path is absolute |
| Textarea doesn't contain URLs yet | Wait 3–5 seconds after upload before running JS eval; retry once if needed |
| Textarea selector not found | GitHub UI changes occasionally — use the multi-selector JS in Step 4 to find the current element |
| Playwright MCP not registered | `claude mcp add playwright -- npx -y @playwright/mcp@latest`, then restart the Claude Code session |
| PR not found / 404 | Private repos return 404 for unauthenticated users — check login state |

## Notes

- GitHub `user-attachments/assets/` URLs are **persistent** — images remain accessible even without submitting the comment
- Editing the description directly in the browser UI is fragile due to GitHub UI structure changes — updating via `gh pr edit` is strongly preferred
- Multiple images can be uploaded in a single session before extracting URLs
- Playwright MCP attaches to a browser instance and preserves cookies/login state across calls
