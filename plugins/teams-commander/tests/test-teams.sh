#!/usr/bin/env bash
# Regression tests for scripts/teams.sh. Auto-discovered by
# test-marketplace-hook-regression-suite. `open` and `pbcopy` are replaced by
# stubs on PATH, so nothing reaches Teams or the real clipboard.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEAMS="$PLUGIN_ROOT/scripts/teams.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export TEAMS_COMMANDER_STATE_DIR="$WORK/state"
export TEAMS_COMMANDER_CONFIG_DIR="$WORK/config"
mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\necho "$1" >"%s/opened"\n' "$WORK" >"$WORK/bin/open"
printf '#!/usr/bin/env bash\ncat >"%s/clipboard"\n' "$WORK" >"$WORK/bin/pbcopy"
chmod +x "$WORK/bin/open" "$WORK/bin/pbcopy"
export PATH="$WORK/bin:$PATH"

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

# Exit status of a command, without tripping set -e.
status_of() { local s=0; "$@" >/dev/null 2>&1 || s=$?; echo "$s"; }

bash "$TEAMS" contact add jona jona@example.com --name "Jona" >/dev/null
assert_eq "new draft prints its id" "d1" "$(bash "$TEAMS" new d1)"
assert_eq "duplicate draft id is refused" "1" "$(status_of bash "$TEAMS" new d1)"
assert_eq "bad draft id is a usage error" "2" "$(status_of bash "$TEAMS" new 'a/b')"

printf 'Hi Jona, the 12:00 run processed 17,291 matters.\nOK to close the task?\n' | bash "$TEAMS" message d1 - >/dev/null

# A message with no claims cannot pass: there is nothing showing it was checked.
assert_eq "verify refuses a draft with no claims" "3" "$(status_of bash "$TEAMS" verify d1)"

# A fact without evidence is recorded but unverified, and blocks verify.
assert_eq "fact without evidence gets an id" "C1" \
  "$(bash "$TEAMS" claim d1 --text "12:00 run processed 17,291 matters" --kind fact)"
assert_eq "unverified fact blocks verify" "3" "$(status_of bash "$TEAMS" verify d1)"
assert_eq "show reports the unverified claim" "1" \
  "$(bash "$TEAMS" show d1 | grep -c '| C1 | unverified |')"

# Replace it with an evidenced fact, plus a question.
bash "$TEAMS" drop d1 C1 >/dev/null
bash "$TEAMS" claim d1 --text "12:00 run processed 17,291 matters" --kind fact \
  --source-type n8n-execution --source "exec 7203" --excerpt "matters: 17291, pages: 88" \
  --reproduce "n8n get execution 7203" >/dev/null
bash "$TEAMS" claim d1 --text "OK to close the task?" --kind question >/dev/null
assert_eq "evidenced draft verifies" "0" "$(status_of bash "$TEAMS" verify d1)"

# Credentials never enter the ledger.
assert_eq "bearer token in evidence is refused" "2" "$(status_of bash "$TEAMS" claim d1 \
  --text x --kind fact --source-type cmd --source y --excerpt "Authorization: Bearer abcdefghijklmnopqrstuvwxyz123")"
assert_eq "password in evidence is refused" "2" "$(status_of bash "$TEAMS" claim d1 \
  --text x --kind fact --source-type cmd --source y --excerpt "password=hunter2secret")"

# The link carries the encoded message and the contact.
link="$(bash "$TEAMS" link d1 jona)"
assert_eq "link targets the documented chat endpoint" "1" \
  "$(grep -c '^https://teams.microsoft.com/l/chat/0/0?users=jona%40example.com&message=Hi%20Jona%2C' <<<"$link")"
assert_eq "line break is percent-encoded" "1" "$(grep -c 'matters.%0AOK' <<<"$link")"
assert_eq "trailing newline is not sent" "0" "$(grep -c '%0A$' <<<"$link")"
assert_eq "unknown contact is refused" "1" "$(status_of bash "$TEAMS" link d1 nobody)"

# Editing the message after verify invalidates the verification.
printf 'Hi Jona, all 17,291 matters are fine.\n' | bash "$TEAMS" message d1 - >/dev/null
assert_eq "edited message must be verified again" "3" "$(status_of bash "$TEAMS" link d1 jona)"
bash "$TEAMS" verify d1 >/dev/null

# Dry run copies to the clipboard but opens nothing.
bash "$TEAMS" open d1 jona --dry-run >/dev/null
assert_eq "dry run fills the clipboard" "Hi Jona, all 17,291 matters are fine." "$(cat "$WORK/clipboard")"
assert_eq "dry run opens nothing" "no" "$([[ -f "$WORK/opened" ]] && echo yes || echo no)"

bash "$TEAMS" open d1 jona >/dev/null
assert_eq "open launches the verified link" "$(bash "$TEAMS" link d1 jona)" "$(cat "$WORK/opened")"
assert_eq "open is recorded in the ledger" "jona" \
  "$(jq -r '.opened[-1].contact' "$TEAMS_COMMANDER_STATE_DIR/drafts/d1/ledger.json")"

# Evidence older than the limit is stale and blocks the link.
jq '.claims[0].captured_at = "2020-01-01T00:00:00Z"' "$TEAMS_COMMANDER_STATE_DIR/drafts/d1/ledger.json" \
  >"$WORK/l.json" && mv "$WORK/l.json" "$TEAMS_COMMANDER_STATE_DIR/drafts/d1/ledger.json"
assert_eq "stale evidence blocks the link" "3" "$(status_of bash "$TEAMS" link d1 jona)"
assert_eq "stale evidence blocks verify" "3" "$(status_of bash "$TEAMS" verify d1)"
bash "$TEAMS" refresh d1 C2 --excerpt "matters: 17291, pages: 88 (re-read)" >/dev/null
assert_eq "refreshed evidence verifies again" "0" "$(status_of bash "$TEAMS" verify d1)"

# Opinions are allowed without evidence, and labelled as such.
bash "$TEAMS" claim d1 --text "Keep Beta separate" --kind opinion >/dev/null
assert_eq "opinion does not block verify" "0" "$(status_of bash "$TEAMS" verify d1)"

# A group contact carries every participant and the topic.
bash "$TEAMS" contact add ops a@example.com,b@example.com --topic "Ops review" >/dev/null
bash "$TEAMS" contact tenant 00000000-1111-2222-3333-444444444444 >/dev/null
link="$(bash "$TEAMS" link d1 ops)"
assert_eq "group link lists both users and the topic" "1" \
  "$(grep -c 'tenantId=00000000-1111-2222-3333-444444444444&users=a%40example.com,b%40example.com&topicName=Ops%20review&message=' <<<"$link")"
assert_eq "bad email is refused" "2" "$(status_of bash "$TEAMS" contact add x not-an-email)"

echo "test-teams.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
