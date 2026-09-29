#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/segment-package.sh"

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

assert_eq "in-sync when versions match" "in-sync" \
  "$(compare_release_to_manifest "v1.0.0" "1.0.0")"

assert_eq "ahead when manifest is newer" "ahead" \
  "$(compare_release_to_manifest "v1.0.0" "1.1.0")"
assert_eq "behind when release is newer" "behind" \
  "$(compare_release_to_manifest "v1.1.0" "1.0.0")"

echo "test-segment-package.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
