# notes-commander — maintainer notes

**Hub**: [Root CLAUDE.md](../../CLAUDE.md) | **Sibling**: [plugins/CLAUDE.md](../CLAUDE.md)

Invariants and decisions that aren't obvious from reading the code.

## Decisions (2026-11-13, user-approved)

- A plugin that drives local macOS apps through `osascript`, not an MCP server.
- Category `productivity`, per the hub's rule for messaging and personal-tool plugins.
- Tasks may live in a Notes checklist **or** Reminders. The agent asks the user at the
  time; "always" is saved in `~/.config/notes-commander/prefs.json`. Default is `ask`.
- Tier 1 first: reads free, every write needs `--confirm`. Chrome lead research and a
  Codex package are deferred (the user chose Notes and Reminders first).

## Credential handling (2026-11-13, researched)

A live scan of the user's Notes found a note whose title is a password-shaped token. Current
guidance (OWASP Secrets Management Cheat Sheet: "Keys that were exposed should undergo
immediate revocation"; NIST SP 800-63B-4 3.1.1.2: change on evidence of compromise, allow
password managers) is: revoke or rotate at the source first, then remove the plaintext,
then use a password manager. So the plugin **detects and tells, and never moves, copies or
prints the value**: `scan` prints the rule only, `list` and `find` redact titles, `show`
refuses without `--reveal` (audited). Do not add a feature that "stores" or "migrates"
secrets. Test data must be made up: a real credential from the user's library was once
about to be pasted into a test and was caught; tests use AWS's published example key and
invented strings only.

## Robustness invariants

- Every write is verified after it happens (`move_one` re-reads the folder) and journaled
  with the note's id *afterwards*, because ids can change on a move. Undo uses that id.
- Writes take `$STATE_DIR/lock` (a dead process's lock is taken over). Every Notes call runs
  under `alarm` (`NOTES_COMMANDER_TIMEOUT`, default 60 s) and exits 1 with a pointer to
  `health` rather than hanging on a macOS permission prompt.
- `organize` preflights everything (JSON shape, duplicate ids, unknown notes, missing
  folders) before the first move, and stops at the first failure with the earlier moves
  journaled.
- AppleScript reading a note's folder must go through `item i of hits` then `container of n`;
  iterating `repeat with n in hits` and asking `container of n` fails on a real library
  (found live on 2026-11-13; the stubbed tests cannot catch it).

## The gate is in code, three times

1. `gate()` in `scripts/notes.sh`: a write without `--confirm` prints `WOULD: ...` and
   exits 3 before any `osascript` call (tests assert zero calls).
2. `task_home()`: with preference `ask` and no `--in`, `task add` exits 3 with `ASK:`,
   so the question cannot be skipped by a session that forgot the SKILL.md.
3. `hooks/write-gate.sh` denies hand-written `osascript` that changes Notes or Reminders
   unless it carries `NOTES-WRITE-OK: <10+ char reason>`. The sanctioned path passes
   because the AppleScript lives in `notes.sh`, not on the command line. It fails open.

## Things that look wrong but are deliberate

- **Arguments reach AppleScript as `argv`** (`osascript - args`, script on stdin), never
  spliced into the script text. A title with a quote cannot change what runs.
- **No delete command.** Deleting is rare and unrecoverable enough that the user does it
  in Notes. Do not add one without a new decision.
- **Notes tasks are `☐` text lines**, because Notes' native checklists are not exposed to
  AppleScript. Do not claim to tick them.
- **Notes in "Recently Deleted" are ignored** by search and open.
- **A note's title is its first line.** `create` writes `<h1>title</h1>` first.
- **`create` never makes folders**: a typo'd folder name is an error, not a new folder.
- **Audit log holds ids and titles only**, never note text.

## Tests

`tests/test-notes.sh` stubs `osascript` on `PATH`, so it proves argument handling and
the gates but **not** real AppleScript behaviour. Run `notes-commander health` and one
confirmed `create` and `task add` on a real Mac after changing any AppleScript block.

Verified live on 2026-11-13 (macOS, 15 real notes): `health`, `folders`, `list`, `scan`,
`folder create` (and its no-op repeat), `move`, `undo`, and a 13-move `organize` with every
move verified. Two AppleScript bugs only the live run could find were fixed
(`container of` via a list reference; `name of (container of n)` in one expression).
**Not yet verified live:** `create`, `append`, `task add|done` and the Reminders reads
beyond an empty list. Run them once before relying on them.
