---
name: install
description: Use when the user wants to install, customize, or remove the custom-statusline plugin's status line via scripts/install.sh. TRIGGERS - custom statusline, build my statusline, status line setup
allowed-tools: Read, Bash
---

# Install the custom status line

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## What this does

Installs the `custom-statusline` plugin's multi-line status line into
`~/.claude/settings.json`, backing up whatever `statusLine` configuration was
there before, and points to which of its 8 segments render and why.

## Execution

### 1. Install

```bash
ROOT="$(skills-plugin-root custom-statusline)"
bash "$ROOT/scripts/install.sh" install
```

This backs up any existing `statusLine` block in `~/.claude/settings.json`
(timestamped, alongside the original) and points it at this plugin's
`scripts/statusline.sh`. Preview the change first with no writes:

```bash
bash "$ROOT/scripts/install.sh" install --dry-run
```

### 2. Check what's active

```bash
bash "$ROOT/scripts/install.sh" status
```

Prints the current `statusLine` command and whether it already points at
this plugin.

### 3. Customize which segments render

Read `references/segments.md` for what each of the 8 segments shows and
which `gh` scopes, if any, it needs. Segments degrade gracefully — a missing
scope or unreachable network just omits that piece, never an error. To
disable a segment for this user, comment out its `source` line in
`scripts/statusline.sh` — a per-user preference edited directly, not a
config flag (see `CLAUDE.md` for why cross-plugin config flags aren't used
here).

### 4. Uninstall

```bash
bash "$ROOT/scripts/install.sh" uninstall
```

Restores the most recent backup, or clears the `statusLine` field entirely
if none exists.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `jq: command not found` | `jq` isn't installed | Install it (`brew install jq`) — required by both `install.sh` and `scripts/statusline.sh` itself |
| Status line shows nothing | `~/.claude/settings.json` wasn't reloaded | Restart the Claude Code session |
| Deployment/package lines never appear | Repo has no GitHub Deployments/Packages, or the `gh` token lacks `read:packages` | Expected — those segments render only when there's real data; see `references/segments.md` |
