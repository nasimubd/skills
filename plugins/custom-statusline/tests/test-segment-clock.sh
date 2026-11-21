#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1
source "$PLUGIN_ROOT/lib/segment-clock.sh"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $desc: expected '$expected', got '$actual'"
  fi
}

# 2026-11-11 18:05:00 UTC
export CUSTOM_STATUSLINE_NOW=1794420300
assert_eq "UTC and a named zone" "Wed 11 Nov 2026 18:05 UTC | 13:05 EST" \
  "$(CUSTOM_STATUSLINE_CLOCK_TZ=America/New_York segment_clock)"
assert_eq "a zone with a different offset" "Wed 11 Nov 2026 18:05 UTC | 02:05 +08" \
  "$(CUSTOM_STATUSLINE_CLOCK_TZ=Asia/Kuala_Lumpur segment_clock | sed 's/MYT/+08/')"
assert_eq "a UTC zone does not repeat itself" "Wed 11 Nov 2026 18:05 UTC" \
  "$(CUSTOM_STATUSLINE_CLOCK_TZ=UTC segment_clock)"
assert_eq "the system zone is used by default" "Wed 11 Nov 2026 18:05 UTC | 03:05 JST" \
  "$(TZ=Asia/Tokyo segment_clock)"
CUSTOM_STATUSLINE_NOW=junk
assert_eq "a bad clock value yields nothing" "" "$(segment_clock)"

echo "test-segment-clock.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
