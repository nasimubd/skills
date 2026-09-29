#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/segment-git.sh"

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

SCRATCH_REPO="$(mktemp -d)"
git init -q -b main "$SCRATCH_REPO"
git -C "$SCRATCH_REPO" commit -q --allow-empty -m init
trap 'rm -rf "$SCRATCH_REPO"' EXIT

assert_eq "clean repo, branch only" "main" "$(git_current_branch "$SCRATCH_REPO")"
assert_eq "clean repo, no dirty state" "0 0 0" "$(git_dirty_counts "$SCRATCH_REPO")"

echo "b" >"$SCRATCH_REPO/tracked.txt"
git -C "$SCRATCH_REPO" add tracked.txt
git -C "$SCRATCH_REPO" commit -q -m "add tracked"
echo "c" >>"$SCRATCH_REPO/tracked.txt"
echo "d" >"$SCRATCH_REPO/staged.txt"
git -C "$SCRATCH_REPO" add staged.txt
echo "e" >"$SCRATCH_REPO/untracked.txt"

assert_eq "dirty repo counts" "1 1 1" "$(git_dirty_counts "$SCRATCH_REPO")"
assert_eq "dirty repo full segment" "main +1~1?1" "$(segment_git "{\"cwd\":\"$SCRATCH_REPO\"}")"

assert_eq "no upstream configured" "0 0" "$(git_ahead_behind "$SCRATCH_REPO")"

NON_GIT_DIR="$(mktemp -d)"
trap 'rm -rf "$SCRATCH_REPO" "$NON_GIT_DIR"' EXIT
assert_eq "non-git dir yields empty segment" "" "$(segment_git "{\"cwd\":\"$NON_GIT_DIR\"}")"

echo "test-segment-git.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
