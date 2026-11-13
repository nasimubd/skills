#!/usr/bin/env bash
# notes.sh — find, open, create and append to Apple Notes; manage tasks in Notes or
# Reminders. Tier 1: reads are free; every write needs --confirm, so a person (or the
# agent, after asking the person) approves each change. There is deliberately no delete.
#
# USAGE
#   notes.sh find <term> [--body]                 search Notes and open Reminders
#   notes.sh folders                              Notes folders with note counts
#   notes.sh list [--folder F]                    notes (id, folder, title)
#   notes.sh show <title> | --id ID               print a note's text
#   notes.sh open <title> | --id ID               bring a note up in the Notes app
#   notes.sh scan [--limit N]                     flag notes that look like they hold credentials
#   notes.sh folder create <name> --confirm       (idempotent)
#   notes.sh move (<title>|--id ID) --to FOLDER --confirm
#   notes.sh organize <plan.json> [--create-folders] --confirm   batch moves, journaled
#   notes.sh undo [--batch ID] --confirm          reverse the latest (or a named) move batch
#   notes.sh journal                              list move batches
#   notes.sh create --title T [--folder F] [--text X|-] --confirm
#   notes.sh append (<title> | --id ID) --text X|- --confirm
#   notes.sh reminders lists                      Reminders lists
#   notes.sh task add --title T [--in notes|reminders] [--note N] [--list L]
#                     [--due "YYYY-MM-DD[ HH:MM]"] [--remember] --confirm
#   notes.sh task list [--in notes|reminders] [--list L] [--done]
#   notes.sh task done --id ID --confirm          Reminders only
#   notes.sh pref show | pref set task-home notes|reminders|ask
#   notes.sh health
#
# EXIT CODES
#   0 ok · 1 runtime error (also: nothing matched for open/show) · 2 usage error
#   3 refused: a write without --confirm, or a task with no chosen home ("ask")
#
# ENVIRONMENT
#   NOTES_COMMANDER_CONFIG_DIR   preferences (default ~/.config/notes-commander)
#   NOTES_COMMANDER_STATE_DIR    audit log, undo journal, lock (default ~/.local/state/notes-commander)
#   NOTES_COMMANDER_TIMEOUT      seconds before a Notes/Reminders call is abandoned (default 60)

set -euo pipefail

readonly SELF="notes-commander"
readonly CONFIG_DIR="${NOTES_COMMANDER_CONFIG_DIR:-$HOME/.config/notes-commander}"
readonly STATE_DIR="${NOTES_COMMANDER_STATE_DIR:-$HOME/.local/state/notes-commander}"
readonly PREFS="$CONFIG_DIR/prefs.json"
readonly AUDIT="$STATE_DIR/audit.log"
readonly TRASH="Recently Deleted"
readonly BOX="☐"

die() { echo "$SELF: $1" >&2; exit "${2:-1}"; }
usage() { die "usage: $1" 2; }

# Run AppleScript from stdin with arguments passed as argv, never interpolated into the
# script text: a title containing a quote cannot change what the script does.
as() {
  local script="$1"; shift
  local limit="${NOTES_COMMANDER_TIMEOUT:-60}" rc=0
  if command -v perl >/dev/null 2>&1; then
    printf '%s' "$script" | perl -e 'alarm shift; exec @ARGV' "$limit" osascript - "$@" || rc=$?
  else
    printf '%s' "$script" | osascript - "$@" || rc=$?
  fi
  if [[ "$rc" == 142 ]]; then
    echo "$SELF: Notes/Reminders did not answer within ${limit}s. A macOS permission prompt may be waiting; run: $SELF health" >&2
    rc=1
  fi
  return "$rc"
}

need_jq() { command -v jq >/dev/null 2>&1 || die "jq is required (brew install jq)"; }

audit() {
  mkdir -p "$STATE_DIR"
  printf '%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" >>"$AUDIT"
}

# ---- flags -----------------------------------------------------------------
F_TITLE="" F_FOLDER="" F_TEXT="" F_ID="" F_IN="" F_NOTE="" F_LIST="" F_DUE=""
F_TO="" F_BATCH="" F_LIMIT=20000
F_BODY=0 F_DONE=0 F_CONFIRM=0 F_REMEMBER=0 F_REVEAL=0 F_CREATE_FOLDERS=0
POS=()

parse_flags() {
  POS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --title)   [[ $# -ge 2 ]] || usage "--title needs a value"; F_TITLE="$2"; shift 2 ;;
      --folder)  [[ $# -ge 2 ]] || usage "--folder needs a value"; F_FOLDER="$2"; shift 2 ;;
      --text)    [[ $# -ge 2 ]] || usage "--text needs a value"; F_TEXT="$2"; shift 2 ;;
      --id)      [[ $# -ge 2 ]] || usage "--id needs a value"; F_ID="$2"; shift 2 ;;
      --in)      [[ $# -ge 2 ]] || usage "--in needs notes or reminders"; F_IN="$2"; shift 2 ;;
      --note)    [[ $# -ge 2 ]] || usage "--note needs a value"; F_NOTE="$2"; shift 2 ;;
      --list)    [[ $# -ge 2 ]] || usage "--list needs a value"; F_LIST="$2"; shift 2 ;;
      --due)     [[ $# -ge 2 ]] || usage "--due needs a value"; F_DUE="$2"; shift 2 ;;
      --to)      [[ $# -ge 2 ]] || usage "--to needs a folder"; F_TO="$2"; shift 2 ;;
      --batch)   [[ $# -ge 2 ]] || usage "--batch needs an id"; F_BATCH="$2"; shift 2 ;;
      --limit)   [[ $# -ge 2 && "$2" =~ ^[0-9]+$ ]] || usage "--limit needs a number"; F_LIMIT="$2"; shift 2 ;;
      --reveal)  F_REVEAL=1; shift ;;
      --create-folders) F_CREATE_FOLDERS=1; shift ;;
      --body)    F_BODY=1; shift ;;
      --done)    F_DONE=1; shift ;;
      --confirm) F_CONFIRM=1; shift ;;
      --remember) F_REMEMBER=1; shift ;;
      --*)       usage "unknown flag $1" ;;
      *)         POS+=("$1"); shift ;;
    esac
  done
  if [[ "$F_TEXT" == "-" ]]; then F_TEXT="$(cat)"; fi
}

# The write gate. Without --confirm nothing changes: say what would happen, exit 3.
gate() {
  [[ "$F_CONFIRM" == 1 ]] && return 0
  echo "WOULD: $1"
  echo "Refused: nothing was changed. Show this to the user and re-run with --confirm once they approve." >&2
  exit 3
}

# ---- text helpers ----------------------------------------------------------
html_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

# Plain text on stdin -> Notes HTML: one <div> per line.
to_html() {
  local line
  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" ]]; then
      printf '<div><br></div>'
    else
      printf '<div>%s</div>' "$(printf '%s' "$line" | html_escape)"
    fi
  done
}

# ---- preferences -----------------------------------------------------------
pref_get() {
  need_jq
  local v=""
  [[ -f "$PREFS" ]] && v="$(jq -r '.task_home // empty' "$PREFS" 2>/dev/null || true)"
  printf '%s' "${v:-ask}"
}

pref_set() {
  need_jq
  case "$1" in notes|reminders|ask) ;; *) usage "task-home must be notes, reminders or ask" ;; esac
  mkdir -p "$CONFIG_DIR"
  jq -n --arg v "$1" '{task_home: $v}' >"$PREFS"
}

# ---- secrets ---------------------------------------------------------------
# Notes is not a safe place for credentials (a locked note still shows its first line as
# the title). So every command that prints note text or titles first asks whether the
# text looks like a credential, and never prints the value itself, only the rule it hit.
RS=$'\x1e'; US=$'\x1f'

# Text on stdin -> the name of the first rule it matches, or nothing.
secret_rule() {
  local t
  t="$(cat)"
  [[ -n "$t" ]] || return 0
  if   grep -Eq -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' <<<"$t"; then echo private-key
  elif grep -Eq -- 'AKIA[0-9A-Z]{16}' <<<"$t"; then echo aws-access-key
  elif grep -Eq -- 'gh[pousr]_[A-Za-z0-9]{36,}' <<<"$t"; then echo github-token
  elif grep -Eq -- 'xox[baprs]-[A-Za-z0-9-]{10,}' <<<"$t"; then echo slack-token
  elif grep -Eq -- 'AIza[0-9A-Za-z_-]{35}' <<<"$t"; then echo google-api-key
  elif grep -Eq -- 'sk-[A-Za-z0-9_-]{20,}' <<<"$t"; then echo api-key
  elif grep -Eq -- 'eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}' <<<"$t"; then echo jwt
  elif grep -Eiq -- '(password|passwd|pwd|passcode|secret|api[ _-]?key|token)[[:space:]]*(is|:|=|-)[[:space:]]*[^[:space:]]{6,}' <<<"$t"; then echo credential-assignment
  else
    # One token, 10-64 chars, at least three of lower/upper/digit/symbol, not an email or URL.
    local one="${t//[[:space:]]/}" classes=0
    if [[ "$one" == "$t" && ${#one} -ge 10 && ${#one} -le 64 && "$one" != *@*.* && "$one" != *://* ]]; then
      [[ "$one" =~ [a-z] ]] && classes=$((classes + 1))
      [[ "$one" =~ [A-Z] ]] && classes=$((classes + 1))
      [[ "$one" =~ [0-9] ]] && classes=$((classes + 1))
      [[ "$one" =~ [^A-Za-z0-9] ]] && classes=$((classes + 1))
      [[ "$classes" -ge 3 ]] && echo single-token-secret
    fi
  fi
  return 0
}

# A title that looks like a credential is never printed.
redact_title() {
  local rule
  rule="$(printf '%s' "$1" | secret_rule)"
  if [[ -n "$rule" ]]; then printf '<redacted: looks like %s>' "$rule"; else printf '%s' "$1"; fi
}

redact_lines() { # id <TAB> folder <TAB> title  ->  same, title redacted
  local id folder title
  while IFS=$'\t' read -r id folder title; do
    [[ -n "$id" ]] || continue
    printf '%s\t%s\t%s\n' "$id" "$folder" "$(redact_title "$title")"
  done
}

valid_note_id() { [[ "$1" =~ ^x-coredata://[A-Za-z0-9-]+/ICNote/p[0-9]+$ ]]; }
need_note_id() { valid_note_id "$1" || usage "'$1' is not a Notes id (see: $SELF list)"; }

# ---- lock and undo journal -------------------------------------------------
LOCK="$STATE_DIR/lock"
acquire_lock() {
  mkdir -p "$STATE_DIR"
  if mkdir "$LOCK" 2>/dev/null; then echo "$$" >"$LOCK/pid"; trap release_lock EXIT; return 0; fi
  local other
  other="$(cat "$LOCK/pid" 2>/dev/null || true)"
  if [[ -n "$other" ]] && ! kill -0 "$other" 2>/dev/null; then
    rm -rf "$LOCK"; mkdir "$LOCK" && echo "$$" >"$LOCK/pid" && { trap release_lock EXIT; return 0; }
  fi
  die "another notes-commander write is running (pid ${other:-unknown}); wait for it" 1
}
release_lock() { rm -rf "$LOCK"; }

JOURNAL_DIR="$STATE_DIR/journal"
new_batch() { mkdir -p "$JOURNAL_DIR"; date -u +%Y%m%dT%H%M%SZ-$$; }

# ---- Notes -----------------------------------------------------------------
# Output: id <TAB> folder <TAB> title, one per line. Mode: name | body | exact | all.
notes_search() {
  as '
on run argv
  set q to item 1 of argv
  set mode to item 2 of argv
  tell application "Notes"
    if mode is "all" then
      set hits to every note
    else if mode is "exact" then
      set hits to (notes whose name is q)
    else if mode is "body" then
      set hits to (notes whose name contains q or plaintext contains q)
    else
      set hits to (notes whose name contains q)
    end if
    set out to ""
    repeat with i from 1 to count of hits
      set n to item i of hits
      set c to container of n
      set out to out & (id of n) & tab & (name of c) & tab & (name of n) & linefeed
    end repeat
    return out
  end tell
end run' "$1" "$2" | awk -F'\t' -v t="$TRASH" 'NF && $2 != t'
}

notes_folders() {
  as '
tell application "Notes"
  set out to ""
  repeat with f in folders
    set out to out & (name of f) & tab & (count of notes of f) & linefeed
  end repeat
  return out
end tell' | awk -F'\t' -v t="$TRASH" 'NF && $1 != t'
}

reminder_lists() {
  as '
tell application "Reminders"
  set ls to every list
  set out to ""
  repeat with i from 1 to count of ls
    set l to item i of ls
    set out to out & (name of l) & linefeed
  end repeat
  return out
end tell' | awk 'NF'
}

# Resolve a title (or --id) to one note id, or explain what exists and stop.
NOTE_ID=""
resolve_note() {
  local title="$1" hits n
  if [[ -n "$F_ID" ]]; then NOTE_ID="$F_ID"; return 0; fi
  [[ -n "$title" ]] || usage "give a note title or --id"
  hits="$(notes_search "$title" exact)" || die "could not read Notes (run: $SELF health)"
  n="$(printf '%s' "$hits" | grep -c . || true)"
  if [[ "$n" == 1 ]]; then NOTE_ID="$(cut -f1 <<<"$hits")"; return 0; fi
  if [[ "$n" -gt 1 ]]; then
    echo "$SELF: $n notes are titled '$(redact_title "$title")'; pick one with --id:" >&2
    printf '%s\n' "$hits" | redact_lines >&2
    exit 1
  fi
  echo "$SELF: no note titled '$(redact_title "$title")' (examined: every note outside $TRASH)." >&2
  echo "Notes with similar titles:" >&2
  notes_search "$title" name | redact_lines | sed 's/^/  /' >&2 || true
  echo "Folders:" >&2
  notes_folders | sed 's/^/  /' >&2 || true
  exit 1
}

cmd_find() {
  parse_flags "$@"
  [[ ${#POS[@]} -ge 1 ]] || usage "find <term> [--body]"
  local term="${POS[*]}" mode="name" notes tasks ln
  [[ "$F_BODY" == 1 ]] && mode="body"
  notes="$(notes_search "$term" "$mode")" || die "could not read Notes (run: $SELF health)"
  tasks="$(task_list_reminders "" 0 | awk -F'\t' -v q="$term" 'index(tolower($3), tolower(q))')" || tasks=""
  echo "Examined: Notes ($mode match on '$term', excluding $TRASH) and open Reminders."
  ln="$(printf '%s' "$notes" | grep -c . || true)"
  echo "Notes: $ln match(es)"
  [[ "$ln" == 0 ]] || printf '%s\n' "$notes" | redact_lines | awk -F'\t' '{printf "  %s  [%s]  %s\n", $3, $2, $1}'
  ln="$(printf '%s' "$tasks" | grep -c . || true)"
  echo "Reminders: $ln match(es)"
  [[ "$ln" == 0 ]] || printf '%s\n' "$tasks" | awk -F'\t' '{printf "  %s  [%s]  %s\n", $3, $2, $1}'
  if [[ -z "$notes$tasks" ]]; then
    echo "Nothing matches '$term'. What exists instead:"
    echo "Notes folders:"
    notes_folders | awk -F'\t' '{printf "  %s (%s notes)\n", $1, $2}'
    echo "Reminders lists:"
    reminder_lists | sed 's/^/  /'
  fi
}

cmd_folders() { notes_folders | awk -F'\t' '{printf "%s\t%s notes\n", $1, $2}'; }

cmd_list() {
  parse_flags "$@"
  notes_search "" all | awk -F'\t' -v f="$F_FOLDER" 'f == "" || $2 == f' | redact_lines
}

cmd_show() {
  parse_flags "$@"
  resolve_note "${POS[*]:-}"
  need_note_id "$NOTE_ID"
  local text rule
  text="$(as 'on run argv
  tell application "Notes"
    set n to note id (item 1 of argv)
    if password protected of n then return "[LOCKED]"
    return plaintext of n
  end tell
end run' "$NOTE_ID")" || die "could not read the note"
  if [[ "$text" == "[LOCKED]" ]]; then die "this note is locked; unlock it in the Notes app" 1; fi
  rule="$(printf '%s' "$text" | secret_rule)"
  if [[ -n "$rule" && "$F_REVEAL" != 1 ]]; then
    echo "Refused: this note looks like it holds a credential ($rule), so its text is not printed." >&2
    echo "If the user explicitly asks to see it, re-run with --reveal (the reveal is audited)." >&2
    exit 3
  fi
  [[ -z "$rule" ]] || audit "revealed note $NOTE_ID (rule: $rule)"
  printf '%s\n' "$text"
}

cmd_open() {
  parse_flags "$@"
  resolve_note "${POS[*]:-}"
  need_note_id "$NOTE_ID"
  as 'on run argv
  tell application "Notes"
    activate
    show note id (item 1 of argv)
  end tell
end run' "$NOTE_ID" >/dev/null
  echo "Opened note $NOTE_ID in the Notes app."
}

cmd_create() {
  parse_flags "$@"
  [[ -n "$F_TITLE" ]] || usage "create --title T [--folder F] [--text X|-] --confirm"
  gate "create a note titled '$F_TITLE'${F_FOLDER:+ in folder '$F_FOLDER'}"
  create_note "$F_TITLE" "$F_FOLDER" "$F_TEXT"
}

# The title is the first line of the body: Notes names a note after it.
create_note() {
  local title="$1" folder="$2" text="$3" html id
  html="<h1>$(printf '%s' "$title" | html_escape)</h1>"
  [[ -z "$text" ]] || html="$html$(printf '%s\n' "$text" | to_html)"
  id="$(as '
on run argv
  set f to item 1 of argv
  set h to item 2 of argv
  tell application "Notes"
    if f is "" then
      set n to make new note with properties {body:h}
    else
      if not (exists folder f) then error "no Notes folder named " & f
      set n to make new note at folder f with properties {body:h}
    end if
    return id of n
  end tell
end run' "$folder" "$html")" || die "could not create the note"
  audit "created note $id '$title'"
  echo "Created note '$title' ($id)."
}

cmd_append() {
  parse_flags "$@"
  [[ -n "$F_TEXT" ]] || usage "append (<title>|--id ID) --text X|- --confirm"
  resolve_note "${POS[*]:-}"
  gate "append ${#F_TEXT} characters to note $NOTE_ID${POS[0]:+ ('$(redact_title "${POS[*]}")')}"
  as 'on run argv
  tell application "Notes"
    set n to note id (item 1 of argv)
    set body of n to (body of n) & (item 2 of argv)
  end tell
end run' "$NOTE_ID" "$(printf '%s\n' "$F_TEXT" | to_html)" >/dev/null || die "could not append"
  audit "appended to note $NOTE_ID"
  echo "Appended to note $NOTE_ID."
}

# ---- Reminders / tasks -----------------------------------------------------
# Output: id <TAB> list <TAB> name <TAB> due. Open reminders unless done=1.
task_list_reminders() {
  as '
on run argv
  set ln to item 1 of argv
  set wantDone to (item 2 of argv is "1")
  tell application "Reminders"
    if ln is "" then
      set ls to every list
    else
      set ls to {list ln}
    end if
    set out to ""
    repeat with l in ls
      repeat with r in (reminders of l whose completed is wantDone)
        set d to ""
        try
          set d to (due date of r) as string
        end try
        set out to out & (id of r) & tab & (name of l) & tab & (name of r) & tab & d & linefeed
      end repeat
    end repeat
    return out
  end tell
end run' "$1" "$2" | awk 'NF'
}

# "YYYY-MM-DD[ HH:MM]" -> "Y M D h m" (validated), default 09:00.
parse_due() {
  local re='^([0-9]{4})-([0-9]{2})-([0-9]{2})( ([0-9]{2}):([0-9]{2}))?$'
  [[ "$1" =~ $re ]] || usage "--due must be YYYY-MM-DD or 'YYYY-MM-DD HH:MM'"
  echo "${BASH_REMATCH[1]} $((10#${BASH_REMATCH[2]})) $((10#${BASH_REMATCH[3]})) $((10#${BASH_REMATCH[5]:-9})) $((10#${BASH_REMATCH[6]:-0}))"
}

add_reminder() {
  local title="$1" list="$2" due="$3" y="" m="" d="" hh="" mi="" id
  if [[ -n "$due" ]]; then
    local parts
    parts="$(parse_due "$due")" || exit "$?"   # a usage error must not be swallowed by the subshell
    read -r y m d hh mi <<<"$parts"
  fi
  id="$(as '
on run argv
  set t to item 1 of argv
  set ln to item 2 of argv
  set y to item 3 of argv
  tell application "Reminders"
    if ln is "" then
      set tgt to default list
    else
      if not (exists list ln) then error "no Reminders list named " & ln
      set tgt to list ln
    end if
    tell tgt to set r to make new reminder with properties {name:t}
    if y is not "" then
      set dd to current date
      set day of dd to 1
      set year of dd to (y as integer)
      set month of dd to ((item 4 of argv) as integer)
      set day of dd to ((item 5 of argv) as integer)
      set hours of dd to ((item 6 of argv) as integer)
      set minutes of dd to ((item 7 of argv) as integer)
      set seconds of dd to 0
      set due date of r to dd
    end if
    return id of r
  end tell
end run' "$title" "$list" "$y" "$m" "$d" "$hh" "$mi")" || die "could not create the reminder"
  audit "created reminder $id '$title'"
  echo "Created reminder '$title' ($id)."
}

task_home() {
  local home="$F_IN"
  [[ -n "$home" ]] || home="$(pref_get)"
  case "$home" in
    notes|reminders) printf '%s' "$home" ;;
    ask)
      echo "ASK: where should this task live, a Notes checklist or Reminders?" >&2
      echo "Ask the user, then re-run with --in notes or --in reminders (add --remember if they say always)." >&2
      exit 3 ;;
    *) usage "--in must be notes or reminders" ;;
  esac
}

cmd_task() {
  local sub="${1:-}"; shift || true
  parse_flags "$@"
  case "$sub" in
    add)
      [[ -n "$F_TITLE" ]] || usage "task add --title T [--in notes|reminders] [--due D] --confirm"
      local home
      home="$(task_home)"
      if [[ "$home" == reminders ]]; then
        gate "add reminder '$F_TITLE'${F_LIST:+ to list '$F_LIST'}${F_DUE:+ due $F_DUE}"
        add_reminder "$F_TITLE" "$F_LIST" "$F_DUE"
      else
        local note="${F_NOTE:-Tasks}" hits n
        gate "add '$BOX $F_TITLE' to the note '$note' (created if it does not exist)"
        hits="$(notes_search "$note" exact)" || die "could not read Notes"
        n="$(printf '%s' "$hits" | grep -c . || true)"
        if [[ "$n" == 0 ]]; then
          create_note "$note" "$F_FOLDER" "$BOX $F_TITLE"
        elif [[ "$n" == 1 ]]; then
          F_ID="$(cut -f1 <<<"$hits")"; F_TEXT="$BOX $F_TITLE"
          cmd_append --id "$F_ID" --text "$F_TEXT" --confirm
        else
          die "$n notes are titled '$note'; name one with --note and --folder"
        fi
      fi
      # Saved only after the user confirmed and the task was added: a preview or a refusal
      # must not change configuration.
      if [[ "$F_REMEMBER" == 1 ]]; then pref_set "$home"; echo "Remembered: tasks go to $home."; fi ;;
    list)
      local home="${F_IN:-both}"
      if [[ "$home" == both || "$home" == notes ]]; then
        echo "== Notes checklist lines ($BOX) =="
        local note="${F_NOTE:-Tasks}" id
        id="$(notes_search "$note" exact | head -1 | cut -f1)" || id=""
        if [[ -n "$id" ]]; then
          as 'on run argv
  tell application "Notes" to return plaintext of note id (item 1 of argv)
end run' "$id" | grep "^$BOX" || echo "(no open items in '$note')"
        else
          echo "(no note titled '$note')"
        fi
      fi
      if [[ "$home" == both || "$home" == reminders ]]; then
        echo "== Reminders ($([[ $F_DONE == 1 ]] && echo done || echo open)) =="
        task_list_reminders "$F_LIST" "$F_DONE" | awk -F'\t' '{printf "%s  [%s]  %s  %s\n", $3, $2, $4, $1}'
      fi ;;
    done)
      [[ -n "$F_ID" ]] || usage "task done --id ID --confirm (Reminders only)"
      gate "mark reminder $F_ID as completed"
      as 'on run argv
  tell application "Reminders" to set completed of reminder id (item 1 of argv) to true
end run' "$F_ID" >/dev/null || die "could not complete the reminder"
      audit "completed reminder $F_ID"
      echo "Completed reminder $F_ID." ;;
    *) usage "task add|list|done" ;;
  esac
}

cmd_pref() {
  case "${1:-}" in
    show) echo "task-home: $(pref_get)" ;;
    set)  [[ "${2:-}" == task-home && -n "${3:-}" ]] || usage "pref set task-home notes|reminders|ask"
          pref_set "$3"; echo "task-home: $3" ;;
    *)    usage "pref show | pref set task-home notes|reminders|ask" ;;
  esac
}

# ---- scan: find notes that look like they hold credentials ------------------
# Prints id, folder, rule and a redacted title. Never prints note text.
cmd_scan() {
  parse_flags "$@"
  local raw n=0 locked=0 flagged=0 rec rest id folder title text rule
  raw="$(as '
on run argv
  set lim to (item 1 of argv) as integer
  set us to character id 31
  set rs to character id 30
  tell application "Notes"
    set allNotes to every note
    set out to ""
    repeat with i from 1 to count of allNotes
      set n to item i of allNotes
      set c to container of n
      set t to ""
      try
        if password protected of n then
          set t to "[LOCKED]"
        else
          set t to plaintext of n
        end if
      end try
      if (count of t) > lim then set t to text 1 thru lim of t
      set out to out & (id of n) & us & (name of c) & us & (name of n) & us & t & rs
    end repeat
    return out
  end tell
end run' "$F_LIMIT")" || die "could not read Notes (run: $SELF health)"
  while IFS= read -r -d "$RS" rec; do
    rec="${rec#$'\n'}"
    [[ -n "$rec" ]] || continue
    id="${rec%%"$US"*}"; rest="${rec#*"$US"}"
    folder="${rest%%"$US"*}"; rest="${rest#*"$US"}"
    title="${rest%%"$US"*}"; text="${rest#*"$US"}"
    [[ "$folder" == "$TRASH" ]] && continue
    n=$((n + 1))
    if [[ "$text" == "[LOCKED]" ]]; then locked=$((locked + 1)); continue; fi
    rule="$(printf '%s' "$text" | secret_rule)"
    [[ -n "$rule" ]] || rule="$(printf '%s' "$title" | secret_rule)"
    if [[ -n "$rule" ]]; then
      flagged=$((flagged + 1))
      printf '%s\t%s\t%s\t%s\n' "$id" "$folder" "$rule" "$(redact_title "$title")"
    fi
  done <<<"$raw"
  echo "Examined: $n note(s) outside $TRASH (first $F_LIMIT characters of each); $locked locked and skipped; $flagged flagged."
  if [[ "$flagged" -gt 0 ]]; then
    echo "A flagged note is a lead, not a verdict. If it holds a real credential: revoke or rotate it at the source first, then remove it from Notes, then store the new one in a password manager (OWASP Secrets Management; NIST SP 800-63B)."
  fi
}

# ---- folders and moves ------------------------------------------------------
valid_folder_name() {
  [[ -n "$1" && ${#1} -le 100 && "$1" != "$TRASH" && "$1" != *$'\t'* && "$1" != *$'\n'* ]] \
    || usage "folder name must be 1-100 characters, no tabs or newlines, and not '$TRASH'"
}

folder_exists() { notes_folders | cut -f1 | grep -Fxq -- "$1"; }

make_folder() {
  as 'on run argv
  tell application "Notes"
    if not (exists folder (item 1 of argv)) then make new folder with properties {name:(item 1 of argv)}
  end tell
end run' "$1" >/dev/null || die "could not create the folder '$1'"
  folder_exists "$1" || die "folder '$1' was not there after creating it"
}

cmd_folder() {
  [[ "${1:-}" == create ]] || usage "folder create <name> --confirm"
  shift; parse_flags "$@"
  local name="${POS[*]:-}"
  valid_folder_name "$name"
  if folder_exists "$name"; then echo "Folder '$name' already exists; nothing to do."; return 0; fi
  gate "create the Notes folder '$name'"
  acquire_lock
  make_folder "$name"
  audit "created folder '$name'"
  echo "Created folder '$name'."
}

# Move one note and check it landed. Prints the new id. Ids can change on a move, so the
# journal records the id the note has afterwards.
move_one() { # id folder
  local out src nid dest
  out="$(as 'on run argv
  tell application "Notes"
    set n to note id (item 1 of argv)
    set c1 to container of n
    set src to name of c1
    move n to folder (item 2 of argv)
    set nid to id of n
    set n2 to note id nid
    set c2 to container of n2
    set dest to name of c2
    return src & tab & nid & tab & dest
  end tell
end run' "$1" "$2")" || return 1
  IFS=$'\t' read -r src nid dest <<<"$out"
  [[ "$dest" == "$2" ]] || { echo "$SELF: moved $1 but it is in '$dest', not '$2'" >&2; return 1; }
  printf '%s\t%s\t%s\t%s\n' "$1" "$nid" "$src" "$dest"
}

journal_add() { printf '%s\n' "$2" >>"$JOURNAL_DIR/$1.tsv"; }

cmd_move() {
  parse_flags "$@"
  [[ -n "$F_TO" ]] || usage "move (<title>|--id ID) --to FOLDER --confirm"
  valid_folder_name "$F_TO"
  resolve_note "${POS[*]:-}"
  need_note_id "$NOTE_ID"
  folder_exists "$F_TO" || die "no Notes folder named '$F_TO' (create it first: $SELF folder create '$F_TO' --confirm)"
  gate "move note $NOTE_ID${POS[0]:+ ('$(redact_title "${POS[*]}")')} to folder '$F_TO'"
  acquire_lock
  local batch line
  batch="$(new_batch)"
  line="$(move_one "$NOTE_ID" "$F_TO")" || die "move failed; nothing else was changed"
  journal_add "$batch" "$line"
  audit "moved note $NOTE_ID to '$F_TO' (batch $batch)"
  echo "Moved note into '$F_TO' (verified). Undo with: $SELF undo --batch $batch --confirm"
}

# plan.json: [{"id": "x-coredata://.../ICNote/p1", "to": "Folder"}, ...]
cmd_organize() {
  parse_flags "$@"
  need_jq
  local plan="${POS[0]:-}"
  [[ -f "$plan" ]] || usage "organize <plan.json> [--create-folders] --confirm"
  jq -e 'type == "array" and length > 0 and all(.[]; (.id|type=="string") and (.to|type=="string"))' "$plan" >/dev/null \
    || usage "plan must be a non-empty JSON array of {\"id\": ..., \"to\": ...}"
  local count dup id to idx missing="" folders have
  count="$(jq length "$plan")"
  dup="$(jq -r '[.[].id] | group_by(.) | map(select(length > 1) | .[0]) | .[]' "$plan")"
  [[ -z "$dup" ]] || die "the plan lists a note twice: $dup" 2
  folders="$(notes_folders | cut -f1)" || die "could not read Notes"
  have="$(notes_search "" all)" || die "could not read Notes"
  echo "Examined: $count planned move(s) against $(printf '%s\n' "$have" | grep -c .) note(s) and $(printf '%s\n' "$folders" | grep -c .) folder(s)."
  local -a ids tos
  idx=0
  while IFS=$'\t' read -r id to; do
    need_note_id "$id"; valid_folder_name "$to"
    printf '%s\n' "$have" | cut -f1 | grep -Fxq -- "$id" || die "note $id is not in Notes (the plan is out of date; list again)" 1
    printf '%s\n' "$folders" | grep -Fxq -- "$to" || { [[ "$F_CREATE_FOLDERS" == 1 ]] || missing="$missing '$to'"; }
    ids[$idx]="$id"; tos[$idx]="$to"; idx=$((idx + 1))
  done < <(jq -r '.[] | [.id, .to] | @tsv' "$plan")
  [[ -z "$missing" ]] || die "folders do not exist:$missing (add --create-folders, or create them first)" 1
  local i from
  for ((i = 0; i < count; i++)); do
    from="$(printf '%s\n' "$have" | awk -F'\t' -v id="${ids[$i]}" '$1 == id {print $2}')"
    printf '  %s  [%s] -> [%s]  %s\n' "${ids[$i]##*/}" "$from" "${tos[$i]}" "$(redact_title "$(printf '%s\n' "$have" | awk -F'\t' -v id="${ids[$i]}" '$1 == id {print $3}')")"
  done
  gate "apply $count move(s) listed above$([[ "$F_CREATE_FOLDERS" == 1 ]] && echo ', creating missing folders')"
  acquire_lock
  local batch line done_n=0 skipped=0 failed=0
  batch="$(new_batch)"
  for ((i = 0; i < count; i++)); do
    from="$(printf '%s\n' "$have" | awk -F'\t' -v id="${ids[$i]}" '$1 == id {print $2}')"
    if [[ "$from" == "${tos[$i]}" ]]; then skipped=$((skipped + 1)); continue; fi
    folder_exists "${tos[$i]}" || make_folder "${tos[$i]}"
    if line="$(move_one "${ids[$i]}" "${tos[$i]}")"; then
      journal_add "$batch" "$line"; done_n=$((done_n + 1))
    else
      failed=$((failed + 1)); echo "$SELF: stopped at ${ids[$i]}; the $done_n move(s) before it are journaled and can be undone" >&2; break
    fi
  done
  audit "organize batch $batch: $done_n moved, $skipped already in place, $failed failed"
  echo "Batch $batch: $done_n moved (each verified), $skipped already in place, $failed failed."
  [[ "$done_n" -gt 0 ]] && echo "Undo with: $SELF undo --batch $batch --confirm"
  [[ "$failed" == 0 ]]
}

cmd_journal() {
  [[ -d "$JOURNAL_DIR" ]] || { echo "No move batches yet."; return 0; }
  local f
  for f in "$JOURNAL_DIR"/*.tsv "$JOURNAL_DIR"/*.undone; do
    [[ -f "$f" ]] || continue
    printf '%s\t%s move(s)%s\n' "$(basename "$f" | sed 's/\.\(tsv\|undone\)$//')" "$(grep -c . "$f")" "$([[ "$f" == *.undone ]] && echo '  (already undone)')"
  done | sort
}

cmd_undo() {
  parse_flags "$@"
  local file line nid from to ok=0 bad=0 batch
  if [[ -n "$F_BATCH" ]]; then
    [[ "$F_BATCH" =~ ^[A-Za-z0-9-]+$ ]] || usage "bad batch id"
    file="$JOURNAL_DIR/$F_BATCH.tsv"
  else
    file="$(ls -1 "$JOURNAL_DIR"/*.tsv 2>/dev/null | sort | tail -1 || true)"
  fi
  [[ -n "$file" && -f "$file" ]] || die "no move batch to undo (see: $SELF journal)" 1
  batch="$(basename "$file" .tsv)"
  echo "Batch $batch would put back:"
  while IFS=$'\t' read -r _ nid from to; do printf '  %s  [%s] -> [%s]\n' "${nid##*/}" "$to" "$from"; done <"$file"
  gate "undo batch $batch ($(grep -c . "$file") move(s))"
  acquire_lock
  while IFS=$'\t' read -r _ nid from to; do
    if folder_exists "$from" && move_one "$nid" "$from" >/dev/null; then ok=$((ok + 1)); else bad=$((bad + 1)); echo "$SELF: could not put $nid back into '$from'" >&2; fi
  done < <(sort -r "$file")
  audit "undo batch $batch: $ok restored, $bad failed"
  if [[ "$bad" == 0 ]]; then mv "$file" "${file%.tsv}.undone"; fi
  echo "Undo of $batch: $ok restored, $bad failed."
  [[ "$bad" == 0 ]]
}

cmd_health() {
  local checked=0 failed=0
  check() {
    checked=$((checked + 1))
    if eval "$2" >/dev/null 2>&1; then echo "ok    $1"; else failed=$((failed + 1)); echo "FAIL  $1 — $3"; fi
  }
  check "jq installed" 'command -v jq' "brew install jq"
  check "osascript available" 'command -v osascript' "this plugin needs macOS"
  check "perl present (call timeout)" 'command -v perl' "without it a pending permission prompt can hang a command"
  check "state folder writable" 'mkdir -p "$STATE_DIR" && test -w "$STATE_DIR"' "$STATE_DIR is not writable"
  check "no stale write lock" '! test -d "$LOCK" || ! kill -0 "$(cat "$LOCK/pid" 2>/dev/null)" 2>/dev/null' "remove $LOCK if no write is running"
  check "Notes app present" 'osascript -e "id of application \"Notes\""' "Notes.app not found"
  check "Reminders app present" 'osascript -e "id of application \"Reminders\""' "Reminders.app not found"
  check "Notes readable (Automation permission)" 'osascript -e "tell application \"Notes\" to count of notes"' "allow your terminal under System Settings > Privacy & Security > Automation > Notes"
  check "Reminders readable (Automation permission)" 'osascript -e "tell application \"Reminders\" to count of lists"' "allow your terminal under System Settings > Privacy & Security > Automation > Reminders"
  echo "task-home preference: $(pref_get 2>/dev/null || echo unreadable) ($PREFS)"
  echo "Checked: $checked · failed: $failed"
  [[ "$failed" == 0 ]]
}

main() {
  local cmd="${1:-}"; shift || true
  case "$cmd" in
    find) cmd_find "$@" ;;
    folders) cmd_folders ;;
    list) cmd_list "$@" ;;
    show) cmd_show "$@" ;;
    open) cmd_open "$@" ;;
    create) cmd_create "$@" ;;
    append) cmd_append "$@" ;;
    reminders) [[ "${1:-}" == lists ]] || usage "reminders lists"; reminder_lists ;;
    scan) cmd_scan "$@" ;;
    folder) cmd_folder "$@" ;;
    move) cmd_move "$@" ;;
    organize) cmd_organize "$@" ;;
    undo) cmd_undo "$@" ;;
    journal) cmd_journal ;;
    task) cmd_task "$@" ;;
    pref) cmd_pref "$@" ;;
    health) cmd_health ;;
    *) usage "$SELF find|folders|list|show|open|scan|folder|move|organize|undo|journal|create|append|reminders|task|pref|health" ;;
  esac
}

main "$@"
