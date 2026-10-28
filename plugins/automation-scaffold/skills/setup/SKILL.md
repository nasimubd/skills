---
name: setup
description: Use when the user wants to configure automation-scaffold - GitHub owner, commit author, Power Platform environment, n8n, Make - or change those settings. Stores names and IDs, never secrets.
allowed-tools: Bash, Read
argument-hint: [key value]
---

# Set up automation-scaffold

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

Configuration lives in `~/.config/automation-scaffold/config.json` on this machine and is
never committed. It holds IDs, URLs and Keychain item **names**; the secrets themselves stay
in the macOS Keychain or environment variables.

## Execution

```bash
automation-scaffold setup show
```

There is no GitHub owner setting on purpose: the repository a scaffold uses is always given
by the user or asked for at run time, never configured or inferred.

Set what is missing, confirming each value at its source first (`gh api user`, the Power
Platform admin centre or `az`, the n8n URL in the browser). Never guess an ID.

```bash
automation-scaffold setup set workspaceDir <folder for clones>
automation-scaffold setup set author.name "<name>"
automation-scaffold setup set author.email <email>
automation-scaffold setup set powerPlatform.environmentId <Default-guid>
automation-scaffold setup set powerPlatform.environmentName "<display name>"
automation-scaffold setup set n8n.url https://<instance>.app.n8n.cloud
automation-scaffold setup set n8n.keychainItem <keychain item name>
automation-scaffold setup set make.zone eu1.make.com          # only if Make is used
automation-scaffold setup set make.teamId <team id>
automation-scaffold setup set make.keychainItem <keychain item name>
automation-scaffold setup set azBin <path to az>               # only if az is not on PATH
```

The n8n key and Make token go into the Keychain by the **user**, never through chat:

> Please run `! security add-generic-password -s <item name> -a "$USER" -w` and paste the key
> at the prompt.

Finish with the `health` skill.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `that looks like a secret` | A key or token was given as a value | Put it in the Keychain; set the item name |
| `unknown key` | Typo | `setup show` lists the keys in use; the header of `scripts/setup.sh` lists all |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If a key was added or renamed, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
