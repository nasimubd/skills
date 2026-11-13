#!/usr/bin/env bash
# write-gate.sh — PreToolUse hook on Bash.
#
# Denies a hand-written osascript command that changes Notes or Reminders. The only
# sanctioned writer is `notes-commander`, whose every write needs --confirm and is
# audited, and which has no delete. Without this hook a session could script
# `delete note` itself and skip the gate; the SKILL.md saying "don't" is not enforcement.
#
# Escape: put `NOTES-WRITE-OK: <reason of at least ten characters>` in the command,
# only when the user has explicitly asked for that change.
#
# Fail-open: a hook that cannot parse its input allows the call rather than
# blocking all Bash use.

set -uo pipefail

input="$(cat)" || exit 0
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)" || exit 0
[[ -n "$cmd" ]] || exit 0

# In scope: osascript / JXA aimed at Notes or Reminders...
grep -Eq '(^|[;&|[:space:]({`])(/usr/bin/)?osascript([[:space:]]|$)' <<<"$cmd" || exit 0
grep -Eiq 'application[[:space:]]*(\(|id)?[[:space:]]*\\?["'"'"']?(Notes|Reminders)\b|tell[[:space:]]+app[^[:cntrl:]]*(Notes|Reminders)' <<<"$cmd" || exit 0
# ...that changes something. Reading and showing stay allowed.
grep -Eiq '\b(delete|make[[:space:]]+new|set[[:space:]]+(the[[:space:]]+)?(body|name|completed|due[[:space:]]+date|remind[[:space:]]+me[[:space:]]+date|priority|flagged)|move[[:space:]]|duplicate|empty[[:space:]]+trash)\b' <<<"$cmd" || exit 0

if grep -Eq 'NOTES-WRITE-OK:[[:space:]]*[^<[:space:]][^[:cntrl:]]{9,}' <<<"$cmd"; then
  exit 0
fi

reason="Blocked by notes-commander: changes to Notes and Reminders go through 'notes-commander' (create, append, task add, task done), which needs the user's confirmation for each write and keeps an audit log. There is no delete. Bypass only on the user's explicit instruction with 'NOTES-WRITE-OK: <reason>'."
jq -n --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
