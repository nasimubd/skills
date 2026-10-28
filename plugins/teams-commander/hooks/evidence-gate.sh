#!/usr/bin/env bash
# evidence-gate.sh — PreToolUse hook on Bash.
#
# Denies launching a Teams chat deep link from an ad-hoc command. The only
# sanctioned launcher is `teams.sh open`, which refuses any draft whose claims
# are not backed by current evidence. Without this hook, a session could build
# the URL itself and skip the gate entirely; the SKILL.md saying "don't" is not
# enforcement.
#
# Escape: put `TEAMS-SEND-OK: <reason of at least ten characters>` in the command,
# only when the user has explicitly asked to bypass the gate for that message.
#
# Fail-open: a hook that cannot parse its input allows the call rather than
# blocking all Bash use.

set -uo pipefail

input="$(cat)" || exit 0
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)" || exit 0
[[ -n "$cmd" ]] || exit 0

# Only commands that carry a Teams chat deep link are in scope.
grep -Eq 'teams\.microsoft\.com/l/chat|msteams:/*l/chat' <<<"$cmd" || exit 0

# ...and only when they launch it. Searching for or documenting the URL is fine.
grep -Eq '(^|[;&|[:space:]({`])(/usr/bin/)?(open|osascript|xdg-open)([[:space:]]|$)|webbrowser|shell\.openExternal' <<<"$cmd" || exit 0

if grep -Eq 'TEAMS-SEND-OK:[[:space:]]*[^<[:space:]][^[:cntrl:]]{9,}' <<<"$cmd"; then
  exit 0
fi

reason="Blocked by teams-commander: a Teams chat link must be opened with 'teams-commander open <draft-id> <contact>', which refuses drafts whose claims lack current evidence. Record the evidence, run 'teams-commander verify', then 'teams-commander open'. Bypass only on the user's explicit instruction with 'TEAMS-SEND-OK: <reason>'."
jq -n --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
