#!/usr/bin/env bash
# Install/uninstall/status for the custom-statusline plugin's statusLine
# entry in ~/.claude/settings.json.
set -euo pipefail

print_usage() {
  cat <<'USAGE'
usage: install.sh <install|uninstall|status> [--dry-run]
USAGE
}

if [[ $# -lt 1 ]]; then
  print_usage >&2
  exit 1
fi
