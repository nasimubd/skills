#!/usr/bin/env bash
set -euo pipefail
runtime_dir="${NORN_RUNTIME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/norn}"
if [[ -x "$runtime_dir/.venv/bin/python" ]]; then
  "$runtime_dir/.venv/bin/python" -c 'import importlib.metadata; print(importlib.metadata.version("norn-runtime"))'
else
  echo "not-installed"
fi
