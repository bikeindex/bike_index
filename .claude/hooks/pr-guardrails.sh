#!/bin/bash
# PreToolUse guard on two things an agent does to a PR.
#
# Merging: denied outright, with no way to clear it. Merging is the human's call
# even when they ask for it in the moment, so an escape hatch would defeat it.
#
# Opening or editing: routed through the `pr` skill. That half checks the skill was
# *loaded*, not that it was followed - a reminder with teeth rather than a
# guarantee - and clears for the session once the skill appears.
#
# Runs on every Bash call, so the prefilter decides without spawning anything.
set -uo pipefail

input=$(</dev/stdin)

# ~every call exits here. A false positive just falls through to the jq path.
[[ $input == *_pull_request* || $input =~ gh[[:space:]]+pr[[:space:]]+(create|edit|merge) ||
  $input =~ pulls/[0-9]+/merge ]] || exit 0

field() { jq -r "$1 // \"\"" <<<"$input" 2>/dev/null; }

deny() { jq -n --arg reason "$1" '{hookSpecificOutput: {
  hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason }}'; }

tool=$(field .tool_name)
command=$(field .tool_input.command)

# Anchored to where a command can actually start, so that *mentioning* the merge
# subcommand - in a grep, a heredoc, a test payload, an edit to this file - isn't
# denied alongside running it. The subcommand form covers --auto; the api form is
# the same act by another route, so it takes both halves.
at_start='(^|[;&|(]|[[:cntrl:]])[[:space:]]*'
merges_pr="${at_start}gh[[:space:]]+pr[[:space:]]+merge"
via_api="${at_start}gh[[:space:]]+api"

if [[ $tool == *merge_pull_request ]] ||
  { [ "$tool" = Bash ] &&
    { [[ $command =~ $merges_pr ]] ||
      { [[ $command =~ $via_api ]] && [[ $command =~ pulls/[0-9]+/merge ]]; }; }; }; then
  deny "Merging a PR is never the agent's to do - it is the human's call, including when they have just asked for it. Tell them the PR is ready and let them merge it. Do not enable auto-merge, and do not look for another route to the same action."
  exit 0
fi

# Spelt out rather than leaning on settings.json's matcher: `list_pull_requests`
# also contains `_pull_request`, so a widened matcher would start denying reads.
case "$tool" in
  # `gh pr comment`, `view`, `list` are fine - only authoring is gated.
  Bash) [[ $command =~ gh[[:space:]]+pr[[:space:]]+(create|edit) ]] || exit 0 ;;
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

deny 'AGENTS.md routes PR authoring through the `pr` skill - it merges from the base, runs /simplify and bin/lint, and captures screenshots for frontend diffs. Invoke it (Skill tool, skill: "pr") and follow it from the top; this command is allowed once it is loaded.'
