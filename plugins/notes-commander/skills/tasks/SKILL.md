---
name: tasks
description: Use when the user wants to add, list or finish a task or reminder. Asks whether it goes in a Notes checklist or Reminders unless already settled. TRIGGERS - add task, remind me, my todos
allowed-tools: Bash
argument-hint: [task]
---

# Tasks in Notes or Reminders

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

Tasks can live in a **Notes checklist** or in **Reminders**. The user picks at the time.

## Execution

```bash
notes-commander task list                  # both places; add --in notes|reminders
notes-commander pref show                  # the saved choice: notes, reminders or ask
```

### Add

Decide the home like this, in order:

1. The user's words settle it ("remind me", "due Friday" mean Reminders; "in my project
   note" means Notes): use `--in`.
2. Otherwise run it plainly. With no saved choice the command exits 3 with
   `ASK: where should this task live`. **Ask the user** (Notes checklist or Reminders),
   and whether that is "just this time" or "always".
3. "Always" means add `--remember`; "ask me again" means `notes-commander pref set task-home ask`.

Then preview and confirm, as with notes: run without `--confirm`, show `WOULD: ...`, add
`--confirm` after approval.

```bash
notes-commander task add --title "Call Jona" --in reminders --due "2026-11-20 10:00" --list "Work"
notes-commander task add --title "Send invoice" --in notes --note "Tasks"
notes-commander task done --id <reminder-id>          # Reminders only
```

Notes cannot script its native checklists, so a Notes task is a line `☐ title` appended
to a note (default "Tasks", created if missing). Finishing a Notes task is done by the
user in Notes, or with `notes append`; say so rather than pretending otherwise.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Exit 3 with `ASK:` | No saved home and no `--in` | Ask the user, re-run with `--in` |
| `no Reminders list named X` | Wrong list | `notes-commander reminders lists` |
| `--due must be YYYY-MM-DD` | Other date format | Convert it; time defaults to 09:00 |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If the CLI drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
