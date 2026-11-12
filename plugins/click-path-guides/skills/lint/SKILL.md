---
name: lint
description: Use when asked to check, review or fix an existing click-path guide against an app definition. Reports each finding with its line. TRIGGERS - lint guide, check click path, verify UI steps
allowed-tools: Read, Edit, Bash
---

# Check an existing click-path guide

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

```bash
click-path-guides lint <guide.md> --source <definition> [--keys label,title,text]
```

It prints what it examined, then one finding per problem as `guide:LINE: rule: message`, and a
summary. Exit 0 means no findings; exit 3 means findings; exit 1 means the source could not be
read (missing, an image, or no labels).

Report the findings with their lines. If the user asks you to fix the guide, change only what
the findings name: replace a wrong label with the source's spelling (list them with
`click-path-guides labels <definition>`), reformat menu paths, remove position or colour
wording. Never add a label to make the lint pass; if a control is not in the source, say so.

| Rule | Meaning |
|---|---|
| `ui-label-unverified` | A bold term is not a label in the source |
| `menu-separator`, `menu-bold` | Menu path not written as `**File** > **Open**` |
| `sensory-language` | A control identified by position, colour, shape or size |
| `filler-word`, `placeholder` | Filler such as "simply", or an unfilled placeholder or TODO |
| `prerequisites-missing`, `step-number`, `no-steps` | Structure: prerequisites first, steps numbered 1, 2, 3, at least one step |

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Every bold term fails | Wrong source file or wrong `--keys` | Run `labels` on the source and compare |
| A host-application menu fails | The definition cannot hold it | Ask the user; if they agree use `--allow` and list it as not verified |
| `click-path-guides: command not found` | Plugin not enabled, or installed mid-session | Enable it, then `/reload-plugins` or start a new session |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If a rule changed, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
