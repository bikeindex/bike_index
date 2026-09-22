#!/bin/bash
# PreToolUse guard: opening or editing a PR goes through the `pr` skill, which runs
# /simplify, bin/lint, an AGENTS.md pass and a merge from the base before it writes
# a body, and handles screenshots for frontend diffs. None of that happens when the
# PR is created straight from `gh` or the GitHub MCP tools.
#
# Allows the call once the skill is loaded, so the deny is self-clearing: the model
# invokes the skill and retries. Anything it can't determine, it allows.
set -uo pipefail

input=$(cat)
field() { jq -r "$1 // \"\"" <<<"$input" 2>/dev/null; }

case "$(field .tool_name)" in
  Bash)
    # `gh pr comment`, `view`, `list`, `diff` are all fine - only authoring is gated.
    [[ "$(field .tool_input.command)" =~ gh[[:space:]]+pr[[:space:]]+(create|edit) ]] || exit 0
    ;;
  *create_pull_request | *update_pull_request) ;;
  *) exit 0 ;;
esac

# A Skill tool_use writes "skill":"pr"; a typed /pr writes the command-name tag.
transcript=$(field .transcript_path)
[ -r "$transcript" ] || exit 0
grep -qE '"skill": *"pr"|<command-name>/pr</command-name>' "$transcript" && exit 0

jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: "Authoring a PR goes through the `pr` skill (AGENTS.md). It runs /simplify, bin/lint, an AGENTS.md conformance pass and a merge from the base before writing the body, and captures screenshots for frontend diffs. Invoke it (Skill tool, skill: \"pr\") and follow it from the top - this command will be allowed once it is loaded."
}}'
