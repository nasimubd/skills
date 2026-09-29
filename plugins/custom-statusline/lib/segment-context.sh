#!/usr/bin/env bash
# Context-window segment: usage percentage straight off the stdin payload —
# Claude Code computes this already, no estimation needed.

segment_context() {
  local payload_json="$1"
  local used_pct
  used_pct="$(printf '%s' "$payload_json" | jq -r '.context_window.used_percentage // empty')"
  [[ -n "$used_pct" ]] || return 0
  printf '%s%%' "$used_pct"
}
