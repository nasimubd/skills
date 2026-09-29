#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

assert_exit_zero() {
  local desc="$1" payload="$2"
  # `if pipeline; then` is exempt from set -e — the pipeline's failure is the
  # thing under test here, not a real script error.
  if printf '%s' "$payload" | bash "$PLUGIN_ROOT/scripts/statusline.sh" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $desc: exited non-zero, expected 0"
  fi
}

assert_exit_zero "empty payload" "{}"
assert_exit_zero "malformed payload" "not json"
assert_exit_zero "empty stdin" ""

FULL_PAYLOAD='{"session_id":"3e83be9e-2559-4c75-869f-a65a883d85d1","model":{"display_name":"Sonnet 5"},"context_window":{"used_percentage":42},"cost":{"total_cost_usd":1.5,"total_duration_ms":60000}}'
OUTPUT="$(printf '%s' "$FULL_PAYLOAD" | bash "$PLUGIN_ROOT/scripts/statusline.sh")"

if [[ "$OUTPUT" == *"3e83be9e"* ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ output missing session id: $OUTPUT"
fi

if [[ "$OUTPUT" == *"Sonnet 5"* ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ output missing model name: $OUTPUT"
fi

if [[ "$OUTPUT" == *"42%"* ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ output missing context percentage: $OUTPUT"
fi

echo "test-statusline-integration.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
