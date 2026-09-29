#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/segment-model.sh"

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

assert_eq "1h boundary" "1h1m" "$(format_duration_ms 3660000)"
assert_eq "minutes only" "18m" "$(format_duration_ms 1106257)"
assert_eq "seconds only" "5s" "$(format_duration_ms 5000)"

echo "test-segment-model.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
