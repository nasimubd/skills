#!/usr/bin/env bash
# End-to-end: the entrypoint, run the way Claude Code runs it: under macOS's
# stock /bin/bash (3.2) when it exists, with a minimal environment.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/statusline.sh"
RUNNER=bash
[[ -x /bin/bash ]] && RUNNER=/bin/bash

SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
HOME_DIR="$SCRATCH/home"
REPO="$SCRATCH/repo"
mkdir -p "$HOME_DIR/.local/bin" "$REPO"
# A stub gh in $HOME/.local/bin, one of the directories the script adds to PATH.
printf '#!/bin/sh\ncase "$*" in *releases/latest*) exit 1 ;; *) echo public ;; esac\n' >"$HOME_DIR/.local/bin/gh"
chmod +x "$HOME_DIR/.local/bin/gh"
git init -q -b main "$REPO"
git -C "$REPO" config user.name t
git -C "$REPO" config user.email t@example.com
git -C "$REPO" commit -q --allow-empty -m init
git -C "$REPO" tag v1.2.3
git -C "$REPO" remote add origin https://github.com/example/repo.git

PASS=0
FAIL=0
assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then PASS=$((PASS + 1)); else
    FAIL=$((FAIL + 1)); echo "  ✗ $desc: expected '$expected', got '$actual'"; fi
}
assert_match() {
  local desc="$1" pattern="$2" actual="$3"
  if [[ "$actual" =~ $pattern ]]; then PASS=$((PASS + 1)); else
    FAIL=$((FAIL + 1)); echo "  ✗ $desc: '$actual' does not match /$pattern/"; fi
}

# Run the entrypoint in $REPO with a minimal PATH and the scratch HOME.
run() {
  (cd "$REPO" && printf '%s' "$1" |
    env -i HOME="$HOME_DIR" PATH="/usr/bin:/bin" CUSTOM_STATUSLINE_CACHE_DIR="$SCRATCH/cache" \
      CUSTOM_STATUSLINE_CLOCK_TZ=America/New_York "${@:2}" "$RUNNER" "$SCRIPT")
}
status_of() { local s=0; "$@" >/dev/null 2>&1 || s=$?; echo "$s"; }

# Never fails the status line, whatever it is given.
assert_eq "empty object exits 0" "0" "$(status_of run '{}')"
assert_eq "malformed payload exits 0" "0" "$(status_of run 'not json')"
assert_eq "empty stdin exits 0" "0" "$(status_of run '')"
assert_eq "malformed payload leaks no jq error" "0" "$(run 'not json' NO_COLOR=1 2>&1 | grep -c 'parse error' || true)"

PAYLOAD="$(printf '{"model":{"id":"claude-sonnet-5-5"},"effort":{"level":"high"},"thinking":{"enabled":true},"session_id":"abc-123","transcript_path":"%s/.claude/projects/-p/abc-123.jsonl","cwd":"%s","workspace":{"current_dir":"%s","repo":{"host":"github.com","owner":"example","name":"repo"}},"context_window":{"used_percentage":30,"total_input_tokens":60000,"context_window_size":200000}}' "$HOME_DIR" "$REPO" "$REPO")"
OUT="$(run "$PAYLOAD" NO_COLOR=1 CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=73)"

assert_eq "six lines" "6" "$(printf '%s\n' "$OUT" | wc -l | tr -d ' ')"
assert_match "line 1: git indicators, then the local tag" '^M:0 D:0 S:0 U:0 ≡:0 ⚠:0 \| v1\.2\.3 tag <1m ago$' "$(printf '%s\n' "$OUT" | sed -n 1p)"
assert_eq "line 2: model, effort, thinking" "claude-sonnet-5-5 · high · thinking:true" "$(printf '%s\n' "$OUT" | sed -n 2p)"
assert_eq "line 3: context bar with the compaction estimate" \
  "ctx ▕██████·······|≈≈≈≈≈≈≈▏ 30% · 60k/200k · ~71k until compact" "$(printf '%s\n' "$OUT" | sed -n 3p)"
assert_match "line 4: UTC then New York time" '^[A-Z][a-z]{2} [0-9]{2} [A-Z][a-z]{2} [0-9]{4} [0-9]{2}:[0-9]{2} UTC \| [0-9]{2}:[0-9]{2} E[SD]T$' "$(printf '%s\n' "$OUT" | sed -n 4p)"
assert_match "line 5: directory, URL and the visibility badge" 'repo \| https://github\.com/example/repo \[public\]$' "$(printf '%s\n' "$OUT" | sed -n 5p)"
assert_eq "line 6: transcript folder and session id" "~/.claude/projects JSONL ID: abc-123" "$(printf '%s\n' "$OUT" | sed -n 6p)"

# The visibility badge needs gh, which is not on the minimal PATH: the PATH
# block must find it. (This once regressed: a rewrite dropped the block and the
# release tag, which comes from git, kept the old test green.)
assert_match "gh is found under a minimal PATH" '\[public\]' "$OUT"

# Colour: on by default, off with NO_COLOR.
assert_match "colour by default" '^[1-9]' "$(run "$PAYLOAD" | grep -c $'\033\\[' || true)"
assert_eq "NO_COLOR removes every escape" "0" "$(run "$PAYLOAD" NO_COLOR=1 | grep -c $'\033' || true)"

# Optional network lines are off by default and harmless when on.
assert_eq "extras are off by default" "6" "$(run "$PAYLOAD" NO_COLOR=1 | wc -l | tr -d ' ')"
assert_eq "extras never break the line" "0" "$(status_of run "$PAYLOAD" CUSTOM_STATUSLINE_EXTRAS=deployment,package)"

# Outside a repository the git and remote parts disappear quietly.
NOREPO="$(mktemp -d)"
NO_OUT="$(cd "$NOREPO" && printf '{"model":{"id":"m"},"cwd":"%s"}' "$NOREPO" |
  env -i HOME="$HOME_DIR" PATH="/usr/bin:/bin" NO_COLOR=1 "$RUNNER" "$SCRIPT")"
rm -rf "$NOREPO"
assert_eq "no repository: no git noise" "0" "$(printf '%s\n' "$NO_OUT" | grep -c 'not a git repository\|fatal' || true)"
assert_eq "no repository: the model line is still there" "1" "$(printf '%s\n' "$NO_OUT" | grep -c '^m$' || true)"

echo "test-statusline-integration.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
