# Logging into GitHub when the MCP runs headless

The Playwright MCP is configured with `--headless` (no visible window) so it never steals focus. The login cookie lives in the persistent `--user-data-dir` profile and works headless once it exists — but you can't *type* credentials into a window that doesn't exist. When GitHub logs the user out (expired session, or first-ever use), re-login by temporarily running headed:

```bash
# 1. Remove the --headless flag for one session
claude mcp remove playwright -s user
claude mcp add playwright -s user -- npx -y @playwright/mcp@latest \
  --user-data-dir="$HOME/.cache/ms-playwright/mcp-chrome-shared"
# 2. Restart Claude Code, sign into github.com in the visible window (handles 2FA)
# 3. Re-add --headless once the cookie is saved to the profile:
claude mcp remove playwright -s user
claude mcp add playwright -s user -- npx -y @playwright/mcp@latest \
  --user-data-dir="$HOME/.cache/ms-playwright/mcp-chrome-shared" --headless
```

If you hit a 404 / login screen mid-task and the MCP is headless, stop and tell the user to do the headed re-login above rather than trying to drive the login form blind.
