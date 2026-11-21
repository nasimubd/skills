#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1

# A scratch HOME with a stub gh in $HOME/.local/bin, which runtime.sh puts first
# on PATH: no network, and the real gh cannot answer instead.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
export HOME="$SCRATCH/home"
mkdir -p "$HOME/.local/bin"
export CUSTOM_STATUSLINE_CACHE_DIR="$SCRATCH/cache"
export GH_CALLS="$SCRATCH/gh-calls"
NOW="$(date +%s)"
PUBLISHED="$(TZ=UTC date -r $((NOW - 3 * 3600)) '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
  || date -u -d "@$((NOW - 3 * 3600))" '+%Y-%m-%dT%H:%M:%SZ')"
cat >"$HOME/.local/bin/gh" <<STUB
#!/bin/sh
echo "\$*" >>"$GH_CALLS"
case "\$*" in
  *releases/latest*tag_name,*) printf 'v9.9.9\t$PUBLISHED' ;;
  *releases/latest*) echo v9.9.9 ;;
  *) exit 1 ;;
esac
STUB
chmod +x "$HOME/.local/bin/gh"

source "$PLUGIN_ROOT/lib/segment-release.sh"

PASS=0
FAIL=0
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then PASS=$((PASS + 1)); else
    FAIL=$((FAIL + 1)); echo "  ✗ $desc: expected '$expected', got '$actual'"; fi
}

assert_eq "age: under a minute" "<1m" "$(format_age_seconds 30)"
assert_eq "age: minutes" "5m" "$(format_age_seconds 300)"
assert_eq "age: hours" "13h" "$(format_age_seconds 47000)"
assert_eq "age: days" "3d" "$(format_age_seconds 260000)"
assert_eq "age: weeks" "2w" "$(format_age_seconds 1300000)"
assert_eq "age: junk yields nothing" "" "$(format_age_seconds soon)"
assert_eq "iso to epoch" "1794420300" "$(iso_to_epoch 2026-11-11T18:05:00Z)"

# A GitHub release, with its age computed from the published time.
PAYLOAD='{"workspace":{"repo":{"owner":"acme","name":"widget"}}}'
assert_eq "release from GitHub with its age" "v9.9.9 tag 3h ago" "$(segment_release "$PAYLOAD")"

# The second render is served from the cache: gh is not called again.
CALLS_BEFORE="$(wc -l <"$GH_CALLS" | tr -d ' ')"
segment_release "$PAYLOAD" >/dev/null
assert_eq "second render uses the cache" "$CALLS_BEFORE" "$(wc -l <"$GH_CALLS" | tr -d ' ')"

# With no GitHub answer, the newest local tag stands in.
rm -f "$HOME/.local/bin/gh"
rm -rf "$CUSTOM_STATUSLINE_CACHE_DIR"
REPO="$SCRATCH/repo"
git init -q -b main "$REPO"
git -C "$REPO" config user.name t
git -C "$REPO" config user.email t@example.com
git -C "$REPO" commit -q --allow-empty -m init
git -C "$REPO" tag v1.2.0
git -C "$REPO" tag v1.10.0
assert_eq "local tag is chosen by version order, not text" "v1.10.0 tag <1m ago" \
  "$(segment_release "$(printf '{"cwd":"%s"}' "$REPO")")"
assert_eq "a repository with no tags yields nothing" "" \
  "$(segment_release "$(printf '{"cwd":"%s"}' "$SCRATCH")")"
assert_eq "no repository information yields nothing" "" "$(segment_release '{}')"

echo "test-segment-release.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
