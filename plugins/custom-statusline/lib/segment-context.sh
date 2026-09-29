#!/usr/bin/env bash
# Context-window segment: usage percentage straight off the stdin payload —
# Claude Code computes this already, no estimation needed.

CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH="${CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH:-10}"

# Render a filled/empty block bar for a 0-100 percentage.
render_usage_bar() {
  local percent="$1" width="$2"
  local filled=$(((percent * width + 50) / 100))
  [[ "$filled" -gt "$width" ]] && filled="$width"
  [[ "$filled" -lt 0 ]] && filled=0
  local empty=$((width - filled))

  local bar=""
  local i
  for ((i = 0; i < filled; i++)); do bar+="█"; done
  for ((i = 0; i < empty; i++)); do bar+="░"; done
  printf '%s' "$bar"
}

segment_context() {
  local payload_json="$1"
  local used_pct
  used_pct="$(printf '%s' "$payload_json" | jq -r '.context_window.used_percentage // empty')"
  [[ -n "$used_pct" ]] || return 0
  printf '%s %s%%' "$(render_usage_bar "$used_pct" "$CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH")" "$used_pct"
}
