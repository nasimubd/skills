#!/usr/bin/env bash
# Session segment: the session id (and name, if any) Claude Code hands the
# statusline script on stdin.

segment_session() {
  local payload_json="$1"
  local session_id session_name
  session_id="$(printf '%s' "$payload_json" | jq -r '.session_id // empty')"
  session_name="$(printf '%s' "$payload_json" | jq -r '.session_name // empty')"
  [[ -n "$session_id" ]] || return 0

  if [[ -n "$session_name" ]]; then
    printf '%s %s' "${session_id:0:8}" "$session_name"
  else
    printf '%s' "${session_id:0:8}"
  fi
}
