# notes-commander

Find, open, create and append to Apple Notes and manage tasks in Notes or Reminders. Reads are free, every write needs your confirmation, and it asks where tasks should live.

Category: `productivity` · Keywords: Apple Notes, Reminders, tasks, macOS

## Skills

| Command | What it does |
|---|---|
| `/notes-commander:notes` | **Find** a note (or hear that it does not exist, with the folders and lists you do have), **open** or **show** it, **create** or **append**, **scan** for credentials, and **organize** with folders, moves, batch plans and undo |
| `/notes-commander:tasks` | **Add**, **list** or **finish** a task, in a Notes checklist or in Reminders. It asks which, unless your words or a saved choice settle it |
| `/notes-commander:setup` | Saves your default: Notes, Reminders, or ask every time |
| `/notes-commander:health` | Checks `jq`, the two apps and the macOS Automation permission |

## How it keeps you in control

- **Reads never ask**; `find` prints what it examined.
- **Every write is previewed first.** Without `--confirm` the command prints `WOULD: ...`
  and changes nothing (exit 3). The agent shows you that line and re-runs only after you
  say yes. Each write is recorded in `~/.local/state/notes-commander/audit.log` (ids and
  titles, never note text).
- **There is no delete.** A hook also blocks hand-written `osascript` that changes Notes
  or Reminders, so the confirmed path cannot be skipped. Escape: `NOTES-WRITE-OK: <reason>`.
- **Tasks ask where they go.** With no saved choice, `task add` refuses with `ASK:` until
  the agent has asked you. Answer "always" and it remembers; change it any time.

## Organizing, safely

`scan` flags notes that look like credentials (private keys, cloud and API tokens, JWTs,
`password: ...` lines, single random-looking tokens) and prints the rule, never the value.
`folder create`, `move` and `organize` are confirm-gated, **verify each move after it
happens**, take a lock so two writers cannot collide, and write an undo journal so
`undo` restores a batch even after a partial failure. Every call to Notes has a timeout, so
a pending macOS permission prompt cannot hang the session.

Credential handling follows current guidance (OWASP Secrets Management Cheat Sheet; NIST
SP 800-63B-4): revoke or rotate at the source first, then remove the plaintext, then use a
password manager. Notes is not a vault: a locked note still shows its first line as the title.

## Limits

- Notes' own checklists cannot be scripted, so a Notes task is a `☐ title` line appended to
  a note (default "Tasks"). Finishing one is done in Notes.
- macOS only. The first run makes macOS ask whether the terminal may control Notes and
  Reminders; allow it. Run `/notes-commander:health` to check.
- Claude Code only for now. A Codex package and Chrome lead research are planned.

## Install

```
/plugin marketplace add nasimubd/skills
/plugin install notes-commander@skills
```

Then run `/notes-commander:setup` and `/notes-commander:health`.

## Requirements

macOS (`osascript`), `jq`, and the Notes and Reminders apps.
