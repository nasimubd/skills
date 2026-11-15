---
name: cloudflare-operator
description: Use when inspecting or safely managing Cloudflare zones, DNS, and domain infrastructure through the REST API. TRIGGERS - Cloudflare, DNS, zone, SPF, DKIM, MX, webhook hostname.
allowed-tools: Read, Bash
---
# Cloudflare Operator

> **Self-Evolving Skill**: Improve this skill when a real, reproducible API or provider issue is found.

Inspect the account, zone, and current records before proposing changes. Prefer a scoped API token for one account. Use OAuth only for a hosted multi-user application needing delegated access. Verify records after mutations. Never expose credentials. Ask before deleting records, changing zone-wide settings, certificates, or bulk changes.

Use `cloudflare-operator health`, `zones`, and `dns` for discovery. Preserve Postal MX, SPF, DKIM, and return-path records unless an approved plan changes them.

## Post-Execution Reflection

Verify resulting records and record reproducible provider drift.
