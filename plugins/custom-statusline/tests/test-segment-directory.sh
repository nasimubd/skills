#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/segment-directory.sh"

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

assert_eq "home dir becomes ~" "~" \
  "$(segment_directory "{\"cwd\":\"$HOME\"}")"

assert_eq "subdirectory of home" "~/skills" \
  "$(segment_directory "{\"cwd\":\"$HOME/skills\"}")"

assert_eq "path outside home is untouched" "/tmp/foo" \
  "$(segment_directory '{"cwd":"/tmp/foo"}')"

LONG_SUBPATH="very/deeply/nested/project/directory/structure/goes/here"
assert_eq "long path is middle-truncated" "~/very/deeply/neste…structure/goes/here" \
  "$(segment_directory "{\"cwd\":\"$HOME/$LONG_SUBPATH\"}")"

echo "test-segment-directory.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
