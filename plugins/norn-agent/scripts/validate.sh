#!/usr/bin/env bash
set -euo pipefail
runtime_dir="${NORN_RUNTIME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/norn}"
[[ -x "$runtime_dir/.venv/bin/norn" ]] || { echo "Norn is not installed" >&2; exit 1; }
"$runtime_dir/.venv/bin/norn" route "check git status" --json >/dev/null
echo "Norn validation passed"
