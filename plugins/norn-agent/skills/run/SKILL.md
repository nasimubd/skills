---
name: run
description: Use when the user asks Norn to route and execute a natural-language task through approved tools, models, Agent-S, or human approval. TRIGGERS - run with Norn, execute task with Norn, Norn task
allowed-tools: Read, Bash
argument-hint: [natural-language task]
---

# Run a Norn task

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Safety

Norn chooses the smallest suitable executor, but a route decision is not proof that an action is safe. Show the route and confidence before privileged, destructive, network, or GUI actions. Keep approval gates enabled unless the user has explicitly configured a trusted workflow.

## Execution

```bash
ROOT="$(skills-plugin-root norn-agent)"
RUNTIME_DIR="${NORN_RUNTIME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/norn}"
if [[ ! -x "$RUNTIME_DIR/.venv/bin/norn" ]]; then
  bash "$ROOT/scripts/setup.sh"
fi
"$RUNTIME_DIR/.venv/bin/norn" route "$ARGUMENTS" --json
```

The current foundation reports the route and does not silently execute privileged work. Future executors must preserve the same policy and audit contracts.

## Post-Execution Reflection

Record whether the selected route was appropriate, whether verification was available, and any reproducible runtime drift.
