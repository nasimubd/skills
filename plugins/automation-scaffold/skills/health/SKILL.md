---
name: health
description: Use when automation-scaffold fails or before a scaffold. Checks git, gh, node, mise, az tokens, n8n and Make access and the config, one line each. TRIGGERS - scaffold health, scaffold not working
allowed-tools: Bash
---

# Check automation-scaffold health

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

```bash
automation-scaffold health
```

One line per check (✓ passed, ✗ required and failed, ! optional and missing), then
`Checked: N · failed: M · optional missing: K`. Exit 0 only when every required check
passed. Read-only: it requests tokens and lists one n8n workflow, and never prints a secret.

Report each ✗ with the fix it names. Platforms that are not configured are optional:
discovery simply does not examine them, and says so.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Power Apps / Power Automate token fails | Azure sign-in expired or needs MFA | The user runs `! az login` |
| n8n API not reachable | Wrong URL, key, or the API is disabled on the plan | Check `n8n.url` and the Keychain item |
| `gh signed in` fails | No GitHub login | The user runs `! gh auth login` |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If a check drifted, update `scripts/health.sh` and this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
