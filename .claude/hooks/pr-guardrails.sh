#!/bin/bash
# PreToolUse guard on two things an agent does to a PR. Both are reminders that
# arrive at the moment they're actionable, not guarantees: the real boundary for
# merging is branch protection on GitHub, which holds for every tool and route.
#
# Merging is denied with nothing that clears it. Opening or editing is denied
# until the `pr` skill is loaded - which checks it was loaded, not followed.
#
# Runs on every Bash call, so the prefilter decides without spawning anything.
set -uo pipefail

input=$(</dev/stdin)

# Substrings only, no pattern spelt twice: every deny below needs one of these, so
# this is a superset by construction and can't drift out of step with them. Note
# "github" does not contain "gh" - a bare curl to the REST route is caught by the
# third, not the second.
[[ $input == *pull_request* || $input == *gh* || $input == *merge* ]] || exit 0

field() { jq -r "$1 // \"\"" <<<"$input" 2>/dev/null; }

deny() { jq -n --arg reason "$1" '{hookSpecificOutput: {
  hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $reason }}'; }

no_merging="Merging a PR is never the agent's to do - it is the human's call, including when they have just asked for it. Nothing clears this. Tell them the PR is ready and leave it, and do not look for another route to the same action."

# Matched anywhere in the command rather than at a command boundary: a false
# positive costs one reworded grep, a false negative is an irreversible public
# action. The subcommand form covers --auto; the others are the REST and GraphQL
# routes. `[[:space:]]+` keeps the literal out of this file, which would otherwise
# deny any command that quotes it.
subcommand="gh[[:space:]]+pr[[:space:]]+merge"
api_route='pulls/[0-9]+/merge|mergePullRequest'

tool=$(field .tool_name)
command=$(field .tool_input.command)

# Fail closed on this half only: the prefilter saw a merge shape, so an empty tool
# means jq failed rather than that the call is harmless. Exit 2 rather than deny(),
# which would itself need the jq that is missing; Claude Code blocks on 2 and uses
# stderr as the reason. The authoring half below keeps the opposite posture, where
# a false negative costs nothing.
if [ -z "$tool" ] && [[ $input =~ $subcommand|$api_route|merge_pull_request ]]; then
  echo "$no_merging" >&2
  exit 2
fi

if [[ $tool == *merge_pull_request || $command =~ $subcommand || $command =~ $api_route ]]; then
  deny "$no_merging"
  exit 0
fi

# The hook is the discriminator, not settings.json's matcher - `list_pull_requests`
# also ends in `_pull_request`, and only here is it known that reads are fine.
# `gh pr comment`, `view`, `list` likewise: only authoring is gated.
case "$tool" in
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

deny 'AGENTS.md routes PR authoring through the `pr` skill. Invoke it (Skill tool, skill: "pr") and follow it from the top; this command is allowed once it is loaded.'
