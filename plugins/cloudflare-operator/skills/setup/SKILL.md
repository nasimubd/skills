---
name: setup
description: Use when configuring or checking Cloudflare Operator.
allowed-tools: Bash, Read
---
# Setup

> **Self-Evolving Skill**: Improve this skill when a real, reproducible issue is found.

Set `CLOUDFLARE_API_TOKEN` in the secret store. Prefer a zone-scoped token with Zone Read, DNS Read, and DNS Edit. Run `cloudflare-operator health` before zone lookup.

## Post-Execution Reflection

Record only verified results.
