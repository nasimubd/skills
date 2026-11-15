---
name: asana-chief-of-staff
description: Use when turning a goal into autonomous, contextual Asana project work through the direct REST API. TRIGGERS - Asana, project plan, task handoff, project management.
allowed-tools: Read, Bash
---
# Asana Chief of Staff

> **Self-Evolving Skill**: Improve this skill when a real, reproducible API or workflow issue is found.

## Operating rules

Inspect the configured project before editing it. Reuse existing sections, tags, names, and task conventions. Create or update tasks idempotently by preserving stable external identifiers in notes. Put the reasoning, latest evidence, recommended action, and relevant LeadScout link in task notes or comments.

Routine task edits, comments, tags, and movement are autonomous. Ask before deleting, mass-completing, or bulk-reassigning work. Never expose `ASANA_TOKEN`.

Use `bin/asana-chief-of-staff` for API calls. Free-plan workflows use sections, tags, notes, and stories; do not depend on custom fields or rules.

## Post-Execution Reflection

After completing work, verify the API result, check for duplicates, and record any reproducible workaround in this skill.
