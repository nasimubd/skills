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

echo "test-statusline-integration.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
