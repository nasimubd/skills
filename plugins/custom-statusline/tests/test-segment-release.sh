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

assert_match() {
  local desc="$1" pattern="$2" actual="$3"
  if [[ "$actual" =~ $pattern ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $desc: '$actual' does not match /$pattern/"
  fi
}

assert_eq "missing repo info yields empty" "" "$(segment_release '{}')"

# This repo's own latest tag is a live value that changes on every release —
# asserting a frozen literal here breaks the instant a new release ships.
# The pattern proves the live fetch reached a real repo and returned a real
# semver tag, without freezing it to whichever tag happened to be latest
# when this test was written.
assert_match "real repo returns a semver tag" '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  "$(segment_release '{"workspace":{"repo":{"owner":"nasimubd","name":"skills"}}}')"

# A pre-seeded cache entry for a repo that cannot possibly exist proves the
# segment served the cache instead of attempting a live (and here, failing)
# fetch.
cache_set "nonexistent-owner-zzz/nonexistent-repo-zzz/release" "v9.9.9"
assert_eq "cache hit bypasses the live fetch" "v9.9.9" \
  "$(segment_release '{"workspace":{"repo":{"owner":"nonexistent-owner-zzz","name":"nonexistent-repo-zzz"}}}')"

echo "test-segment-release.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
