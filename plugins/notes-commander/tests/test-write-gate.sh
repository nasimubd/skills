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

# ---- review fix: the ways the first version let a write through ------------
expect deny "JXA property assignment" 'osascript -l JavaScript -e '"'"'Application("Notes").notes[0].body = "x"'"'"
expect deny "JXA delete call" 'osascript -l JavaScript -e '"'"'Application("Notes").notes[0].delete()'"'"
expect deny "move with a parenthesis after the verb" 'osascript -e '"'"'tell application "Notes" to move (note 1) to folder "A"'"'"
expect deny "set the text of a note" 'osascript -e '"'"'tell application "Notes" to set the text of note 1 to "x"'"'"
expect deny "set the container of a note" 'osascript -e '"'"'tell application "Notes" to set container of note 1 to folder "A"'"'"
expect deny "set a reminder due date" 'osascript -e '"'"'tell application "Reminders" to set due date of reminder 1 to (current date)'"'"
expect deny "heredoc script" $'osascript <<EOF\ntell application "Notes" to delete note 1\nEOF'
SCRIPT_FILE="$(mktemp -t notesgate).applescript"
printf 'tell application "Notes" to delete note 1\n' >"$SCRIPT_FILE"
expect deny "a script file that deletes a note" "osascript $SCRIPT_FILE"
printf 'tell application "Finder" to delete file 1\n' >"$SCRIPT_FILE"
expect allow "a script file aimed at another app" "osascript $SCRIPT_FILE"
printf 'tell application "Notes" to count of notes\n' >"$SCRIPT_FILE"
expect allow "a read-only script file" "osascript $SCRIPT_FILE"
rm -f "$SCRIPT_FILE"
expect allow "read a note name" 'osascript -e '"'"'tell application "Notes" to get name of note 1'"'"
expect allow "read with a local variable" 'osascript -e '"'"'tell application "Notes" to set n to count of notes'"'"

echo "$PASS passed, $FAIL failed"
[[ "$FAIL" == 0 ]]
