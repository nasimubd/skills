#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1
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

REPO="$(mktemp -d)"
UPSTREAM="$(mktemp -d)"
NON_GIT="$(mktemp -d)"
trap 'rm -rf "$REPO" "$UPSTREAM" "$NON_GIT"' EXIT
git init -q -b main "$REPO"
git -C "$REPO" config user.name t
git -C "$REPO" config user.email t@example.com
git -C "$REPO" commit -q --allow-empty -m init

assert_eq "clean repo: every indicator is zero, no upstream arrows" \
  "M:0 D:0 S:0 U:0 ≡:0 ⚠:0" "$(segment_git "{\"cwd\":\"$REPO\"}")"
assert_eq "clean repo counts" "0 0 0 0 0" "$(git_dirty_counts "$REPO")"

printf 'a\n' >"$REPO/tracked.txt"; printf 'b\n' >"$REPO/gone.txt"
git -C "$REPO" add . && git -C "$REPO" commit -q -m files
printf 'more\n' >>"$REPO/tracked.txt"          # modified
rm "$REPO/gone.txt"                              # deleted
printf 'c\n' >"$REPO/staged.txt" && git -C "$REPO" add staged.txt   # staged
printf 'd\n' >"$REPO/new.txt"                   # untracked
assert_eq "one of each, counted separately" "1 1 1 1 0" "$(git_dirty_counts "$REPO")"
assert_eq "dirty repo segment" "M:1 D:1 S:1 U:1 ≡:0 ⚠:0" "$(segment_git "{\"cwd\":\"$REPO\"}")"

git -C "$REPO" stash -q -u
assert_eq "a stash is counted" "1" "$(git_stash_count "$REPO")"

# Ahead and behind appear only once an upstream exists.
git init -q --bare -b main "$UPSTREAM"
git -C "$REPO" remote add origin "$UPSTREAM"
git -C "$REPO" push -q -u origin main
git -C "$REPO" commit -q --allow-empty -m local
assert_eq "one commit ahead of upstream" "1 0" "$(git_ahead_behind "$REPO")"
assert_eq "arrows render with an upstream" "M:0 D:0 S:0 U:0 ↑:1 ↓:0 ≡:1 ⚠:0" "$(segment_git "{\"cwd\":\"$REPO\"}")"

# A merge conflict is counted as a conflict, not as a modification.
git -C "$REPO" checkout -q -b other
printf 'x\n' >"$REPO/tracked.txt"; git -C "$REPO" commit -q -am other
git -C "$REPO" checkout -q main
printf 'y\n' >"$REPO/tracked.txt"; git -C "$REPO" commit -q -am main-side
git -C "$REPO" merge -q other >/dev/null 2>&1 || true
assert_eq "conflict counted once" "0 0 0 0 1" "$(git_dirty_counts "$REPO")"

assert_eq "non-git directory yields nothing" "" "$(segment_git "{\"cwd\":\"$NON_GIT\"}")"

echo "test-segment-git.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
