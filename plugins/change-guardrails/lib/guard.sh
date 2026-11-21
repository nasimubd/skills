#!/usr/bin/env bash
# guard.sh — the policy engine shared by hooks/guard-bash.sh and scripts/change-guardrails.sh,
# so the command a person tests with `check` is judged by the same code as a live Bash call.
#
# Source it; it defines functions only. bash 3.2 compatible (macOS): no associative arrays,
# no mapfile, no ${var,,}, no `&` in ${var//pat/rep} replacements.
#
# Rule record, one per line:  decision@@scope@@id@@regex@@message
# (format and scopes are described at the top of policy/default.rules)

[[ -n "${GUARD_LIB_LOADED:-}" ]] && return 0
GUARD_LIB_LOADED=1

GUARD_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD_ROOT="$(cd "$GUARD_LIB_DIR/.." && pwd)"
GUARD_DEFAULT_RULES="$GUARD_ROOT/policy/default.rules"
GUARD_B='(^|[^[:alnum:]_.-])'

guard_config_dir() {
  printf '%s' "${CHANGE_GUARDRAILS_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/change-guardrails}"
}

guard_state_dir() {
  printf '%s' "${CHANGE_GUARDRAILS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/change-guardrails}"
}

# Fills GUARD_RULES (records, newline separated), GUARD_DISABLED (" id id "),
# GUARD_PROBLEMS (newline separated "file:line: what"), GUARD_SOURCES (id=source lines).
guard_load_policy() {
  GUARD_RULES=""
  GUARD_DISABLED=" "
  GUARD_PROBLEMS=""
  GUARD_SOURCES=""
  local user_file
  user_file="$(guard_config_dir)/rules"
  guard_load_file "$GUARD_DEFAULT_RULES" default || true
  if [[ -f "$user_file" ]]; then
    guard_load_file "$user_file" user || true
  fi
}

guard_problem() {
  GUARD_PROBLEMS="${GUARD_PROBLEMS}$1"$'\n'
}

guard_load_file() {
  local file="$1" source="$2" n=0 line d rest scope id re msg
  if [[ ! -r "$file" ]]; then
    guard_problem "$file:0: cannot read the rules file"
    return 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))
    case "$line" in '' | '#'*) continue ;; esac
    case "$line" in [[:space:]]*) [[ -z "${line//[[:space:]]/}" ]] && continue ;; esac

    d="${line%%@@*}"
    if [[ "$d" == "disable" ]]; then
      rest="${line#*@@}"
      id="${rest%%@@*}"
      if [[ "$source" != "user" ]]; then
        guard_problem "$file:$n: disable is only allowed in the user rules file"
      elif [[ -z "$id" || "$id" == *[!abcdefghijklmnopqrstuvwxyz0-9-]* ]]; then
        guard_problem "$file:$n: disable needs a rule id (lowercase letters, digits, hyphens)"
      else
        GUARD_DISABLED="${GUARD_DISABLED}${id} "
      fi
      continue
    fi

    if [[ "$line" != *@@*@@*@@*@@* ]]; then
      guard_problem "$file:$n: expected decision@@scope@@id@@regex@@message"
      continue
    fi
    rest="${line#*@@}"
    scope="${rest%%@@*}"
    rest="${rest#*@@}"
    id="${rest%%@@*}"
    rest="${rest#*@@}"
    re="${rest%%@@*}"
    msg="${rest#*@@}"

    case "$d" in deny | ask) ;; *)
      guard_problem "$file:$n: decision must be deny or ask, not '$d'"
      continue
      ;;
    esac
    case "$scope" in cmd | raw | sql) ;; *)
      guard_problem "$file:$n: scope must be cmd, raw or sql, not '$scope'"
      continue
      ;;
    esac
    if [[ -z "$id" || "$id" == *[!abcdefghijklmnopqrstuvwxyz0-9-]* ]]; then
      guard_problem "$file:$n: rule id must be lowercase letters, digits and hyphens"
      continue
    fi
    if [[ -z "$re" || -z "$msg" ]]; then
      guard_problem "$file:$n: regex and message must not be empty"
      continue
    fi
    re="${re//\{B\}/$GUARD_B}"
    # grep -E exits 2 on an invalid expression and 0/1 otherwise.
    local rc=0
    printf '' | grep -Eq -- "$re" 2>/dev/null || rc=$?
    if [[ "$rc" -ge 2 ]]; then
      guard_problem "$file:$n: invalid regular expression in rule '$id'"
      continue
    fi
    if [[ "$GUARD_SOURCES" == *"|$id="* ]]; then
      guard_problem "$file:$n: duplicate rule id '$id'"
      continue
    fi
    GUARD_RULES="${GUARD_RULES}${d}@@${scope}@@${id}@@${re}@@${msg}"$'\n'
    GUARD_SOURCES="${GUARD_SOURCES}|${id}=${source}"
  done <"$file"
  return 0
}

# stdin: the command; stdout: what would run (see normalize.awk).
guard_normalize() {
  awk -v q="'" -v dq='"' -v bt='`' -f "$GUARD_LIB_DIR/normalize.awk"
}

# stdin: the command; stdout: one line, newlines joined by " ; ".
guard_flatten() {
  awk 'NR > 1 { printf " ; " } { printf "%s", $0 } END { print "" }'
}

# Sets GUARD_DECISION (allow|ask|deny), GUARD_MATCHED (lines "decision id message"),
# GUARD_ESCAPE (reason or empty), GUARD_NORMALIZED, GUARD_BROKEN (1 when the policy is broken).
guard_evaluate() {
  local command="$1" raw norm rule d scope id re msg text opt rc
  GUARD_DECISION="allow"
  GUARD_MATCHED=""
  GUARD_ESCAPE=""
  GUARD_BROKEN=0

  raw="$(printf '%s' "$command" | guard_flatten)"
  norm="$(printf '%s' "$command" | guard_normalize)"
  GUARD_NORMALIZED="$norm"

  guard_load_policy
  if [[ -n "$GUARD_PROBLEMS" ]]; then
    GUARD_BROKEN=1
    GUARD_DECISION="ask"
    return 0
  fi

  while IFS= read -r rule; do
    [[ -n "$rule" ]] || continue
    d="${rule%%@@*}"
    rest="${rule#*@@}"
    scope="${rest%%@@*}"
    rest="${rest#*@@}"
    id="${rest%%@@*}"
    rest="${rest#*@@}"
    re="${rest%%@@*}"
    msg="${rest#*@@}"
    [[ "$GUARD_DISABLED" == *" $id "* ]] && continue
    opt="-Eq"
    case "$scope" in
      cmd) text="$norm" ;;
      raw) text="$raw" ;;
      sql) text="$raw"; opt="-Eiq" ;;
    esac
    rc=0
    printf '%s\n' "$text" | grep $opt -- "$re" 2>/dev/null || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      GUARD_MATCHED="${GUARD_MATCHED}${d} ${id} ${msg}"$'\n'
      if [[ "$d" == "deny" ]]; then GUARD_DECISION="deny"
      elif [[ "$GUARD_DECISION" == "allow" ]]; then GUARD_DECISION="ask"; fi
    fi
  done <<<"$GUARD_RULES"

  # The marker downgrades a deny to an ask. It never produces an allow.
  if [[ "$GUARD_DECISION" == "deny" ]]; then
    local found
    found="$(printf '%s' "$raw" | grep -Eo 'GUARD-OK:[[:space:]]*[^<[:space:]][^[:cntrl:]]{9,}' 2>/dev/null | head -n 1)" || true
    if [[ -n "$found" ]]; then
      GUARD_ESCAPE="${found#GUARD-OK:}"
      GUARD_ESCAPE="${GUARD_ESCAPE#"${GUARD_ESCAPE%%[![:space:]]*}"}"
      GUARD_DECISION="ask"
    fi
  fi
  return 0
}

# The reason the user (and the agent) is shown.
guard_reason() {
  local out line
  if [[ "$GUARD_BROKEN" -eq 1 ]]; then
    out="change-guardrails: the rules file is broken, so every command asks until it is fixed. ${GUARD_PROBLEMS%$'\n'}. Run 'change-guardrails health' for the full list."
    printf '%s' "$out" | tr '\n' ' '
    return 0
  fi
  out="change-guardrails:"
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    out="$out [${line%% *}] ${line#* }."
  done <<<"$GUARD_MATCHED"
  if [[ -n "$GUARD_ESCAPE" ]]; then
    out="$out The command carries GUARD-OK (reason given by the agent: $GUARD_ESCAPE); it is allowed to proceed only if you approve."
  elif [[ "$GUARD_DECISION" == "deny" ]]; then
    out="$out Stopped. Only if the user explicitly asked for this exact command, re-run it with 'GUARD-OK: <reason of at least ten characters>' in the command; the user will then be asked to approve."
  fi
  printf '%s' "$out"
}

# One line per decision, never the command text.
guard_audit() {
  local dir ids line
  dir="$(guard_state_dir)"
  ids=""
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    rest="${line#* }"
    ids="$ids${ids:+,}${rest%% *}"
  done <<<"$GUARD_MATCHED"
  [[ "$GUARD_BROKEN" -eq 1 ]] && ids="policy-broken"
  [[ -n "$GUARD_ESCAPE" ]] && ids="$ids,escape-marker"
  mkdir -p "$dir" 2>/dev/null || return 0
  printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$GUARD_DECISION" "${ids:--}" >>"$dir/audit.log" 2>/dev/null || true
}
