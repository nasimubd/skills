#!/usr/bin/env bash
# Regression tests for hooks/write-gate.sh. Auto-discovered by
# test-marketplace-hook-regression-suite.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/write-gate.sh"

PASS=0
FAIL=0

decision() {
  local out
  out="$(jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}' | bash "$HOOK")"
  if [[ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$out" 2>/dev/null)" == "deny" ]]; then
    echo deny
  else
    echo allow
  fi
}

expect() {
  local want="$1" desc="$2" cmd="$3" got
  got="$(decision "$cmd")"
  if [[ "$got" == "$want" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $desc: expected $want, got $got"
  fi
}

expect deny "delete a note" 'osascript -e '"'"'tell application "Notes" to delete note 1'"'"
expect deny "make a note" 'osascript -e '"'"'tell application "Notes" to make new note with properties {name:"x"}'"'"
expect deny "set a note body" 'osascript -e '"'"'tell application "Notes" to set body of note 1 to "x"'"'"
expect deny "complete a reminder" 'osascript -e '"'"'tell application "Reminders" to set completed of reminder 1 to true'"'"
expect deny "after a pipe" 'echo go | /usr/bin/osascript -e '"'"'tell application "Notes" to delete note 1'"'"
expect deny "escape reason too short" 'osascript -e '"'"'tell application "Notes" to delete note 1'"'"' # NOTES-WRITE-OK: yes'
expect allow "escape with a real reason" 'osascript -e '"'"'tell application "Notes" to delete note 1'"'"' # NOTES-WRITE-OK: user asked to remove the duplicate draft'
expect allow "read the count of notes" 'osascript -e '"'"'tell application "Notes" to count of notes'"'"
expect allow "show a note" 'osascript -e '"'"'tell application "Notes" to show note 1'"'"
expect allow "osascript on another app" 'osascript -e '"'"'tell application "Finder" to delete file 1'"'"
expect allow "the sanctioned command" 'notes-commander create --title "x" --confirm'
expect allow "no osascript at all" 'ls -la'
expect allow "grep for the words" 'grep -r "delete note" docs/'

echo "$PASS passed, $FAIL failed"
[[ "$FAIL" == 0 ]]
