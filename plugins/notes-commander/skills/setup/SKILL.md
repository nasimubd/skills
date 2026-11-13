---
name: setup
description: Use when the user wants to set up notes-commander or change where tasks go by default (Notes, Reminders, or ask each time). Writes only a local preference file. TRIGGERS - notes setup, task default
allowed-tools: Bash
---

# Set up notes-commander

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

The only setting is `task-home`, stored in `~/.config/notes-commander/prefs.json` on this
machine and never committed. Change it only when the user asks.

## Execution

```bash
notes-commander pref show
notes-commander pref set task-home ask          # ask every time (default)
notes-commander pref set task-home reminders    # always Reminders
notes-commander pref set task-home notes        # always a Notes checklist
```

Finish with the `health` skill. The first run of any command makes macOS ask whether the
terminal may control Notes and Reminders; the user has to allow it.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `task-home must be notes, reminders or ask` | Typo | Use one of the three values |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If the CLI drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
