#!/bin/bash
# macOS's path_helper puts /usr/bin ahead of the mise shims in a non-interactive
# shell, so a bare `ruby` in Claude's Bash would be the system 2.6
[ -n "$CLAUDE_ENV_FILE" ] && command -v mise >/dev/null || exit 0

grep -qsF mise/shims "$CLAUDE_ENV_FILE" || mise activate bash --shims >>"$CLAUDE_ENV_FILE"
