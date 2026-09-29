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
