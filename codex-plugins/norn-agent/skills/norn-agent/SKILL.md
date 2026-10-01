---
name: norn-agent
description: Install and use Norn, a local-first runtime that routes natural-language tasks across deterministic tools, decision models, Argus, Agent-S, and approval gates.
---

# Norn for Codex

Use the repository's setup and doctor scripts before routing a task. Norn is an execution layer above Argus; it does not replace Argus account management.

```bash
RUNTIME_DIR="${NORN_RUNTIME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/norn}"
if [[ ! -x "$RUNTIME_DIR/.venv/bin/norn" ]]; then
  git clone https://github.com/nasimubd/norn.git "$RUNTIME_DIR"
  python3 -m venv "$RUNTIME_DIR/.venv"
  "$RUNTIME_DIR/.venv/bin/python" -m pip install -e "$RUNTIME_DIR"
fi
"$RUNTIME_DIR/.venv/bin/norn" route "$1" --json
```

Show the route before any privileged action. Keep GUI approval enabled and use Agent-S only when the route explicitly requires visual desktop interaction.
