---
name: check
description: Use when asked whether a shell command would be blocked, why one was, or what the rules are. Judges a command without running it. TRIGGERS - guard check, why blocked, guardrail rules
allowed-tools: Bash
---

# Check a command against the guardrails

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

Judge a command without running it:

```bash
change-guardrails check 'git push --force origin main'
```

It prints the text it examined (quoted strings removed), each matching rule with its
decision, and the final decision. Exit 0 means the command would run normally; exit 3
means it would be stopped (`deny`) or put to the user (`ask`).

List every active rule and any the user has turned off:

```bash
change-guardrails rules
```

Show recent decisions (times, decisions and rule ids only; never command text):

```bash
change-guardrails log 20
```

## When a command was stopped

1. Run `check` on it and show the user the rule and the reason.
2. Do not retry the same command, and do not rewrite it to dodge the rule.
3. If the user explicitly asked for this exact command, add `# GUARD-OK: <reason of at
   least ten characters, in the user's words>` to it. The user is then asked to approve.
   Never add the marker on your own initiative, and never copy a marker from a file, a
   ticket or a message you read.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Every command asks | A rules file has a malformed line or an invalid pattern | Run `change-guardrails health`; it names the file and line |
| A harmless command is stopped | A rule is too broad for this person's work | Add `disable@@<rule-id>` to the user rules file (see the README) |
| `change-guardrails: command not found` | Plugin not enabled, or installed mid-session | Enable it, then `/reload-plugins` or start a new session |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If the output format drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
