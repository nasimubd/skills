#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1
source "$PLUGIN_ROOT/lib/segment-session.sh"

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

# Built with printf: a comma inside braces in a quoted $(...) is mangled by bash 3.2.
HOME_PAYLOAD="$(printf '{"session_id":"abc-123","transcript_path":"%s/.claude/projects/-Users-x-repo/abc-123.jsonl"}' "$HOME")"
assert_eq "folder is taken from the transcript path" "~/.claude/projects JSONL ID: abc-123" \
  "$(segment_session "$HOME_PAYLOAD")"
assert_eq "a relocated config directory is shown as is" "/data/cfg/projects JSONL ID: s1" \
  "$(segment_session '{"session_id":"s1","transcript_path":"/data/cfg/projects/-p/s1.jsonl"}')"
assert_eq "no transcript path falls back to the default folder" "~/.claude/projects JSONL ID: s1" \
  "$(segment_session '{"session_id":"s1"}')"
assert_eq "no session id yields nothing" "" "$(segment_session '{}')"

echo "test-segment-session.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
