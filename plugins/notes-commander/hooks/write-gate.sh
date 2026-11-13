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

# A script named on the command line (osascript /tmp/x.scpt) is invisible in the command
# text, so read it too. Compiled scripts go through osadecompile when it is available.
body="$cmd"
set -f
read -ra words <<<"$cmd"
set +f
for w in "${words[@]}"; do
  w="${w//[\"\']/}"
  [[ -f "$w" && "$w" =~ \.(scpt|applescript|js|jxa)$ ]] || continue
  if [[ "$w" == *.scpt ]]; then
    body+=$'\n'"$(osadecompile "$w" 2>/dev/null || true)"
  else
    body+=$'\n'"$(head -c 200000 "$w" 2>/dev/null || true)"
  fi
done

grep -Eiq 'application[[:space:]]*(\(|id)?[[:space:]]*\\?["'"'"']?(Notes|Reminders)\b|tell[[:space:]]+app[^[:cntrl:]]*(Notes|Reminders)' <<<"$body" || exit 0

# ...that changes something. Reading and showing stay allowed. Three shapes:
#   verbs that create or remove (delete, make, create, move, duplicate, save, import, empty trash)
#   AppleScript property assignment: "set <anything> of <thing>", which covers body, name, text,
#     container, password, due date and the rest, not a hand-picked list
#   JXA: ".prop = value" assignment and ".delete(" / ".make(" style calls
mutates=0
grep -Eiq '\b(delete|make|create|move|duplicate|save|import)\b|\bempty[[:space:]]+trash\b' <<<"$body" && mutates=1
# "set n to count of notes" is a variable, not a property: drop matches that contain " to ".
if grep -Eio '\bset[[:space:]]+(the[[:space:]]+)?([A-Za-z]+[[:space:]]+){0,3}of[[:space:]]' <<<"$body" \
   | grep -Eviq '[[:space:]]to[[:space:]]'; then mutates=1; fi
grep -Eq '\.[A-Za-z_]+[[:space:]]*=[^=]' <<<"$body" && mutates=1
[[ "$mutates" == 1 ]] || exit 0

if grep -Eq 'NOTES-WRITE-OK:[[:space:]]*[^<[:space:]][^[:cntrl:]]{9,}' <<<"$cmd"; then
  exit 0
fi

reason="Blocked by notes-commander: changes to Notes and Reminders go through 'notes-commander' (create, append, task add, task done), which needs the user's confirmation for each write and keeps an audit log. There is no delete. Bypass only on the user's explicit instruction with 'NOTES-WRITE-OK: <reason>'."
jq -n --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
exit 0
