#!/usr/bin/env bash
# Regression tests for hooks/evidence-gate.sh. Auto-discovered by
# test-marketplace-hook-regression-suite.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/evidence-gate.sh"

PASS=0
FAIL=0

# Prints "deny" or "allow" for a Bash command as the hook would see it.
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

expect deny "raw open of a chat link" \
  'open "https://teams.microsoft.com/l/chat/0/0?users=a@b.com&message=hi"'
expect deny "msteams scheme" 'open "msteams:/l/chat/0/0?users=a@b.com&message=hi"'
expect deny "launcher after a pipe" 'echo x | /usr/bin/open "https://teams.microsoft.com/l/chat/0/0?users=a@b.com"'
expect deny "osascript launcher" 'osascript -e "open location \"https://teams.microsoft.com/l/chat/0/0\""'
expect deny "python webbrowser" 'python3 -c "import webbrowser; webbrowser.open(\"https://teams.microsoft.com/l/chat/0/0\")"'
expect deny "placeholder escape reason is not an escape" \
  'open "https://teams.microsoft.com/l/chat/0/0" # TEAMS-SEND-OK: <reason>'
expect deny "short escape reason is not an escape" \
  'open "https://teams.microsoft.com/l/chat/0/0" # TEAMS-SEND-OK: ok'
expect allow "escape with a real reason" \
  'open "https://teams.microsoft.com/l/chat/0/0" # TEAMS-SEND-OK: user asked to bypass for this greeting'
expect allow "the gated launcher" 'teams-commander open d1 jona'
expect allow "the gated launcher by path" 'bash "$ROOT/scripts/teams.sh" open d1 jona'
expect allow "searching for the URL" 'grep -rn "teams.microsoft.com/l/chat" plugins/'
expect allow "a word containing open" 'echo opened teams.microsoft.com/l/chat'
expect allow "unrelated command" 'ls -la'
expect allow "opening another URL" 'open https://example.com'

# Fail-open: garbage input must not block Bash.
out="$(printf 'not json' | bash "$HOOK")"
if [[ -z "$out" ]]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "  ✗ invalid input should allow"; fi

echo "test-evidence-gate.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
