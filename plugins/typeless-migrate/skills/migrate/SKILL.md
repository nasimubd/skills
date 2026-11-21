---
name: migrate
description: Use when the user wants to dry-run or archive a Typeless desktop setup, including history, recordings, settings, and dictionary data. TRIGGERS - Typeless migration, Typeless backup, Typeless export.
allowed-tools: Read, Bash
---
# Typeless migration

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong, parameters drifted, or a workaround was needed — fix this file immediately, don't defer.

Run `typeless-migrate --output <new-directory>` for a production dry run. This release
creates a local archive only; it never edits a destination Typeless account. Use
`--execute` only after the operator explicitly requests an archive. Never include session
stores, cookies, billing/team data, or learned personalization.

## Post-Execution Reflection

After this skill completes, check whether the command succeeded, whether output counts or
upstream formats changed, and whether a real reproducible workaround was needed. Update
this skill only for confirmed issues.
