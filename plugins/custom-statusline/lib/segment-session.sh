#!/usr/bin/env bash
# Session segment: the session id (and name, if any) Claude Code hands the
# statusline script on stdin.

segment_session() {
  local payload_json="$1"
  local session_id
  session_id="$(printf '%s' "$payload_json" | jq -r '.session_id // empty')"
  [[ -n "$session_id" ]] || return 0
  printf '%s' "${session_id:0:8}"
}
