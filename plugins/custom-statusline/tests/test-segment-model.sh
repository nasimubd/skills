#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1
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

assert_eq "id, effort and thinking" "claude-sonnet-5-5 · high · thinking:true" \
  "$(segment_model '{"model":{"id":"claude-sonnet-5-5"},"effort":{"level":"high"},"thinking":{"enabled":true}}')"
assert_eq "thinking off is shown as false" "claude-sonnet-5-5 · thinking:false" \
  "$(segment_model '{"model":{"id":"claude-sonnet-5-5"},"thinking":{"enabled":false}}')"
assert_eq "absent fields are left out" "claude-sonnet-5-5" "$(segment_model '{"model":{"id":"claude-sonnet-5-5"}}')"
assert_eq "display name is the fallback" "Sonnet" "$(segment_model '{"model":{"display_name":"Sonnet"}}')"
assert_eq "no model yields nothing" "" "$(segment_model '{}')"
assert_eq "colour is applied when allowed" "1" \
  "$(NO_COLOR='' segment_model '{"model":{"id":"m"}}' | grep -c $'\033\[90m')"

echo "test-segment-model.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
