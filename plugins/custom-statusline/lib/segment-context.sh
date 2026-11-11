#!/usr/bin/env bash
# Context-window segment: how full the window is and how far the automatic
# compaction trigger is.
#
#   ctx ▕██████·······|≈≈≈≈≈≈≈▏ 30% · 60k/200k · ~107k until compact
#
# The bar is 20 cells for the whole window. Cells left of `|` are the room
# before compaction fires, cells right of it are the region past the trigger.
# Usage comes from the stdin payload; only the trigger position is estimated.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./runtime.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/runtime.sh"

CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH="${CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH:-20}"

# 60000 -> 60k, 1000000 -> 1M, 1500000 -> 1500k.
format_tokens() {
  local n="$1"
  [[ "$n" =~ ^[0-9]+$ ]] || return 0
  if [[ "$n" -ge 1000000 && $((n % 1000000)) -eq 0 ]]; then printf '%dM' $((n / 1000000))
  elif [[ "$n" -ge 1000 ]]; then printf '%dk' $((n / 1000))
  else printf '%d' "$n"
  fi
}

# context_compact_threshold <window> [pct-override] [window-cap]
# Estimated token count at which Claude Code compacts on its own.
#
# This is an ESTIMATE, not a documented value: Claude Code publishes no
# threshold, so it is rebuilt from the public settings and from behaviour
# reported by others. Compaction is measured against the window minus a
# 20,000-token output reserve; with no override it fires 13,000 tokens before
# that (window - 33,000); CLAUDE_AUTOCOMPACT_PCT_OVERRIDE can only move it
# earlier; CLAUDE_CODE_AUTO_COMPACT_WINDOW caps the window first. Every figure
# the readout derives from it carries a `~` for that reason, and this one
# function is the only place to change if Claude Code changes.
context_compact_threshold() {
  local window="$1" pct="${2:-}" cap="${3:-0}"
  [[ "$window" =~ ^[0-9]+$ ]] || return 1
  if [[ "$cap" =~ ^[0-9]+$ && "$cap" -gt 0 && "$cap" -lt "$window" ]]; then
    window="$cap"
  fi
  local effective=$((window - 20000)) threshold=$((window - 33000))
  if [[ "$pct" =~ ^[0-9]+$ && "$pct" -ge 1 && "$pct" -le 100 ]]; then
    local by_pct=$((effective * pct / 100))
    [[ "$by_pct" -lt "$threshold" ]] && threshold="$by_pct"
  fi
  [[ "$threshold" -lt 0 ]] && threshold=0
  printf '%d' "$threshold"
}

# repeat_char <char> <count>
repeat_char() {
  local out="" i
  for ((i = 0; i < $2; i++)); do out+="$1"; done
  printf '%s' "$out"
}

# render_context_bar <used-pct> <trigger-pct> <window-used-tokens> <threshold-tokens>
render_context_bar() {
  local used_pct="$1" trigger_pct="$2" used_tok="$3" threshold="$4"
  local width="$CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH"
  [[ "$trigger_pct" -gt 100 ]] && trigger_pct=100

  local safe=$(((width * trigger_pct + 50) / 100)) danger
  danger=$((width - safe))
  local filled=$(((width * used_pct + 50) / 100))
  [[ "$filled" -gt "$width" ]] && filled="$width"

  local filled_safe="$filled" filled_danger=0
  [[ "$filled" -gt "$safe" ]] && { filled_safe="$safe"; filled_danger=$((filled - safe)); }
  local empty_safe=$((safe - filled_safe)) empty_danger=$((danger - filled_danger))

  # Colour tier: red once past the trigger, yellow within 15 points of it.
  local tone=dim
  if [[ "$used_tok" -ge "$threshold" ]]; then tone=red
  elif [[ "$used_pct" -ge $((trigger_pct - 15)) ]]; then tone=yellow
  fi

  printf '%s%s%s%s%s' \
    "$(sl_color "$tone" "$(repeat_char █ "$filled_safe")")" \
    "$(sl_color dim "$(repeat_char · "$empty_safe")")" \
    "$(sl_color "$tone" '|')" \
    "$(sl_color "$tone" "$(repeat_char █ "$filled_danger")")" \
    "$(sl_color dim "$(repeat_char ≈ "$empty_danger")")"
}

segment_context() {
  local payload_json="$1" used_pct used_tok window
  IFS=$'\x1f' read -r used_pct used_tok window <<<"$(printf '%s' "$payload_json" | jq -r '
    [ (.context_window.used_percentage // "" | if type == "number" then floor else . end),
      (.context_window.total_input_tokens // ""),
      (.context_window.context_window_size // "")
    ] | map(tostring) | join("\u001f")' 2>/dev/null)"
  [[ "$used_pct" =~ ^[0-9]+$ && "$window" =~ ^[0-9]+$ && "$window" -gt 0 ]] || return 0
  [[ "$used_tok" =~ ^[0-9]+$ ]] || used_tok=$((window * used_pct / 100))

  local threshold trigger_pct
  threshold="$(context_compact_threshold "$window" "${CLAUDE_AUTOCOMPACT_PCT_OVERRIDE:-}" \
    "${CLAUDE_CODE_AUTO_COMPACT_WINDOW:-0}")" || return 0
  trigger_pct=$((threshold * 100 / window))

  local remaining until_part
  remaining=$((threshold - used_tok))
  if [[ "$remaining" -le 0 ]]; then
    until_part="past compact"
  else
    until_part="~$(format_tokens "$remaining") until compact"
  fi

  printf '%s%s%s' \
    "$(sl_color dim 'ctx ▕')" \
    "$(render_context_bar "$used_pct" "$trigger_pct" "$used_tok" "$threshold")" \
    "$(sl_color dim "▏ $used_pct% · $(format_tokens "$used_tok")/$(format_tokens "$window") · $until_part")"
}
