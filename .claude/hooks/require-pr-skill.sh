#!/bin/bash
# PreToolUse guard: opening or editing a PR goes through the `pr` skill.
#
# It checks the skill was *loaded*, not that it was followed — so it's a reminder
# with teeth rather than a guarantee, and it clears for the rest of the session
# once the skill appears. Deliberately cheap: it runs on every Bash call, so the
# prefilter below decides without spawning anything.
set -uo pipefail

input=$(</dev/stdin)

# ~every call exits here. A false positive just falls through to the jq path.
[[ $input == *_pull_request* || $input =~ gh[[:space:]]+pr[[:space:]]+(create|edit) ]] || exit 0

field() { jq -r "$1 // \"\"" <<<"$input" 2>/dev/null; }

# Spelt out rather than leaning on settings.json's matcher: `list_pull_requests`
# also contains `_pull_request`, so a widened matcher would start denying reads.
case "$(field .tool_name)" in
  # `gh pr comment`, `view`, `list` are fine - only authoring is gated.
  Bash) [[ "$(field .tool_input.command)" =~ gh[[:space:]]+pr[[:space:]]+(create|edit) ]] || exit 0 ;;
  mcp__*__create_pull_request | mcp__*__update_pull_request) ;;
  *) exit 0 ;;
esac

# Two markers: the Skill tool_use's own input, and the tag a typed slash command
# leaves. Both are assembled from pieces, and described rather than spelt out, so
# that reading *this* file into the transcript can't satisfy the check below.
transcript=$(field .transcript_path)
[ -r "$transcript" ] || exit 0
invoked='"input":\{"skill":"pr"'
typed="<command-name>/pr<""/command-name>"
grep -qE "$invoked|$typed" "$transcript" && exit 0

jq -n '{hookSpecificOutput: {
  hookEventName: "PreToolUse",
  permissionDecision: "deny",
  permissionDecisionReason: "AGENTS.md routes PR authoring through the `pr` skill - it merges from the base, runs /simplify and bin/lint, and captures screenshots for frontend diffs. Invoke it (Skill tool, skill: \"pr\") and follow it from the top; this command is allowed once it is loaded."
}}'
