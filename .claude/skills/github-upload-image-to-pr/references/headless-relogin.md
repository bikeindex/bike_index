# Logging into GitHub for the isolated, headless MCP

The Playwright MCP here runs **isolated** against a shared storage-state file:

```
--isolated --storage-state=$HOME/.cache/ms-playwright/mcp-auth.json --headless
```

`--isolated` keeps the browser profile in memory (nothing on disk); `--storage-state` **loads** github.com cookies from `mcp-auth.json` into every new browser context at startup. That single file is the shared auth store — every Claude Code session's MCP reads the same cookies from it, which is why login "sticks" across sessions with no visible window.

**It is load-only.** The MCP never writes `mcp-auth.json` back. Signing in *inside* the MCP browser doesn't persist: an isolated context is discarded on `browser_close` and the fresh cookie goes with it. (This is the difference from the old `--user-data-dir` persistent profile, which saved login to disk automatically.) So when GitHub logs you out, refresh the file out-of-band, then let the MCP re-read it.

## When this triggers

You hit a GitHub 404 / login screen mid-task (a private-repo page 404s when logged out). **Stop** — don't try to drive GitHub's login form through the MCP: it can't persist the result, and 2FA / passkeys can't be typed into a headless window.

## Refresh the shared auth file

1. Confirm the storage-state path from the live config — don't assume it, read whatever `--storage-state` points at:
   ```bash
   claude mcp get playwright   # read the --storage-state=<path> in the Args line
   ```
2. **Ask the user** to run a one-off headed login that loads the current cookies and saves them back after they sign in. They type their own credentials / 2FA / passkey — **never do it for them**:
   ```bash
   AUTH="$HOME/.cache/ms-playwright/mcp-auth.json"   # the --storage-state path from step 1
   npx -y playwright open --load-storage="$AUTH" --save-storage="$AUTH" https://github.com/login
   ```
   A visible browser opens (carrying any still-valid cookies from the file). They finish signing in, then **close the window** — Playwright writes the refreshed cookies to `mcp-auth.json` on close. This is a user-run login helper, not a screenshot path; screenshots still go only through the MCP, never the Playwright CLI.
3. Back in the MCP, pick up the new file — usually no config change and no reconnect:
   ```
   browser_close                    # drop the logged-out context
   browser_navigate https://github.com
   browser_snapshot                 # confirm the account handle shows in the sidebar
   ```
   The next isolated context re-reads `mcp-auth.json` (the path is resolved lazily per context, not cached at launch). If the snapshot still shows logged-out, reconnect once — `/mcp` → **playwright** → **reconnect** — and re-check.

## Notes

- **No profile lock anymore.** `--isolated` keeps nothing on disk, so concurrent sessions don't fight over a shared profile — you'll never see the old `Browser is already in use ... use --isolated` error, and there's no orphaned-Chrome process to hunt down or kill.
- `npx playwright open` uses Playwright's bundled Chromium. If it reports the browser is missing, run `npx playwright install chromium` once.
- The config lives in `~/.claude.json` (often a symlink into a dotfile manager like Mackup). Prefer `claude mcp get/remove/add` over hand-editing it; if you must edit the JSON, edit the real symlink target, not the link.
