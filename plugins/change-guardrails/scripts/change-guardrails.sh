#!/usr/bin/env bash
# change-guardrails — inspect and test the guard that hooks/guard-bash.sh enforces.
#
#   change-guardrails check <command...>   judge a command without running it
#   change-guardrails rules                list every active rule and where it came from
#   change-guardrails health               check the dependencies and both rules files
#   change-guardrails log [N]              show the last N audit lines (default 20)
#
# Exit codes: 0 ok / would be allowed, 1 runtime error, 2 usage, 3 would be stopped or asked.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/guard.sh
source "$ROOT/lib/guard.sh"

usage() {
  cat <<'EOF'
usage: change-guardrails <command>

  check <command...>   judge a command without running it
  rules                list every active rule and where it came from
  health               check the dependencies and both rules files
  log [N]              show the last N audit lines (default 20)
EOF
}

cmd_check() {
  [[ $# -ge 1 ]] || { echo "usage: change-guardrails check <command...>" >&2; return 2; }
  command -v jq >/dev/null 2>&1 || echo "note: jq is missing, so the hook itself would allow everything" >&2
  local text="$*"
  guard_evaluate "$text"
  echo "Examined (what would run, quoted text removed):"
  echo "  $GUARD_NORMALIZED"
  if [[ "$GUARD_BROKEN" -eq 1 ]]; then
    echo "Rules file problems:"
    printf '%s' "$GUARD_PROBLEMS" | sed 's/^/  /'
    echo "Decision: ask (every command asks while the rules are broken)"
    return 3
  fi
  if [[ -n "$GUARD_MATCHED" ]]; then
    echo "Matched:"
    while IFS= read -r line; do
      [[ -n "$line" ]] || continue
      local rest="${line#* }"
      echo "  [${line%% *}] ${rest%% *}: ${rest#* }"
    done <<<"$GUARD_MATCHED"
  else
    echo "Matched: nothing"
  fi
  [[ -n "$GUARD_ESCAPE" ]] && echo "Escape marker: GUARD-OK reason \"$GUARD_ESCAPE\" (deny becomes ask)"
  echo "Decision: $GUARD_DECISION"
  [[ "$GUARD_DECISION" == "allow" ]] && return 0
  return 3
}

cmd_rules() {
  guard_load_policy
  local total=0 rule d rest scope id msg
  echo "Active rules (default: $GUARD_DEFAULT_RULES; user: $(guard_config_dir)/rules):"
  while IFS= read -r rule; do
    [[ -n "$rule" ]] || continue
    d="${rule%%@@*}"; rest="${rule#*@@}"
    scope="${rest%%@@*}"; rest="${rest#*@@}"
    id="${rest%%@@*}"; rest="${rest#*@@}"
    msg="${rest#*@@}"; msg="${msg#*@@}"
    local state=""
    [[ "$GUARD_DISABLED" == *" $id "* ]] && state=" (disabled by the user file)"
    echo "  $d  $id  [$scope]  $msg$state"
    total=$((total + 1))
  done <<<"$GUARD_RULES"
  echo "Rules: $total"
  [[ -n "$GUARD_PROBLEMS" ]] && { echo "Problems:"; printf '%s' "$GUARD_PROBLEMS" | sed 's/^/  /'; return 3; }
  return 0
}

cmd_health() {
  local failed=0 checked=0
  ok() { checked=$((checked + 1)); echo "  ok    $1"; }
  bad() { checked=$((checked + 1)); failed=$((failed + 1)); echo "  FAIL  $1"; }

  echo "change-guardrails health"
  if command -v jq >/dev/null 2>&1; then ok "jq found ($(command -v jq))"
  else bad "jq not found: the hook fails open and guards nothing. Install jq."; fi

  if command -v awk >/dev/null 2>&1 && command -v grep >/dev/null 2>&1; then ok "awk and grep found"
  else bad "awk or grep missing"; fi

  [[ -f "$ROOT/hooks/hooks.json" ]] && jq -e . "$ROOT/hooks/hooks.json" >/dev/null 2>&1 \
    && ok "hooks.json is valid JSON" || bad "hooks.json missing or not valid JSON"

  guard_load_policy
  if [[ -z "$GUARD_PROBLEMS" ]]; then ok "rules files parse (default and user)"
  else bad "rules files have problems, so every command asks:"; printf '%s' "$GUARD_PROBLEMS" | sed 's/^/        /'; fi

  local n
  n="$(printf '%s' "$GUARD_RULES" | grep -c . || true)"
  ok "$n rules loaded"

  if [[ "$GUARD_DISABLED" != " " ]]; then
    echo "  note  rules disabled by the user file:$GUARD_DISABLED"
  fi

  # A live self-test: the hook must stop a command that is certain to be caught.
  local probe='git push --force origin main'
  guard_evaluate "$probe"
  if [[ "$GUARD_DECISION" != "allow" || "$GUARD_BROKEN" -eq 1 ]]; then ok "self-test: '$probe' is stopped"
  else bad "self-test: '$probe' was allowed; the push-force-protected rule may be disabled"; fi

  local dir
  dir="$(guard_state_dir)"
  if mkdir -p "$dir" 2>/dev/null && [[ -w "$dir" ]]; then ok "audit folder writable ($dir)"
  else bad "audit folder not writable ($dir): decisions are still enforced but not logged"; fi

  echo "Checked: $checked · failed: $failed"
  [[ "$failed" -eq 0 ]]
}

cmd_log() {
  local n="${1:-20}" file
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "usage: change-guardrails log [N]" >&2; return 2; }
  file="$(guard_state_dir)/audit.log"
  if [[ ! -f "$file" ]]; then echo "No audit log yet ($file)"; return 0; fi
  echo "Last $n of $(wc -l <"$file" | tr -d ' ') decisions ($file; time, decision, rules):"
  tail -n "$n" "$file"
}

case "${1:-}" in
  check) shift; cmd_check "$@" ;;
  rules) cmd_rules ;;
  health) cmd_health ;;
  log) shift; cmd_log "$@" ;;
  -h | --help | help | "") usage ;;
  *) echo "change-guardrails: unknown command '$1'" >&2; usage >&2; exit 2 ;;
esac
