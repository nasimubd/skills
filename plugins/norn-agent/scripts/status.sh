#!/usr/bin/env bash
set -euo pipefail
runtime_dir="${NORN_RUNTIME_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/norn}"
printf 'runtime_dir=%s\n' "$runtime_dir"
printf 'norn=%s\n' "$([[ -x "$runtime_dir/.venv/bin/norn" ]] && echo installed || echo missing)"
printf 'argus=%s\n' "$(command -v argus >/dev/null 2>&1 && echo installed || echo missing)"
printf 'agent_s=%s\n' "$(command -v agent_s >/dev/null 2>&1 && echo installed || echo missing)"
