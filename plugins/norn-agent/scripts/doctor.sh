#!/usr/bin/env bash
set -euo pipefail

runtime_dir="${NORN_RUNTIME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/norn}"
if [[ ! -x "$runtime_dir/.venv/bin/norn" ]]; then
  echo "Norn is not installed. Run /norn-agent:setup first." >&2
  exit 1
fi

"$runtime_dir/.venv/bin/norn" route "check git status" --json
if command -v argus >/dev/null 2>&1; then
  echo "Argus: installed"
else
  echo "Argus: not found (install separately if model-backed execution is needed)"
fi
if command -v agent_s >/dev/null 2>&1; then
  echo "Agent-S: installed"
else
  echo "Agent-S: not found (optional; required only for GUI tasks)"
fi
