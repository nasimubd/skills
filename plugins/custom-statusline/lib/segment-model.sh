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

segment_model() {
  local payload_json="$1"
  local display_name
  display_name="$(printf '%s' "$payload_json" | jq -r '.model.display_name // empty')"
  printf '%s' "$display_name"
}
