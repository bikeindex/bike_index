---
name: github-upload-image-to-pr
description: >-
  Embed a local image file into an existing GitHub PR — either in the PR body or as a comment.
  Trigger when a request pairs a local image (screenshot, .png/.jpg, CleanShot capture, before/after)
  with an existing PR (by #number, URL, branch name, or "the open PR"), regardless of verb —
  attach, embed, add, put, post, drop, show, document. Also covers visually documenting test runs,
  bug repros, UI states, or CI failures on an existing PR. The `gh` CLI cannot upload images;
  this skill drives a real browser to GitHub's user-attachments uploader.
allowed-tools: Bash(agent-browser:*), Bash(gh:*), Bash(cp:*), ToolSearch, Read
---

# Upload Image to PR

Browser-driven workflow for embedding local images in a GitHub PR — the GitHub API does not support image uploads, so this drives a real browser to GitHub's user-attachments uploader instead.

Supported backends: Playwright MCP (preferred), Chrome DevTools MCP, agent-browser (CLI).

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

## Step 2: Pick a browser tool

### Priority Order

1. **Playwright MCP** (MCP connection, `mcp__playwright__*`) — preferred; cross-browser automation with stable APIs
2. **Chrome DevTools MCP** (MCP connection, `mcp__chrome-devtools__*`) — fallback MCP option if already installed
3. **agent-browser** (CLI via Bash — last-resort fallback, login state preserved with `--profile`)

MCP-based tools spawn or attach to a browser instance. By default they launch a fresh profile, so **you will need to sign into github.com the first time** in the spawned window (the session then persists across reuse). agent-browser can persist login state using `--profile ~/.agent-browser-github`.

### Detection

First, use `ToolSearch` with a query like `"browser navigate upload"` to find MCP-based browser tools. If none are registered, fall back to `agent-browser --version` via Bash to confirm the CLI is installed.

### If no browser tool is installed

Recommend the user install **Playwright MCP only** — it's sufficient for this skill and avoids prompting them to choose between backends:

```bash
claude mcp add playwright -- npx -y @playwright/mcp@latest
```

After install, the Claude Code session must be restarted for `mcp__playwright__*` tools to register. Do not suggest Chrome DevTools MCP or agent-browser unless the user explicitly asks for an alternative.

### Tool Compatibility Matrix

| Operation | Playwright MCP | Chrome DevTools MCP | agent-browser (CLI/Bash) |
|-----------|----------------|---------------------|--------------------------|
| **Navigate** | `browser_navigate` | `navigate_page` | `agent-browser --headed open {url}` |
| **Snapshot** | `browser_snapshot` | `take_snapshot` | `agent-browser snapshot` |
| **Screenshot** | `browser_take_screenshot` | `take_screenshot` | `agent-browser screenshot {path}` |
| **Click** | `browser_click` (ref) | `click` (uid) | `agent-browser click {ref}` |
| **File Upload** | `browser_file_upload` (paths) | `upload_file` (uid, filePath) | `agent-browser upload {ref} {path}` |
| **JS Eval** | `browser_evaluate` (function) | `evaluate_script` (function) | `agent-browser eval '{js}'` |
| **Login State** | Persists across calls; sign in once | Persists across calls; sign in once | Preserved with `--profile` |

## Step 3: Navigate to PR page and check login state

Navigate to the PR page and immediately take a snapshot to verify login state.

Playwright MCP (preferred):

```js
browser_navigate({ url: "https://github.com/{owner}/{repo}/pull/{number}" })
```

Chrome DevTools MCP (fallback):

```js
navigate_page({ url: "https://github.com/{owner}/{repo}/pull/{number}", type: "url" })
```

agent-browser — use `--profile` to persist login state:

```bash
agent-browser --headed --profile ~/.agent-browser-github open "https://github.com/{owner}/{repo}/pull/{number}"
```

**If SSO authentication screen appears:** Take a snapshot, locate the "Continue" button, and click it.

**If NOT logged in (agent-browser only):**
1. Navigate to `https://github.com/login`
2. Ask the user to log in manually in the headed browser window.
3. Wait for user confirmation, then navigate back to the PR page.

## Step 4: Locate the file upload input

Take a snapshot/screenshot and scroll to the bottom to find the comment area.

GitHub renders a file upload input in the comment form. Try these selectors in order (GitHub's UI can change — if one fails, try the next):

```javascript
// Shared JS for MCP-based tools — tries multiple known selectors
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

For Playwright MCP and Chrome DevTools MCP, you can also take a snapshot to find the `ref`/`uid` of the file upload element directly.

## Step 5: Upload images one by one

Upload each image file using the detected tool. Wait **2–3 seconds between uploads** so GitHub can process each file, then **3–5 seconds after the last upload** before reading URLs in step 6 — GitHub injects the markdown asynchronously after each file finishes processing.

For multiple images, upload them all to the same comment textarea before extracting URLs — this is more efficient than navigating between uploads.

- **Playwright MCP**: `browser_file_upload` takes the element ref and a file paths array.
- **Chrome DevTools MCP**: `upload_file` requires the `uid` of the input element.
- **agent-browser**: `agent-browser upload {ref} {absolute_path}`.

**Important:** Always use absolute file paths.

## Step 6: Retrieve uploaded image URLs

Read the textarea value — GitHub injects markdown image syntax like `![description](https://github.com/user-attachments/assets/...)` after each upload finishes processing.

The **standard textarea selector** (referenced again in step 7) prefers the known ID and falls back to a substring match in case GitHub renames it:

```javascript
// MCP-based tools
() => {
  const ta = document.getElementById('new_comment_field')
          || document.querySelector('textarea[id*="comment"]');
  return ta ? ta.value : 'textarea not found';
}
```

```bash
# agent-browser
agent-browser eval 'document.getElementById("new_comment_field")?.value || document.querySelector("textarea[id*=comment]")?.value || "not found"'
```

The response contains URLs in the format:
```
![image](https://github.com/user-attachments/assets/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
```

Extract all image URLs/markdown from the textarea value before clearing it.

## Step 7: Clear the textarea (do not submit the comment)

Use the **standard textarea selector** from step 6, then assign `ta.value = ""`:

```javascript
// MCP-based tools
() => {
  const ta = document.getElementById('new_comment_field')
           || document.querySelector('textarea[id*="comment"]');
  if (ta) { ta.value = ""; return "cleared"; }
  return "textarea not found";
}
```

```bash
# agent-browser
agent-browser eval 'const ta = document.getElementById("new_comment_field") || document.querySelector("textarea[id*=comment]"); if(ta){ta.value=""} "cleared"'
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
- **agent-browser login persistence**: Use `--profile ~/.agent-browser-github` to persist GitHub login across sessions

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Not logged in (MCP tools) | SSO screen may appear — take snapshot, find "Continue" button, click it |
| Not logged in (agent-browser) | Use `--headed` mode, navigate to login page, ask user to log in manually |
| Browser window not visible | For agent-browser, ensure `--headed` flag is used |
| File path with special characters (e.g., Unicode narrow spaces from CleanShot) | Copy file to `/tmp/` with a simple name: `cp /path/CleanShot*keyword*.png /tmp/screenshot.png` |
| File upload fails | Ensure the file path is absolute |
| Textarea doesn't contain URLs yet | Wait 3–5 seconds after upload before running JS eval; retry once if needed |
| Textarea selector not found | GitHub UI changes occasionally — use the multi-selector JS in Step 4 to find the current element |
| Chrome DevTools MCP disconnected | Reconnect via `/mcp` command |
| agent-browser not found | `npm install -g agent-browser && agent-browser install` |
| No browser tools found | Use `ToolSearch` to search for available browser tools |
| PR not found / 404 | Private repos return 404 for unauthenticated users — check login state |

## Notes

- GitHub `user-attachments/assets/` URLs are **persistent** — images remain accessible even without submitting the comment
- Editing the description directly in the browser UI is fragile due to GitHub UI structure changes — updating via `gh pr edit` is strongly preferred
- Multiple images can be uploaded in a single session before extracting URLs
- MCP-based tools connect to existing browser instances, preserving cookies and login sessions
