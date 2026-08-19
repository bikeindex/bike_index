---
name: github-pr-images
description: >-
  Embed a local image file into an existing GitHub PR — either in the PR body or as a comment.
  Trigger when a request pairs a local image (screenshot, .png/.jpg, CleanShot capture, before/after)
  with an existing PR (by #number, URL, branch name, or "the open PR"), regardless of verb —
  attach, embed, add, put, post, drop, show, document. Also covers visually documenting test runs,
  bug repros, UI states, or CI failures on an existing PR. The `gh` CLI cannot upload images;
  this skill drives a real browser to GitHub's user-attachments uploader. It also owns the PR's
  one `## Screenshots` comment — finding, creating, editing and verifying it — so other workflows
  (the `pr` skill's screenshot phase) call it to host images and get URLs back, then hand it a
  composed body to post.
allowed-tools: Bash(gh:*), Bash(cp:*), ToolSearch, Read, Write, mcp__playwright__browser_navigate, mcp__playwright__browser_snapshot, mcp__playwright__browser_find, mcp__playwright__browser_click, mcp__playwright__browser_evaluate, mcp__playwright__browser_file_upload, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_close
---

# Upload Image to PR

Browser-driven workflow for embedding local images in a GitHub PR — the GitHub API does not support image uploads, so this drives Playwright MCP to GitHub's user-attachments uploader instead.

## How It Works

Since the GitHub API does not support direct image uploads, this skill uses the **PR comment textarea as a staging area for GitHub's image hosting** — uploading files there to obtain persistent `user-attachments/assets/` URLs, then updating the PR description or posting a comment via the `gh` CLI.

## Preflight: this needs `gh` and a signed-in browser

Both, or nothing works — the upload is a real browser session against github.com, and the posting is `gh`. **Stop before uploading anything if either is missing**, say which one, and return without posting. Don't half-run it: images hosted with nowhere to go are wasted, and a comment posted through some other route is one the next run can't find.

The Claude Code web sandbox has neither: no GitHub CLI, and a browser that rejects the egress proxy's CA, so github.com fails to load with `ERR_CERT_AUTHORITY_INVALID`. Callers should have skipped before reaching you — the `pr` skill's screenshot phase gates on exactly this — but check anyway, since a direct request won't have.

## Step 1: Resolve PR context

If the user didn't specify a PR number or URL, auto-detect it:

```bash
# Get PR number from the current branch
gh pr view --json number,url -q '"\(.number) \(.url)"'
```

If multiple repos or branches are involved, confirm with the user which PR to target.

Also, normalize the image paths to absolute paths. If a path contains special characters (e.g., Unicode narrow spaces from CleanShot X), copy the file into the project's `tmp/` first — not the system `/tmp`, which is where scratch files go to be lost:

```bash
# e.g., to handle glob-matched paths with special chars
cp /path/to/CleanShot*keyword*.png tmp/screenshot.png
```

## Step 2: Verify Playwright MCP is available

Use `ToolSearch` with a query like `"browser navigate upload"` to confirm `mcp__playwright__*` tools are registered.

Playwright MCP runs isolated (`--isolated --storage-state=…/mcp-auth.json`), loading github.com cookies from that shared storage-state file at startup — so the session persists across sessions once the file is populated. It's load-only: the MCP never writes it back, so login can't be refreshed through the MCP browser. If GitHub logs the user out and you hit a 404 / login screen mid-task, see [references/headless-relogin.md](references/headless-relogin.md) — full login can't be driven headlessly.

### If Playwright MCP is not registered

The project ships a `.mcp.json` registering Playwright MCP (isolated, shared storage-state file, headless). Claude Code prompts to approve project MCP servers on first entry — if the `mcp__playwright__*` tools aren't registered, approve the `playwright` server there and restart the session (or `/mcp` → **playwright** → **reconnect**). On first use `mcp-auth.json` won't exist yet — populate it via the login helper in the re-login guide.

## Step 3: Navigate to PR page and check login state

`browser_resize` to 1440×900 first. `frontend-screenshots` hands the browser over at whatever viewport its last shot needed — often a few dozen pixels tall, to fit a short component preview — and in that window GitHub's sticky header covers the comment form, so step 5's click times out on "intercepts pointer events".

Then navigate and immediately take a snapshot to verify login state:

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

## Step 5: Upload every image in one call

The `<input type="file">` from step 4 is **CSS-hidden** — calling `browser_file_upload` against its ref directly fails with "can only be used when there is related modal state present." First click the visible attach button on the comment form to open the native file chooser, then `browser_file_upload` will satisfy that chooser. The button's accessible name is **"Add files"**; its full text ("Paste, drop, or click to add files") is in the DOM but isn't what the snapshot matches on, so search for `Add files`.

**Upload every image in one `browser_file_upload` call** — it takes an array of paths, and GitHub processes them together. Don't upload one at a time. Always absolute paths.

Then poll the textarea until it holds one `user-attachments/assets/` URL per file, rather than sleeping a fixed interval — GitHub injects each image's markup asynchronously as it finishes:

```javascript
async () => {
  const ta = () => document.getElementById('new_comment_field')
              || document.querySelector('textarea[id*="comment"]');
  for (let i = 0; i < 25; i++) {
    const value = ta()?.value ?? '';
    if ((value.match(/user-attachments\/assets\//g) || []).length >= EXPECTED) return value;
    await new Promise(r => setTimeout(r, 1000));
  }
  return ta()?.value ?? 'textarea not found';
}
```

GitHub sets each image's `alt` to its **filename**, so a batch comes back self-labelling — that's how you map URLs to pages and viewports without uploading singly.

## Step 6: Retrieve uploaded image URLs

Step 5's poll already returns the textarea value; this is what's in it. The **standard textarea selector** it uses (referenced again in step 7) prefers the known ID and falls back to a substring match in case GitHub renames it:

```javascript
document.getElementById('new_comment_field') || document.querySelector('textarea[id*="comment"]')
```

GitHub may inject **either form** depending on image dimensions / file type:
```
![image](https://github.com/user-attachments/assets/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
<img width="..." height="..." alt="..." src="https://github.com/user-attachments/assets/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx" />
```

Both render the image in the PR — preserve whichever form GitHub used. If you need to extract just the URL (e.g., to rewrap), match the asset path with a regex that ignores wrapper syntax: `https://github\.com/user-attachments/assets/[0-9a-f-]+`.

## Step 7: Clear the textarea (do not submit the comment)

Submitting via the UI's "Comment" button would post a public comment as a side effect of the upload. The only thing that should determine where the image lands — a comment, the PR body, or nowhere yet — is step 8, so the textarea here is purely an upload-staging surface, never a submission surface. Clear it, then let `gh` decide the destination.

Use the **standard textarea selector** from step 6, then assign `ta.value = ""`:

```javascript
() => {
  const ta = document.getElementById('new_comment_field')
           || document.querySelector('textarea[id*="comment"]');
  if (ta) { ta.value = ""; return "cleared"; }
  return "textarea not found";
}
```

## Step 8: Put them on the PR

**Two ways this skill gets called, decided by whether you were handed a body:**

- **Host only** — no body. Stop here: return the URLs from step 6, keyed however the caller asked, and **leave the browser open** — only a workflow mid-sequence calls this way, and it has more to do. The `pr` skill's screenshot phase calls this twice (branch, then base) before it has anything worth posting. Posting here would land a partial comment.
- **Host and post** — the caller handed you a composed body, or the request was a direct "put this image on the PR" with no other workflow involved. Post it as below.

This skill owns the `## Screenshots` comment: finding it, creating it, editing it, checking it rendered. Callers compose bodies; they don't post them.

Substitute whichever form (markdown `![](...)` or HTML `<img ...>`) GitHub returned in step 6 — preserve it verbatim instead of rewrapping. A body handed to you by a caller is posted verbatim too; don't recompose it.

**Post as a comment** (the default). A comment keeps the description tight and skimmable, and avoids re-editing the body (and its notification noise) on every recapture.

If a screenshots comment already exists (one authored by you whose body starts with `## Screenshots`), edit it in place instead of posting a new one. Keep the heading as the handle: one such comment per PR, always starting `## Screenshots`, even when what's under it isn't screenshots — retitle it and the next run can't find it.
```bash
ME=$(gh api user --jq .login)
SCREENSHOT_COMMENT_ID=$(gh api --paginate "repos/{owner}/{repo}/issues/$PR_NUMBER/comments" \
  --jq ".[] | select(.user.login == \"$ME\") | select(.body | startswith(\"## Screenshots\")) | .id" | head -1)
```

`--paginate` matters — comments come 30 to a page, and on a busy PR the screenshots comment often isn't on the first. The author filter keeps someone else's `## Screenshots` comment from being overwritten.

A caller updating one page of a multi-page comment needs the current body to edit — hand it back on request: `gh api repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID --jq .body`.

Write the comment body to a temp file — the caller's, or, when you're composing it yourself:
```
## Screenshots

<image markup from step 6>
```

- If `$SCREENSHOT_COMMENT_ID` is empty: `gh pr comment $PR_NUMBER --body-file <tmp-comment-file>`.
- Otherwise: `gh api -X PATCH repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID -F body=@<tmp-comment-file> --jq .html_url`. `-F` is what reads a file when the value starts with `@`; `-f` is a raw string field and would clobber the comment with the literal `@<file>`. Re-verify after: `gh api repos/{owner}/{repo}/issues/comments/$SCREENSHOT_COMMENT_ID --jq .body | head`.

Only edit the PR description instead when the user explicitly asks for it:
```bash
EXISTING_BODY=$(gh pr view $PR_NUMBER --json body -q .body)

gh pr edit $PR_NUMBER --body "$(printf '%s\n\n## Screenshots\n\n%s' "$EXISTING_BODY" "<image markup from step 6>")"
```

If `$EXISTING_BODY` already contains a `## Screenshots` heading (e.g., on re-runs), this will create a duplicate section. Check first with `grep -q "^## Screenshots" <<< "$EXISTING_BODY"` and either replace the existing section or post as a comment instead.

## Step 9: Verify the result

Reload the page in the Playwright browser and confirm the images render. **Do not** verify with `curl` — `user-attachments/assets/` URLs return HTTP 302 to a session-signed S3 URL that 403s for unauthenticated clients. The 302 alone confirms the asset exists; only the browser can say it displayed.

**The rendered `src` is not the URL you posted.** GitHub rewrites `github.com/user-attachments/assets/…` to `private-user-images.githubusercontent.com`, so a DOM query for the posted URL finds nothing on a comment that is rendering perfectly. Check the images under the heading instead:

```javascript
() => {
  const heading = [...document.querySelectorAll('h2')].find(h => h.textContent.trim() === 'Screenshots');
  return [...heading.closest('td, div').querySelectorAll('img')]
    .map(i => ({w: i.naturalWidth, h: i.naturalHeight, complete: i.complete}));
}
```

A non-zero `naturalWidth` on every image is the pass.

Then `browser_close`. **Posting is always terminal** — nothing follows it, in this skill or in any caller — so a post always closes, and a host-only call (step 8) always leaves the browser for whoever called it. That pair needs no signal from the caller and leaves no session running: the profile lock would otherwise stay held and the next `browser_navigate` anywhere fails with "Browser is already in use". `frontend-screenshots` hands you an open browser for the same reason rather than paying the startup twice.

## Tips

- **Image sizing**: Control display size via HTML `<img>` tags: `<img width="800" alt="description" src="..." />`
- **Multiple images**: one `browser_file_upload` call with every path; extract all URLs before clearing

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Not logged in | SSO screen may appear — take snapshot, find "Continue" button, click it. Full GitHub login can't be done headless — see [references/headless-relogin.md](references/headless-relogin.md) |
| File path with special characters (e.g., Unicode narrow spaces from CleanShot) | Copy file into the project's `tmp/` with a simple name: `cp /path/CleanShot*keyword*.png tmp/screenshot.png` |
| File upload fails | Ensure the file path is absolute |
| Textarea doesn't contain URLs yet | Poll it (step 5) until the count matches the files uploaded, rather than waiting a fixed interval |
| Attach button not in the snapshot | Its accessible name is "Add files" — searching for "Paste, drop, or click to add files" won't match |
| Textarea selector not found | GitHub UI changes occasionally — use the multi-selector JS in Step 4 to find the current element |
| Playwright MCP not registered | Approve the `playwright` server from the project `.mcp.json` (Claude Code prompts on project entry), then restart the session or `/mcp` → reconnect |
| PR not found / 404 | Private repos return 404 for unauthenticated users — check login state |

## Notes

- GitHub `user-attachments/assets/` URLs are **persistent** — images remain accessible even without submitting the comment
- Editing the description directly in the browser UI is fragile due to GitHub UI structure changes — updating via `gh pr edit` is strongly preferred
- Every image goes up in a single `browser_file_upload` call; extract all the URLs before clearing
- Playwright MCP preserves cookies/login state across calls within a session; across sessions the login comes from the shared `--storage-state` file (`mcp-auth.json`), loaded at startup
