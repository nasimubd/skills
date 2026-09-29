#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/segment-release.sh"

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

assert_eq "missing repo info yields empty" "" "$(segment_release '{}')"

assert_eq "real repo returns its published tag" "v1.0.0" \
  "$(segment_release '{"workspace":{"repo":{"owner":"nasimubd","name":"skills"}}}')"

# A pre-seeded cache entry for a repo that cannot possibly exist proves the
# segment served the cache instead of attempting a live (and here, failing)
# fetch.
cache_set "nonexistent-owner-zzz/nonexistent-repo-zzz/release" "v9.9.9"
assert_eq "cache hit bypasses the live fetch" "v9.9.9" \
  "$(segment_release '{"workspace":{"repo":{"owner":"nonexistent-owner-zzz","name":"nonexistent-repo-zzz"}}}')"

echo "test-segment-release.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
