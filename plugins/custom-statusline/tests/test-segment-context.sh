#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/segment-context.sh"

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

assert_eq "0% is fully empty bar" "░░░░░░░░░░" "$(render_usage_bar 0 10)"
assert_eq "100% is fully filled bar" "██████████" "$(render_usage_bar 100 10)"

assert_eq "full segment renders bar + percent" "██░░░░░░░░ 21%" \
  "$(segment_context '{"context_window":{"used_percentage":21}}')"
assert_eq "missing context_window yields empty" "" \
  "$(segment_context '{}')"

echo "test-segment-context.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
