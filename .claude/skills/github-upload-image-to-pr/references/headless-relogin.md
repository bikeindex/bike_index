# Logging into GitHub when the MCP runs headless

The Playwright MCP is usually configured with `--headless` (no visible window, so it never steals focus). The github.com login cookie lives in the persistent `--user-data-dir` profile and keeps working headless once it exists — but you can't *type* credentials, a 2FA code, or a passkey into a window that doesn't exist. So when GitHub has logged the user out (expired session, or first-ever use), briefly run **headed**, let the user sign in, then switch back to headless.

## First: confirm you're actually headless (the trigger gate)

Do **none** of this unless the MCP is currently headless. Check:

```bash
claude mcp get playwright   # look for `--headless` in the Args line
```

If `--headless` is **absent**, the window is already visible — just `browser_navigate` to `https://github.com/login` and ask the user to sign in there. Skip the entire config dance below.

## The clean switch — one reconnect each way

The trap that caused us to reconnect repeatedly: the running browser holds a lock on the shared profile dir (`mcp-chrome-shared`). If you change the config and reconnect while that browser is **still alive**, the new server can't launch — it fails with `Browser is already in use ... use --isolated` — and you're forced to kill orphaned processes, which itself drops the MCP connection and forces yet another reconnect.

Avoid all of that by **closing the browser first** so the lock is released *before* each reconnect. Done this way it's exactly one reconnect per direction, no process-killing.

### Headless → headed (to log in)

1. `browser_close` — releases the profile lock. Login state lives on disk, so this never logs anyone out.
2. Drop the `--headless` flag (re-register the server without it):
   ```bash
   claude mcp remove playwright -s user
   claude mcp add playwright -s user -- npx -y @playwright/mcp@latest \
     --user-data-dir="$HOME/.cache/ms-playwright/mcp-chrome-shared"
   ```
3. Ask the user to run `/mcp` → **playwright** → **reconnect**. A full Claude Code restart is **not** needed — reconnect re-reads the config and relaunches the server.
4. After they confirm reconnection, `browser_navigate` to `https://github.com/login`. A visible Chrome window appears; the user types their credentials and clears any 2FA/passkey themselves. **Do not type their credentials for them.**
5. When they say they're signed in, `browser_navigate` to `https://github.com` and `browser_snapshot` to confirm the account sidebar shows their handle.

### Headed → headless (restore when done)

6. `browser_close` again — releases the lock; the freshly-saved cookie is already persisted to the profile.
7. Re-add `--headless`:
   ```bash
   claude mcp remove playwright -s user
   claude mcp add playwright -s user -- npx -y @playwright/mcp@latest \
     --user-data-dir="$HOME/.cache/ms-playwright/mcp-chrome-shared" --headless
   ```
8. User runs `/mcp` → reconnect once more. Verify with a `browser_navigate` + `browser_snapshot`: headless again, still signed in.

> The config lives in `~/.claude.json` (often a symlink into a dotfile manager like Mackup). Prefer the `claude mcp remove/add` commands above over hand-editing that file — they handle the symlink and write the exact args. If you must edit the JSON directly, edit the real symlink target, not the link.

## Fallback: "Browser is already in use" even after closing

This only happens when a **prior crashed session** left an orphaned headless Chrome still holding the lock. Inspect first, then kill **only** the MCP-scoped headless processes — never bare "Chrome", which would take down the user's real browser ([[feedback_never_kill_non_mcp_chrome]]):

```bash
# Inspect — the actual Chrome browser process has `--headless` BEFORE the
# user-data-dir, so eyeball the list rather than trusting a one-shot regex.
# (Your own shell may appear in the list because this command contains the
# match strings — ignore the zsh/grep lines.)
pgrep -fl "mcp-chrome-shared" | grep -- "--headless"
```

Confirm each line is a `Google Chrome`, `node`, or `playwright-mcp` process tied to `mcp-chrome-shared`, then `kill <those PIDs>`. Killing the MCP processes drops the connection, so reconnect via `/mcp` afterward (this is the one case where you pay an extra reconnect).

## Mid-task

If you hit a 404 / login screen mid-task while headless, **stop** and walk the user through the headed re-login above — never try to drive GitHub's login form blind.
