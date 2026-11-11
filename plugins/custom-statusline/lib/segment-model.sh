#!/usr/bin/env bash
# Model segment: model id, reasoning effort and thinking flag, straight off the
# stdin payload. Fields that are absent are left out, never guessed.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./runtime.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/runtime.sh"

segment_model() {
  local payload_json="$1" id effort thinking
  IFS=$'\x1f' read -r id effort thinking <<<"$(printf '%s' "$payload_json" | jq -r '
    [ (.model.id // .model.display_name // ""),
      (.effort.level // ""),
      (if .thinking.enabled == null then "" else (.thinking.enabled | tostring) end)
    ] | join("\u001f")' 2>/dev/null)"
  [[ -n "$id" ]] || return 0
  local out="$id"
  [[ -n "$effort" ]] && out+=" · $effort"
  [[ -n "$thinking" ]] && out+=" · thinking:$thinking"
  sl_color dim "$out"
}
