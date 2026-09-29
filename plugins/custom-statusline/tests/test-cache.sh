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

# A TTL of 0 means "always stale" — cache_get must miss even right after set.
cache_set "test/expired" "stale-value"
if cache_get "test/expired" 0 >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  echo "  ✗ ttl-0 should always miss, but cache_get succeeded"
else
  PASS=$((PASS + 1))
fi

# A missing key is a miss, not an error that aborts the script.
if cache_get "test/never-set" 60 >/dev/null 2>&1; then
  FAIL=$((FAIL + 1))
  echo "  ✗ missing key should miss, but cache_get succeeded"
else
  PASS=$((PASS + 1))
fi

# cache_fetch runs the command on a miss and caches stdout.
assert_eq "cache_fetch miss runs command" "computed" "$(cache_fetch "test/fetch" 60 echo computed)"
assert_eq "cache_fetch hit serves cache, not the command" "computed" "$(cache_fetch "test/fetch" 60 echo different)"

echo "test-cache.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
