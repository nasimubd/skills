---
name: health
description: Use when teams-commander misbehaves or after setup. Checks jq, clipboard, the Teams app, the state folder and the contacts file. TRIGGERS - teams health, teams-commander not working
allowed-tools: Bash
---

# Check teams-commander health

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

```bash
teams-commander health
```

It prints one line per check and a count (`Checked: N · failed: M`); exit 0 only when
every check passed. Report the failures with their fix, not just the count.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Teams not installed | App missing or renamed | Links still work in the browser |
| Contacts file missing | Setup not run | Run the `setup` skill |
| `teams-commander: command not found` | Plugin not enabled, or installed mid-session | Enable the plugin, then `/reload-plugins` or start a new session; until then run `bash <repo>/plugins/teams-commander/bin/teams-commander` |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If a check drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
