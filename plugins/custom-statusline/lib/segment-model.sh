#!/usr/bin/env bash
# Model segment: model display name, straight off the stdin payload.

segment_model() {
  local payload_json="$1"
  local display_name
  display_name="$(printf '%s' "$payload_json" | jq -r '.model.display_name // empty')"
  printf '%s' "$display_name"
}
