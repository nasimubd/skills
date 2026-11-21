#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
export HOME="$SCRATCH/home"
mkdir -p "$HOME/.local/bin" "$SCRATCH/work/proj"
export CUSTOM_STATUSLINE_CACHE_DIR="$SCRATCH/cache"
export CUSTOM_STATUSLINE_DIRECTORY_MAX_CHARS=300   # scratch paths are long; truncation has its own test
printf '#!/bin/sh\necho private\n' >"$HOME/.local/bin/gh"
chmod +x "$HOME/.local/bin/gh"

source "$PLUGIN_ROOT/lib/segment-remote.sh"

PASS=0
FAIL=0
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then PASS=$((PASS + 1)); else
    FAIL=$((FAIL + 1)); echo "  ✗ $desc: expected '$expected', got '$actual'"; fi
}

assert_eq "ssh remote" "github.com acme widget" "$(parse_remote_url git@github.com:acme/widget.git)"
assert_eq "https remote" "github.com acme widget" "$(parse_remote_url https://github.com/acme/widget.git)"
assert_eq "https remote with credentials" "github.com acme widget" \
  "$(parse_remote_url https://user@github.com/acme/widget)"
assert_eq "ssh:// remote" "git.example.com team repo" "$(parse_remote_url ssh://git@git.example.com/team/repo.git)"
assert_eq "not a remote" "" "$(parse_remote_url /local/path)"

P="$(printf '{"cwd":"%s/work/proj","workspace":{"repo":{"host":"github.com","owner":"acme","name":"widget"}}}' "$SCRATCH")"
assert_eq "directory, URL and visibility from the payload" \
  "$SCRATCH/work/proj | https://github.com/acme/widget [private]" "$(segment_remote "$P")"

# Without gh the badge is left out; there is no error text in its place.
rm -f "$HOME/.local/bin/gh"
rm -rf "$CUSTOM_STATUSLINE_CACHE_DIR"
assert_eq "no gh: no badge and no error text" \
  "$SCRATCH/work/proj | https://github.com/acme/widget" "$(segment_remote "$P")"

# A non-GitHub host never calls gh.
P2="$(printf '{"cwd":"%s/work/proj","workspace":{"repo":{"host":"git.example.com","owner":"t","name":"r"}}}' "$SCRATCH")"
assert_eq "other host: URL only" "$SCRATCH/work/proj | https://git.example.com/t/r" "$(segment_remote "$P2")"

# The origin URL is the fallback when the payload carries no repo.
git init -q -b main "$SCRATCH/work/proj"
git -C "$SCRATCH/work/proj" remote add origin git@github.com:acme/widget.git
assert_eq "origin URL fallback" "$SCRATCH/work/proj | https://github.com/acme/widget" \
  "$(segment_remote "$(printf '{"cwd":"%s/work/proj"}' "$SCRATCH")")"

# Off the default branch the URL names the branch; detached HEAD and other hosts do not.
git -C "$SCRATCH/work/proj" checkout -q -b feat/thing
assert_eq "feature branch is in the URL" "$SCRATCH/work/proj | https://github.com/acme/widget/tree/feat/thing" \
  "$(segment_remote "$(printf '{"cwd":"%s/work/proj"}' "$SCRATCH")")"
git -C "$SCRATCH/work/proj" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m x
git -C "$SCRATCH/work/proj" checkout -q --detach
assert_eq "detached HEAD adds no branch" "$SCRATCH/work/proj | https://github.com/acme/widget" \
  "$(segment_remote "$(printf '{"cwd":"%s/work/proj"}' "$SCRATCH")")"

# Outside a repository only the directory is shown.
assert_eq "no repository: directory only" "$SCRATCH/work" "$(segment_remote "$(printf '{"cwd":"%s/work"}' "$SCRATCH")")"
assert_eq "no directory yields nothing" "" "$(segment_remote '{}')"

echo "test-segment-remote.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
