#!/usr/bin/env bash
set -euo pipefail
runtime_dir="${NORN_RUNTIME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/norn}"
if [[ -d "$runtime_dir" ]]; then
  echo "Norn runtime remains at $runtime_dir. Remove it manually after reviewing the path."
else
  echo "Norn runtime is not installed."
fi
