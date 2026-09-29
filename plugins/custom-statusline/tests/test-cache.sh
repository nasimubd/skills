#!/usr/bin/env bash
# Regression tests for lib/cache.sh. Auto-discovered by
# test-marketplace-hook-regression-suite.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/cache.sh"

export CUSTOM_STATUSLINE_CACHE_DIR="$(mktemp -d)"
trap 'rm -rf "$CUSTOM_STATUSLINE_CACHE_DIR"' EXIT

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

# cache_set + cache_get within TTL returns the value.
cache_set "test/key" "hello"
assert_eq "fresh cache hit" "hello" "$(cache_get "test/key" 60)"

echo "test-cache.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
