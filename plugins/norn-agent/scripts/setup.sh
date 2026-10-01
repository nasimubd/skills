#!/usr/bin/env bash
set -euo pipefail

runtime_dir="${NORN_RUNTIME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/norn}"
runtime_repo="${NORN_RUNTIME_REPO:-https://github.com/nasimubd/norn.git}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

if [[ ! -d "$runtime_dir/.git" ]]; then
  mkdir -p "$(dirname "$runtime_dir")"
  git clone "$runtime_repo" "$runtime_dir"
else
  git -C "$runtime_dir" fetch --tags --quiet
  git -C "$runtime_dir" pull --ff-only --quiet
fi

python3 -m venv "$runtime_dir/.venv"
"$runtime_dir/.venv/bin/python" -m pip install --quiet --upgrade pip
"$runtime_dir/.venv/bin/python" -m pip install --quiet -e "$runtime_dir"
echo "Norn installed at $runtime_dir"
echo "Run /norn-agent:doctor to verify Argus and optional executors."
