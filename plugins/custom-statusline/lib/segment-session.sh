#!/usr/bin/env bash
# Session segment: where the session transcript lives and its id, so the pair
# can be pasted into a prompt ("analyse this JSONL").
#
#   ~/.claude/projects JSONL ID: 8bb6c049-5a75-40b9-b6f3-b72d77879486
#
# The folder comes from the payload's transcript_path (two levels up: the
# transcript sits in a per-project folder inside the projects folder), so a
# relocated config directory is shown correctly; absent that, the default.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./runtime.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/runtime.sh"

segment_session() {
  local payload_json="$1" session_id transcript
  IFS=$'\x1f' read -r session_id transcript <<<"$(printf '%s' "$payload_json" | jq -r '
    [(.session_id // ""), (.transcript_path // "")] | join("\u001f")' 2>/dev/null)"
  [[ -n "$session_id" ]] || return 0

  local folder="~/.claude/projects"
  if [[ "$transcript" == /* ]]; then
    folder="$(dirname "$(dirname "$transcript")")"
    [[ "$folder" == "$HOME"/* ]] && folder="~${folder#"$HOME"}"
  fi
  sl_color dim "$folder JSONL ID: $session_id"
}
