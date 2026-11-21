---
name: health
description: Use when change-guardrails misbehaves or after installing it. Checks jq, both rules files, a live self-test and the audit folder. TRIGGERS - guardrails health, guard not working, hook not firing
allowed-tools: Bash
---

# Check change-guardrails health

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

```bash
change-guardrails health
```

It prints one line per check and a count (`Checked: N · failed: M`); exit 0 only when
every check passed. Report each failure with its fix, not just the count.

A missing `jq` is the failure that matters most: the hook then fails open and guards
nothing, silently. The self-test line proves a certain-to-be-caught command is stopped, so
a disabled core rule shows up here.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `jq not found` | jq not installed | Install jq (`brew install jq` or the distribution's package) |
| Rules files have problems | A malformed line, an invalid pattern, a duplicate id, or `disable` in the shipped file | Fix the line named in the output; until then every command asks |
| Self-test failed | The user disabled `push-force-protected` and `git-force-push` | Remove the `disable@@` lines if that was not intended |
| Audit folder not writable | Permissions on the state folder | Fix them; decisions are still enforced, only the log is lost |
| Hook never fires | Plugin not enabled, or enabled mid-session | `/reload-plugins` or start a new session; check with `/hooks` |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If a check drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
