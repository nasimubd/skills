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

echo "test-segment-git.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
