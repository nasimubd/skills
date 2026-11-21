#!/usr/bin/env bash
# Clock segment: UTC date and time, then the local time.
#
#   Wed 11 Nov 2026 18:05 UTC | 13:05 EST
#
# The local zone is the system zone; CUSTOM_STATUSLINE_CLOCK_TZ names another
# (an IANA name such as Asia/Kuala_Lumpur). The second half is dropped when it
# would repeat the first, which is the case on a UTC machine. The line only
# refreshes when Claude Code redraws; set `refreshInterval` on the statusLine
# setting to keep the minute current while the session is idle.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./runtime.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/runtime.sh"

segment_clock() {
  local epoch="${CUSTOM_STATUSLINE_NOW:-$(date +%s)}" utc local_part zone
  [[ "$epoch" =~ ^[0-9]+$ ]] || return 0
  utc="$(TZ=UTC date -r "$epoch" '+%a %d %b %Y %H:%M UTC' 2>/dev/null \
    || TZ=UTC date -d "@$epoch" '+%a %d %b %Y %H:%M UTC' 2>/dev/null)" || return 0
  [[ -n "$utc" ]] || return 0

  zone="${CUSTOM_STATUSLINE_CLOCK_TZ:-}"
  if [[ -n "$zone" ]]; then
    local_part="$(TZ="$zone" date -r "$epoch" '+%H:%M %Z' 2>/dev/null \
      || TZ="$zone" date -d "@$epoch" '+%H:%M %Z' 2>/dev/null)"
  else
    local_part="$(date -r "$epoch" '+%H:%M %Z' 2>/dev/null || date -d "@$epoch" '+%H:%M %Z' 2>/dev/null)"
  fi

  local out="$utc"
  [[ -n "$local_part" && "$local_part" != *" UTC" && "$local_part" != *" GMT" ]] && out+=" | $local_part"
  sl_color dim "$out"
}
