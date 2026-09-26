#!/bin/bash
# PreToolUse guard on two things an agent does to a PR. Both are reminders that
# arrive at the moment they're actionable, not guarantees: the real boundary for
# merging is branch protection on GitHub, which holds for every tool and route.
#
# Merging is denied with nothing that clears it. Opening or editing is denied
# until the `pr` skill is loaded - which checks it was loaded, not followed.
#
# Nothing outside bash is required: `jq` is absent from the CI image and may be
# absent from a sandbox, and a guard that quietly stops guarding there is worse
# than no guard. Blocking is exit 2 with the reason on stderr, which Claude Code
# treats the same as the JSON deny and which needs no tool to emit.
set -uo pipefail

input=$(</dev/stdin)

# Substrings only, no pattern spelt twice: every block below needs one of these, so
# this is a superset by construction and can't drift out of step with them. Note
# "github" does not contain "gh" - a bare curl to the REST route is caught by the
# third, not the second.
[[ $input == *pull_request* || $input == *gh* || $input == *merge* ]] || exit 0

block() { echo "$1" >&2; exit 2; }

# Tool names are bare identifiers, so no unescaping is needed to read one out.
tool=""
tool_pattern='"tool_name"[[:space:]]*:[[:space:]]*"([^"]+)"'
[[ $input =~ $tool_pattern ]] && tool="${BASH_REMATCH[1]}"

# Matched anywhere in the payload rather than at a command boundary: a false
# positive costs one reworded grep, a false negative is an irreversible public
# action. The subcommand form covers --auto; the others are the REST and GraphQL
# routes. `[[:space:]]+` keeps the literal out of this file, which would otherwise
# block any command that quotes it.
subcommand="gh[[:space:]]+pr[[:space:]]+merge"
api_route='pulls/[0-9]+/merge|mergePullRequest'

if [[ $tool == *merge_pull_request || $input =~ $subcommand || $input =~ $api_route ]]; then
  block "Merging a PR is never the agent's to do - it is the human's call, including when they have just asked for it. Nothing clears this. Tell them the PR is ready and leave it, and do not look for another route to the same action."
fi

# The hook is the discriminator, not settings.json's matcher - `list_pull_requests`
# also ends in `_pull_request`, and only here is it known that reads are fine.
# `gh pr comment`, `view`, `list` likewise: only authoring is gated.
case "$tool" in
  Bash) [[ $input =~ gh[[:space:]]+pr[[:space:]]+(create|edit) ]] || exit 0 ;;
  mcp__*__create_pull_request | mcp__*__update_pull_request) ;;
  *) exit 0 ;;
esac

# Two markers: the Skill tool_use's own input, and the tag a typed slash command
# leaves. Both are assembled from pieces, and described rather than spelt out, so
# that reading *this* file into the transcript can't satisfy the check below.
transcript=""
transcript_pattern='"transcript_path"[[:space:]]*:[[:space:]]*"([^"]+)"'
[[ $input =~ $transcript_pattern ]] && transcript="${BASH_REMATCH[1]}"
[ -r "$transcript" ] || exit 0
invoked='"input":\{"skill":"pr"'
typed="<command-name>/pr<""/command-name>"
grep -qE "$invoked|$typed" "$transcript" && exit 0

block 'AGENTS.md routes PR authoring through the `pr` skill. Invoke it (Skill tool, skill: "pr") and follow it from the top; this command is allowed once it is loaded.'
