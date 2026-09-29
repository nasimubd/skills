#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/segment-session.sh"

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

assert_eq "id only" "3e83be9e" \
  "$(segment_session '{"session_id":"3e83be9e-2559-4c75-869f-a65a883d85d1"}')"

echo "test-segment-session.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
