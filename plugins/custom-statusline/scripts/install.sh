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

ACTION="$1"
shift
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *)
      echo "install.sh: unknown argument: $arg" >&2
      print_usage >&2
      exit 1
      ;;
  esac
done

case "$ACTION" in
  install | uninstall | status) ;;
  *)
    echo "install.sh: unknown action: $ACTION" >&2
    print_usage >&2
    exit 1
    ;;
esac
