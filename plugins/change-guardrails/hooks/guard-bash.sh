#!/usr/bin/env bash
# guard-bash.sh — PreToolUse hook on Bash.
#
# Judges the command with the rules in policy/default.rules (plus the user's own) and
# answers deny or ask. No match prints nothing, which leaves the host's normal permission
# flow untouched. The decision, the reasoning and the limits are in
# docs/adr/2026-11-12-change-guardrails.md.
#
# Fail-open: input this hook cannot read, a missing jq or a crash allows the call. The one
# deliberate exception is a broken rules file, which makes every call ask (see the ADR).

set -uo pipefail

input="$(cat)" || exit 0
command -v jq >/dev/null 2>&1 || exit 0
cmd="$(jq -r '.tool_input.command // empty' <<<"$input" 2>/dev/null)" || exit 0
[[ -n "$cmd" ]] || exit 0

# shellcheck source=../lib/guard.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/lib/guard.sh" || exit 0

guard_evaluate "$cmd" || exit 0
[[ "$GUARD_DECISION" == "allow" ]] && exit 0

reason="$(guard_reason)"
guard_audit
jq -n --arg d "$GUARD_DECISION" --arg r "$reason" \
  '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: $d, permissionDecisionReason: $r}}' \
  || exit 0
exit 0
