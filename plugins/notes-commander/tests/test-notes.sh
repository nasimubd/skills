#!/usr/bin/env bash
# Regression tests for scripts/notes.sh. Auto-discovered by
# test-marketplace-hook-regression-suite. `osascript` is replaced by a stub on PATH that
# records what it was given, so nothing touches the real Notes or Reminders.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NOTES="$PLUGIN_ROOT/scripts/notes.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export NOTES_COMMANDER_CONFIG_DIR="$WORK/config"
export NOTES_COMMANDER_STATE_DIR="$WORK/state"
mkdir -p "$WORK/bin"
cat >"$WORK/bin/osascript" <<STUB
#!/usr/bin/env bash
# Records the script (stdin) and each argument; replies with the contents of \$REPLY_FILE.
cat >"$WORK/last.scpt"
shift  # the "-" that means: read the script from stdin
: >"$WORK/last.args"
for a in "\$@"; do printf '%s\n' "\$a" >>"$WORK/last.args"; done
echo x >>"$WORK/calls"
n=\$(wc -l <"$WORK/calls" | tr -d ' ')
if [[ -f "$WORK/replies/\$n" ]]; then cat "$WORK/replies/\$n"
elif [[ -f "$WORK/reply" ]]; then cat "$WORK/reply"; fi
if [[ -f "$WORK/sleep" ]]; then exec sleep "\$(cat "$WORK/sleep")"; fi
STUB
chmod +x "$WORK/bin/osascript"
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
assert_contains() {
  local desc="$1" needle="$2" hay="$3"
  if [[ "$hay" == *"$needle"* ]]; then PASS=$((PASS + 1)); else
    FAIL=$((FAIL + 1)); echo "  ✗ $desc: '$needle' not in '$hay'"; fi
}
status_of() { local s=0; "$@" >/dev/null 2>&1 || s=$?; echo "$s"; }
calls() { if [[ -f "$WORK/calls" ]]; then wc -l <"$WORK/calls" | tr -d ' '; else echo 0; fi; }
reset() { rm -rf "$WORK/calls" "$WORK/reply" "$WORK/replies" "$WORK/sleep" "$WORK/last.args" "$WORK/last.scpt" "$NOTES_COMMANDER_STATE_DIR/audit.log" "$NOTES_COMMANDER_STATE_DIR/journal" "$NOTES_COMMANDER_STATE_DIR/lock"; mkdir -p "$WORK/replies"; }

# ---- usage -----------------------------------------------------------------
assert_eq "no command is a usage error" "2" "$(status_of bash "$NOTES")"
assert_eq "unknown flag is a usage error" "2" "$(status_of bash "$NOTES" find x --nope)"
assert_eq "find without a term is a usage error" "2" "$(status_of bash "$NOTES" find)"

# ---- the write gate: no --confirm, no change -------------------------------
reset
assert_eq "create without --confirm is refused" "3" "$(status_of bash "$NOTES" create --title "Plan")"
assert_eq "append without --confirm is refused" "3" "$(status_of bash "$NOTES" append --id x-coredata://AAAA-1111/ICNote/p3 --text hi)"
assert_eq "task done without --confirm is refused" "3" "$(status_of bash "$NOTES" task done --id r1)"
assert_eq "task add (reminders) without --confirm is refused" "3" \
  "$(status_of bash "$NOTES" task add --title Call --in reminders)"
assert_eq "refused writes never reached osascript" "0" "$(calls)"
assert_contains "refusal says what would happen" "WOULD: create a note titled 'Plan'" \
  "$(bash "$NOTES" create --title Plan 2>/dev/null || true)"

# ---- create: arguments are passed as argv, never spliced into the script ---
reset
echo "x-coredata://AAAA-1111/ICNote/p77" >"$WORK/reply"
out="$(bash "$NOTES" create --title 'Q3 "plan" & <ideas>' --text 'line one' --confirm)"
assert_contains "create reports the new id" "x-coredata://AAAA-1111/ICNote/p77" "$out"
assert_eq "create made one osascript call" "1" "$(calls)"
assert_contains "html escapes the title" '<h1>Q3 "plan" &amp; &lt;ideas&gt;</h1>' "$(cat "$WORK/last.args")"
assert_contains "body lines become divs" '<div>line one</div>' "$(cat "$WORK/last.args")"
if grep -q 'Q3' "$WORK/last.scpt"; then
  FAIL=$((FAIL + 1)); echo "  ✗ the title leaked into the script text"
else PASS=$((PASS + 1)); fi
assert_contains "the write is audited" "created note x-coredata://AAAA-1111/ICNote/p77" "$(cat "$NOTES_COMMANDER_STATE_DIR/audit.log")"
if grep -q 'line one' "$NOTES_COMMANDER_STATE_DIR/audit.log"; then
  FAIL=$((FAIL + 1)); echo "  ✗ note text leaked into the audit log"
else PASS=$((PASS + 1)); fi

# ---- open / show resolve a title honestly ----------------------------------
reset
printf 'x-coredata://AAAA-1111/ICNote/p1\tWork\tPlan\n' >"$WORK/reply"
assert_eq "open of a unique title succeeds" "0" "$(status_of bash "$NOTES" open Plan)"
reset
printf 'x-coredata://AAAA-1111/ICNote/p1\tWork\tPlan\nx-coredata://AAAA-1111/ICNote/p2\tHome\tPlan\n' >"$WORK/reply"
assert_eq "an ambiguous title is refused, not guessed" "1" "$(status_of bash "$NOTES" show Plan)"
assert_contains "ambiguity lists both ids" "x-coredata://AAAA-1111/ICNote/p2" "$(bash "$NOTES" show Plan 2>&1 || true)"
reset
: >"$WORK/reply"
assert_eq "a missing note exits 1" "1" "$(status_of bash "$NOTES" open Ghost)"
assert_contains "a missing note says what was examined" "no note titled 'Ghost'" \
  "$(bash "$NOTES" open Ghost 2>&1 || true)"
reset
printf 'Recently Deleted\t3\n' >"$WORK/reply"
printf 'x-coredata://AAAA-1111/ICNote/p5\tRecently Deleted\tOld\n' >"$WORK/reply"
assert_eq "notes in Recently Deleted are ignored" "1" "$(status_of bash "$NOTES" open Old)"

# ---- find ------------------------------------------------------------------
reset
printf 'x-coredata://AAAA-1111/ICNote/p1\tWork\tLead list\n' >"$WORK/reply"
out="$(bash "$NOTES" find lead)"
assert_contains "find prints what it examined" "Examined: Notes" "$out"
assert_contains "find lists a match with its folder" "Lead list  [Work]" "$out"
reset
: >"$WORK/reply"
out="$(bash "$NOTES" find nothing)"
assert_contains "find says when nothing matches" "Nothing matches 'nothing'" "$out"
assert_contains "find then lists what exists" "Notes folders:" "$out"

# ---- the task home preference ----------------------------------------------
reset
assert_eq "default preference is ask" "task-home: ask" "$(bash "$NOTES" pref show)"
assert_eq "a task with no home is refused with ASK" "3" \
  "$(status_of bash "$NOTES" task add --title Call --confirm)"
assert_contains "the refusal tells the agent to ask" "ASK: where should this task live" \
  "$(bash "$NOTES" task add --title Call --confirm 2>&1 || true)"
assert_eq "asking made no osascript call" "0" "$(calls)"
assert_eq "bad preference is a usage error" "2" "$(status_of bash "$NOTES" pref set task-home maybe)"
bash "$NOTES" pref set task-home reminders >/dev/null
assert_eq "preference persists" "task-home: reminders" "$(bash "$NOTES" pref show)"
bash "$NOTES" pref set task-home ask >/dev/null

# ---- tasks in Reminders ----------------------------------------------------
reset
echo "x-apple-reminder://r1" >"$WORK/reply"
out="$(bash "$NOTES" task add --title 'Call Jona' --in reminders --due '2026-12-01 14:30' --confirm)"
assert_contains "reminder created" "Created reminder 'Call Jona'" "$out"
assert_eq "due date is split into argv parts" "Call Jona||2026|12|1|14|30" "$(paste -sd'|' "$WORK/last.args")"
reset
bash "$NOTES" task add --title Soon --in reminders --due 2026-12-01 --confirm >/dev/null
assert_eq "due time defaults to 09:00" "Soon||2026|12|1|9|0" "$(paste -sd'|' "$WORK/last.args")"
assert_eq "bad due date is a usage error" "2" \
  "$(status_of bash "$NOTES" task add --title X --in reminders --due tomorrow --confirm)"

# ---- --remember stores the choice, and later tasks skip the question -------
reset
echo "x-apple-reminder://r2" >"$WORK/reply"
bash "$NOTES" task add --title Once --in reminders --remember --confirm >/dev/null
assert_eq "--remember saved the home" "task-home: reminders" "$(bash "$NOTES" pref show)"
assert_eq "the saved home is used without asking" "0" \
  "$(status_of bash "$NOTES" task add --title Twice --confirm)"
assert_eq "--in overrides the saved home" "3" \
  "$(status_of bash "$NOTES" task add --title Thrice --in notes)"

# ---- tasks in Notes: a new note, then an append ----------------------------
reset
: >"$WORK/reply"
bash "$NOTES" task add --title 'Send invoice' --in notes --confirm >/dev/null
assert_contains "no Tasks note yet: it is created with the item" "☐ Send invoice" "$(cat "$WORK/last.args")"
reset
printf 'x-coredata://AAAA-1111/ICNote/p9\tNotes\tTasks\n' >"$WORK/reply"
bash "$NOTES" task add --title 'Book flight' --in notes --confirm >/dev/null
assert_contains "an existing Tasks note is appended to" "x-coredata://AAAA-1111/ICNote/p9" "$(cat "$WORK/last.args")"
assert_contains "the appended line carries the box" "☐ Book flight" "$(cat "$WORK/last.args")"

# ---- secrets: never printed (all values below are made up) -----------------
ID="x-coredata://AAAA-1111/ICNote/"
RSC=$'\x1e'; USC=$'\x1f'
# Built from fragments at run time, so no secret-shaped literal sits in this file or in git
# history. All of it is made up (the AWS shape is the one AWS documents as an example).
FAKE_TOKEN="Qz7"'$'"mK2vLp9xRw"
FAKE_AWS="AKIA""IOSFODNN7""EXAMPLE"
PW="hunt""er2""hunt""er2"
rec() { printf '%s%s%s%s%s%s%s%s' "$ID$1" "$USC" "$2" "$USC" "$3" "$USC" "$4" "$RSC"; }
reset
{ rec p1 Notes "$FAKE_TOKEN" "$FAKE_TOKEN"; rec p2 Notes "Trip plan" "Book flights for March"
  rec p3 Notes "WiFi" "password: $PW"; rec p4 "Recently Deleted" "Old" "$FAKE_AWS"
  rec p5 Notes "Private" "[LOCKED]"; echo; } >"$WORK/reply"
out="$(bash "$NOTES" scan)"
assert_contains "scan flags the single-token note" "single-token-secret" "$out"
assert_contains "scan flags a credential assignment" "credential-assignment" "$out"
assert_contains "scan counts what it examined" "Examined: 4 note(s)" "$out"
assert_contains "scan counts locked notes it could not read" "1 locked and skipped" "$out"
assert_contains "scan reports the flag count" "2 flagged" "$out"
for leak in "$FAKE_TOKEN" "$PW" "$FAKE_AWS"; do
  if [[ "$out" == *"$leak"* ]]; then FAIL=$((FAIL + 1)); echo "  ✗ scan printed a secret: $leak"; else PASS=$((PASS + 1)); fi
done
assert_contains "scan redacts the title" "<redacted: looks like single-token-secret>" "$out"
if [[ "$out" == *"Old"* ]]; then FAIL=$((FAIL + 1)); echo "  ✗ scan looked inside Recently Deleted"; else PASS=$((PASS + 1)); fi
assert_contains "scan points at the remediation order" "revoke or rotate it at the source first" "$out"

reset
printf '%sp1\tNotes\t%s\n%sp2\tNotes\tPlan\n' "$ID" "$FAKE_TOKEN" "$ID" >"$WORK/reply"
out="$(bash "$NOTES" list)"
if [[ "$out" == *"$FAKE_TOKEN"* ]]; then FAIL=$((FAIL + 1)); echo "  ✗ list printed a credential-looking title"; else PASS=$((PASS + 1)); fi
assert_contains "list still shows ordinary titles" "Plan" "$out"

reset
printf '%sp3\tNotes\tWiFi\n' "$ID" >"$WORK/replies/1"
printf 'password: %s' "$PW" >"$WORK/replies/2"
assert_eq "show refuses a credential-looking note" "3" "$(status_of bash "$NOTES" show WiFi)"
reset
printf '%sp3\tNotes\tWiFi\n' "$ID" >"$WORK/replies/1"
printf 'password: %s' "$PW" >"$WORK/replies/2"
assert_contains "--reveal shows it and is audited" "$PW" "$(bash "$NOTES" show WiFi --reveal)"
assert_contains "the reveal is in the audit log" "revealed note" "$(cat "$NOTES_COMMANDER_STATE_DIR/audit.log")"
reset
printf '%sp3\tNotes\tPlan\n' "$ID" >"$WORK/replies/1"
printf '[LOCKED]' >"$WORK/replies/2"
assert_eq "a locked note is not read" "1" "$(status_of bash "$NOTES" show Plan)"

# ---- folders ---------------------------------------------------------------
reset
printf 'Notes\t3\nWork\t2\n' >"$WORK/reply"
assert_contains "an existing folder is a no-op" "already exists" "$(bash "$NOTES" folder create Work --confirm)"
assert_eq "an existing folder made no write call" "1" "$(calls)"
reset
assert_eq "folder create without --confirm is refused" "3" "$(status_of bash "$NOTES" folder create Fresh)"
assert_eq "the Recently Deleted name is rejected" "2" "$(status_of bash "$NOTES" folder create 'Recently Deleted' --confirm)"
assert_eq "a tab in a name is rejected" "2" "$(status_of bash "$NOTES" folder create $'a\tb' --confirm)"
reset
printf 'Notes\t3\n' >"$WORK/replies/1"; : >"$WORK/replies/2"; printf 'Notes\t3\nFresh\t0\n' >"$WORK/replies/3"
assert_contains "a new folder is created and checked" "Created folder 'Fresh'" "$(bash "$NOTES" folder create Fresh --confirm)"
reset
printf 'Notes\t3\n' >"$WORK/replies/1"; : >"$WORK/replies/2"; printf 'Notes\t3\n' >"$WORK/replies/3"
assert_eq "a folder that did not appear is an error" "1" "$(status_of bash "$NOTES" folder create Fresh --confirm)"

# ---- move: verified, journaled, undoable -----------------------------------
reset
printf 'Notes\t3\nWork\t2\n' >"$WORK/replies/1"
assert_eq "move needs --to" "2" "$(status_of bash "$NOTES" move --id "${ID}p1")"
assert_eq "move rejects a malformed id" "2" "$(status_of bash "$NOTES" move --id nope --to Work --confirm)"
assert_eq "move to a missing folder is refused" "1" "$(status_of bash "$NOTES" move --id "${ID}p1" --to Nowhere --confirm)"
reset
printf 'Notes\t3\nWork\t2\n' >"$WORK/replies/1"
assert_eq "move without --confirm is refused" "3" "$(status_of bash "$NOTES" move --id "${ID}p1" --to Work)"
reset
printf 'Notes\t3\nWork\t2\n' >"$WORK/replies/1"
printf 'Notes\t%sp1\tWork\n' "$ID" >"$WORK/replies/2"
out="$(bash "$NOTES" move --id "${ID}p1" --to Work --confirm)"
assert_contains "move says it was verified" "(verified)" "$out"
assert_contains "move is journaled with from and to" "Notes	Work" "$(cat "$NOTES_COMMANDER_STATE_DIR"/journal/*.tsv)"
reset
printf 'Notes\t3\nWork\t2\n' >"$WORK/replies/1"
printf 'Notes\t%sp1\tNotes\n' "$ID" >"$WORK/replies/2"
assert_eq "a move that did not land is an error" "1" "$(status_of bash "$NOTES" move --id "${ID}p1" --to Work --confirm)"
if ls "$NOTES_COMMANDER_STATE_DIR"/journal/*.tsv >/dev/null 2>&1; then
  FAIL=$((FAIL + 1)); echo "  ✗ a failed move was journaled"; else PASS=$((PASS + 1)); fi

# ---- organize: preflight, partial failure, undo ----------------------------
reset
cat >"$WORK/plan.json" <<JSON
[{"id":"${ID}p1","to":"Work"},{"id":"${ID}p2","to":"Work"}]
JSON
printf 'Notes\t3\nWork\t2\n' >"$WORK/replies/1"
printf '%sp1\tNotes\tA\n%sp2\tNotes\tB\n' "$ID" "$ID" >"$WORK/replies/2"
out="$(bash "$NOTES" organize "$WORK/plan.json" 2>&1 || true)"
assert_contains "organize previews the moves" "[Notes] -> [Work]" "$out"
assert_contains "organize says it changed nothing" "Refused: nothing was changed" "$out"
assert_eq "the preview made only read calls" "2" "$(calls)"

reset
printf 'not json' >"$WORK/bad.json"
assert_eq "a bad plan is a usage error" "2" "$(status_of bash "$NOTES" organize "$WORK/bad.json" --confirm)"
cat >"$WORK/dup.json" <<JSON
[{"id":"${ID}p1","to":"Work"},{"id":"${ID}p1","to":"Home"}]
JSON
assert_eq "a note listed twice is refused" "2" "$(status_of bash "$NOTES" organize "$WORK/dup.json" --confirm)"
reset
printf 'Notes\t3\n' >"$WORK/replies/1"
printf '%sp1\tNotes\tA\n%sp2\tNotes\tB\n' "$ID" "$ID" >"$WORK/replies/2"
assert_eq "a missing target folder stops the plan before any move" "1" "$(status_of bash "$NOTES" organize "$WORK/plan.json" --confirm)"
reset
printf 'Notes\t3\nWork\t2\n' >"$WORK/replies/1"
printf '%sp1\tNotes\tA\n' "$ID" >"$WORK/replies/2"
assert_eq "a plan naming an unknown note stops before any move" "1" "$(status_of bash "$NOTES" organize "$WORK/plan.json" --confirm)"

reset
printf 'Notes\t3\nWork\t2\n' >"$WORK/replies/1"
printf '%sp1\tNotes\tA\n%sp2\tNotes\tB\n' "$ID" "$ID" >"$WORK/replies/2"
printf 'Work\t3\n' >"$WORK/replies/3"
printf 'Notes\t%sp1\tWork\n' "$ID" >"$WORK/replies/4"
printf 'Work\t3\n' >"$WORK/replies/5"
printf 'Notes\t%sp2\tWork\n' "$ID" >"$WORK/replies/6"
out="$(bash "$NOTES" organize "$WORK/plan.json" --confirm)"
assert_contains "organize reports verified moves" "2 moved (each verified), 0 already in place, 0 failed" "$out"
assert_eq "two moves are journaled" "2" "$(cat "$NOTES_COMMANDER_STATE_DIR"/journal/*.tsv | wc -l | tr -d ' ')"
assert_contains "the journal lists the batch" "2 move(s)" "$(bash "$NOTES" journal)"

# partial failure: the second move does not land; the first stays journaled
reset
printf 'Notes\t3\nWork\t2\n' >"$WORK/replies/1"
printf '%sp1\tNotes\tA\n%sp2\tNotes\tB\n' "$ID" "$ID" >"$WORK/replies/2"
printf 'Work\t3\n' >"$WORK/replies/3"
printf 'Notes\t%sp1\tWork\n' "$ID" >"$WORK/replies/4"
printf 'Work\t3\n' >"$WORK/replies/5"
printf 'Notes\t%sp2\tNotes\n' "$ID" >"$WORK/replies/6"
assert_eq "a failing move makes organize exit 1" "1" "$(status_of bash "$NOTES" organize "$WORK/plan.json" --confirm)"
assert_eq "the move before the failure is still journaled" "1" "$(cat "$NOTES_COMMANDER_STATE_DIR"/journal/*.tsv | wc -l | tr -d ' ')"

# undo
reset
mkdir -p "$NOTES_COMMANDER_STATE_DIR/journal"
printf '%sp1\t%sp1\tNotes\tWork\n' "$ID" "$ID" >"$NOTES_COMMANDER_STATE_DIR/journal/20261113T000000Z-1.tsv"
assert_eq "undo without --confirm is refused" "3" "$(status_of bash "$NOTES" undo)"
printf 'Notes\t3\nWork\t2\n' >"$WORK/replies/1"
printf 'Work\t%sp1\tNotes\n' "$ID" >"$WORK/replies/2"
assert_contains "undo reports what it restored" "1 restored, 0 failed" "$(bash "$NOTES" undo --confirm)"
assert_contains "an undone batch is marked" "already undone" "$(bash "$NOTES" journal)"
assert_eq "undo with nothing to undo is an error" "1" "$(status_of bash "$NOTES" undo --confirm)"

# ---- lock and timeout ------------------------------------------------------
reset
mkdir -p "$NOTES_COMMANDER_STATE_DIR/lock"; echo "$$" >"$NOTES_COMMANDER_STATE_DIR/lock/pid"
printf 'Notes\t3\nWork\t2\n' >"$WORK/reply"
assert_eq "a live lock blocks a second write" "1" "$(status_of bash "$NOTES" move --id "${ID}p1" --to Work --confirm)"
echo 999999 >"$NOTES_COMMANDER_STATE_DIR/lock/pid"
assert_eq "a stale lock is taken over" "0" "$(status_of bash "$NOTES" folder create Work --confirm)"
reset
echo 5 >"$WORK/sleep"
start=$SECONDS
assert_eq "a hung call times out" "1" "$(NOTES_COMMANDER_TIMEOUT=1 status_of bash "$NOTES" folders)"
if (( SECONDS - start < 4 )); then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "  ✗ the timeout did not fire in time"; fi

echo "$PASS passed, $FAIL failed"
[[ "$FAIL" == 0 ]]
