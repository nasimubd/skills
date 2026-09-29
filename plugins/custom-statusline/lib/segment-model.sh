#!/usr/bin/env bash
# Model segment: model display name, straight off the stdin payload.

# Format milliseconds as "1h23m", "5m", or "42s" — whichever units are
# non-zero, coarsest first.
format_duration_ms() {
  local ms="$1"
  local total_seconds=$((ms / 1000))
  local hours=$((total_seconds / 3600))
  local minutes=$(((total_seconds % 3600) / 60))
  local seconds=$((total_seconds % 60))

  if [[ "$hours" -gt 0 ]]; then
    printf '%dh%dm' "$hours" "$minutes"
  elif [[ "$minutes" -gt 0 ]]; then
    printf '%dm' "$minutes"
  else
    printf '%ds' "$seconds"
  fi
}

# printf "%.2f" needs a real number; the payload always gives us one, but
# guard against empty/non-numeric input rather than let printf error out.
format_cost_usd() {
  local cost="$1"
  [[ "$cost" =~ ^[0-9]+(\.[0-9]+)?$ ]] || { printf '$0.00'; return 0; }
  printf '$%.2f' "$cost"
}

segment_model() {
  local payload_json="$1"
  local display_name cost_usd duration_ms lines_added lines_removed
  display_name="$(printf '%s' "$payload_json" | jq -r '.model.display_name // empty')"
  cost_usd="$(printf '%s' "$payload_json" | jq -r '.cost.total_cost_usd // empty')"
  duration_ms="$(printf '%s' "$payload_json" | jq -r '.cost.total_duration_ms // empty')"
  lines_added="$(printf '%s' "$payload_json" | jq -r '.cost.total_lines_added // 0')"
  lines_removed="$(printf '%s' "$payload_json" | jq -r '.cost.total_lines_removed // 0')"

  [[ -n "$display_name" ]] || return 0

  local out="$display_name"
  [[ -n "$duration_ms" ]] && out+=" $(format_duration_ms "$duration_ms")"
  [[ -n "$cost_usd" ]] && out+=" $(format_cost_usd "$cost_usd")"
  if [[ "$lines_added" -gt 0 || "$lines_removed" -gt 0 ]]; then
    out+=" +${lines_added}/-${lines_removed}"
  fi
  printf '%s' "$out"
}
