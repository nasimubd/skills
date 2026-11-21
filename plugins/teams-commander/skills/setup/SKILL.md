---
name: setup
description: Use when the user wants to set up teams-commander or add, change or list Teams contacts, the tenant id or message style. Writes only local files. TRIGGERS - teams contacts, teams style
allowed-tools: Bash, Read
argument-hint: [alias email]
---

# Set up teams-commander

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

Contacts map a short alias to the person's Microsoft Entra user principal name (UPN,
usually their work email). They live in `~/.config/teams-commander/contacts.json` on
this machine only and are never committed.

## Execution

```bash
teams-commander contact list
```

### Add a person

Confirm the UPN at the source before saving: from a message the person sent
(Microsoft 365 connector, read-only), the directory, or the user telling you. Do not
guess an address from a name.

```bash
teams-commander contact add jona jona@example.com --name "Jona"
```

### Add a group chat

List every participant except the user; `--topic` names the chat when it has three
or more people.

```bash
teams-commander contact add ops a@example.com,b@example.com --topic "Ops review"
```

### Optional: tenant id

Only needed if links land in the wrong organisation.

```bash
teams-commander contact tenant <tenant-guid>
```

### Optional: message style

Personal style rules are stored in `~/.config/teams-commander/style.json` (this machine
only, never committed) and enforced by `verify`: a message that breaks them cannot be
opened. Set one when the user corrects a draft, not before.

```bash
teams-commander style show                                   # current settings
teams-commander style bold never                             # refuse **bold** markers
teams-commander style ban POC --use "engagement letter"      # refuse a word, say what to write
teams-commander style unban POC
```

Banned terms match whole words, in any case; a term may be several words.

Finish with the `health` skill.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `not an email/UPN` | Typo or display name given | Use the address exactly as in the directory |
| `alias must be lowercase` | Capitals or spaces | Use `jona`, `alex`, `ops-review` |
| `verify` refuses with `style:` lines | A style rule matched the message | Fix the message, or change the rule with `style unban` / `style bold allow` |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If the CLI drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
