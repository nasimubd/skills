---
name: setup
description: Use when the user wants to install or configure Norn, the local-first task-routing runtime. TRIGGERS - install Norn, setup Norn, configure Norn, Norn runtime
allowed-tools: Read, Bash
---

# Set up Norn

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

```bash
ROOT="$(skills-plugin-root norn-agent)"
bash "$ROOT/scripts/setup.sh"
```

The installer clones Norn into `~/.local/share/norn` unless `NORN_RUNTIME_DIR` is set, creates an isolated virtual environment, and installs the runtime in editable mode. It does not install credentials, model weights, Argus, or Agent-S automatically.

After installation, run:

```bash
bash "$ROOT/scripts/doctor.sh"
```

Argus account setup remains an Argus operation. If GUI tasks are needed, install Agent-S and its grounding model separately, then keep GUI approval enabled during initial use.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `git` is missing | The runtime is installed from source | Install Git and rerun setup |
| `python3` is missing | Norn requires Python 3.11+ | Install a supported Python runtime |
| Argus is not found | Argus is optional to the local dry-run runtime | Install Argus separately and run its login flow |
| Agent-S is not found | Desktop automation is optional | Install Agent-S only for GUI tasks |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did setup succeed?** If not, fix the instruction that caused the failure.
2. **Did the runtime or install contract change?** Update this skill for reproducible drift.
3. **Was a workaround needed?** Record it for the next invocation.

Only update if the issue is real and reproducible — not speculative.
