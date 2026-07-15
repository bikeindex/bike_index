# Logging into GitHub when the MCP runs headless

The Playwright MCP is registered in the project's **`.mcp.json`** (inspect with `claude mcp get playwright`) with `--isolated --headless`, seeding each browser session's auth from a storage-state file: `--storage-state=${HOME}/.cache/ms-playwright/mcp-auth.json`. Two consequences:

- The github.com session lives in that file, not in a browser profile. Every new browser session re-reads it at context creation.
- The file is read-only from the MCP's perspective: `--isolated` keeps the profile in memory and never writes back to disk. A login performed inside the MCP browser is lost when the browser closes — so re-login means **regenerating the state file**, not driving the MCP browser through the login form. (This holds even if the MCP happens to be running headed: an in-browser login lasts only until that browser session ends.)

Confirm the exact `--storage-state` path from `claude mcp get playwright` rather than assuming it — the commands below use `$HOME/.cache/ms-playwright/mcp-auth.json`, the current value.

## When to do this

Hitting a GitHub login screen — or a 404 on a private repo (GitHub returns 404 to unauthenticated users) — means `mcp-auth.json` is missing or its session has expired. Confirm with `browser_snapshot`; never try to drive GitHub's login form blind (credentials, 2FA codes, and passkeys can't be typed into a headless window, and you must not type them for the user anyway).

## Regenerate the storage state

Run a one-shot headed browser that saves storage on close — no MCP config edits, no `/mcp` reconnect dance. This is a user-run login helper, not a screenshot path: screenshots still go only through the MCP, never the Playwright CLI.

```bash
npx -y playwright open --save-storage="$HOME/.cache/ms-playwright/mcp-auth.json" https://github.com/login
```

If Playwright's managed Chromium isn't installed, the command errors with an install hint — either run `npx playwright install chromium` first, or append `--browser=chrome` to use the system Chrome instead.

1. The command blocks until the browser is closed, so launch it in the background (or ask the user to run it in their own terminal).
2. A visible browser window opens at the GitHub login page. The user signs in themselves — credentials, 2FA, passkey. **Do not type their credentials for them.**
3. When the user closes the browser window, cookies and localStorage are written to `mcp-auth.json`.

## Pick up the new state

1. `browser_close` — the current MCP browser session was created from the stale state.
2. `browser_navigate` to `https://github.com`, then `browser_snapshot` — the fresh isolated context re-reads `mcp-auth.json`. Confirm the account sidebar shows the user's handle.
3. If it still shows logged-out, ask the user to run `/mcp` → **playwright** → **reconnect**, then repeat step 2.

## Mid-task

If you hit a 404 / login screen mid-task, **stop**, regenerate the state file as above, pick up the new state, then resume the task.
