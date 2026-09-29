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

assert_eq "cost formats to 2 decimals" "\$1.89" "$(format_cost_usd "1.8851941000000003")"
assert_eq "malformed cost degrades to zero" "\$0.00" "$(format_cost_usd "not-a-number")"

FULL_PAYLOAD='{"model":{"display_name":"Sonnet 5"},"cost":{"total_cost_usd":1.885,"total_duration_ms":1106257,"total_lines_added":12,"total_lines_removed":3}}'
assert_eq "full segment with lines changed" "Sonnet 5 18m \$1.89 +12/-3" "$(segment_model "$FULL_PAYLOAD")"

NO_LINES_PAYLOAD='{"model":{"display_name":"Sonnet 5"},"cost":{"total_cost_usd":0,"total_duration_ms":5000}}'
assert_eq "no lines-changed segment omits that piece" "Sonnet 5 5s \$0.00" "$(segment_model "$NO_LINES_PAYLOAD")"

assert_eq "missing model yields empty" "" "$(segment_model '{}')"

echo "test-segment-model.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
