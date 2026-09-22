#!/bin/bash
# Prepares a Claude Code web session's container: Ruby, gems, libvips, postgres,
# redis and the Playwright browser. Everything lives in web_sandbox_setup.sh, which
# is also runnable by hand - see the sandbox-test-setup skill.
#
# Local checkouts (Conductor workspaces, worktrees, a laptop) manage their own
# toolchain through mise, so this is a no-op outside the remote sandbox.
set -uo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

SETUP="${CLAUDE_PROJECT_DIR:-/home/user/bike_index}/.claude/skills/sandbox-test-setup/assets/web_sandbox_setup.sh"
[ -x "$SETUP" ] || [ -f "$SETUP" ] || exit 0

# Never fail the session over setup: a half-built container is still worth
# starting, and the skill covers finishing it by hand.
bash "$SETUP" || echo "setup did not finish cleanly - see the sandbox-test-setup skill"
