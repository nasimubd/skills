---
name: health
description: Use when notes-commander misbehaves or after setup. Checks jq, osascript, the Notes and Reminders apps, Automation permission and the saved preference. TRIGGERS - notes health, notes not working
allowed-tools: Bash
---

# Check notes-commander health

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

```bash
notes-commander health
```

It prints one line per check and a count (`Checked: N · failed: M`); exit 0 only when
every check passed. Report the failures with their fix, not just the count.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Automation check fails | macOS has not been told to allow it | System Settings > Privacy & Security > Automation: allow the terminal for Notes and Reminders |
| `notes-commander: command not found` | Plugin not enabled, or installed mid-session | Enable it, then `/reload-plugins` or start a new session; until then run `bash <repo>/plugins/notes-commander/bin/notes-commander` |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If the CLI drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
