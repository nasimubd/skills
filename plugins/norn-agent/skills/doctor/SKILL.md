---
name: doctor
description: Use when the user wants to verify Norn, Argus, decision-model, or Agent-S readiness without executing a task. TRIGGERS - Norn doctor, Norn status, check Norn installation
allowed-tools: Read, Bash
---

# Verify Norn

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

```bash
ROOT="$(skills-plugin-root norn-agent)"
bash "$ROOT/scripts/doctor.sh"
```

The doctor command performs a local dry-run route and reports optional Argus and Agent-S availability. It must not execute a user task or open a desktop application.

## Post-Execution Reflection

After this skill completes, check whether the reported state matches the installed runtime. Fix only reproducible drift.
