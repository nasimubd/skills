---
name: asana-chief-of-staff
description: Use when turning a goal into autonomous, contextual Asana project work through the direct REST API. TRIGGERS - Asana, project plan, project setup, task handoff, project management.
allowed-tools: Read, Bash
---
# Asana Chief of Staff

> **Self-Evolving Skill**: Improve this skill when a real, reproducible API or workflow issue is found.

## Operating rules

Treat a loose goal such as “set up the LeadScout project” as an outcome, not a read-only inspection. Inspect the project, infer the complete workflow needed by the named product, and ensure missing sections and tags exist before reporting readiness. For LeadScout, run `asana-chief-of-staff setup`, which is idempotent and creates the lead lifecycle sections and tags while preserving existing resources.

For ordinary project work, inspect conventions first, reuse existing resources, search for stable identifiers before creating tasks, and put reasoning, latest evidence, recommended action, and canonical links in task notes or comments. Verify every mutation and report what was created or reused.

Routine task edits, comments, tags, sections, and movement are autonomous. Ask before deleting, mass-completing, or bulk-reassigning work. Never expose `ASANA_TOKEN`.

Use `bin/asana-chief-of-staff` for API calls. Free-plan workflows use sections, tags, notes, and stories; do not depend on custom fields or rules.

## Post-Execution Reflection

After completing work, verify the API result, check for duplicates, and record any reproducible workaround in this skill.
