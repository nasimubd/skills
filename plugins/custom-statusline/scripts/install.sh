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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATUSLINE_SCRIPT="$PLUGIN_ROOT/scripts/statusline.sh"
SETTINGS_FILE="${CUSTOM_STATUSLINE_SETTINGS_FILE:-$HOME/.claude/settings.json}"

if ! command -v jq >/dev/null 2>&1; then
  echo "install.sh: jq is required but not on PATH" >&2
  exit 1
fi

# Backs up $SETTINGS_FILE to a timestamped sibling before install overwrites
# it. Returns the backup path on stdout; prints nothing (and does not fail)
# when there's no file to back up yet.
backup_settings_file() {
  [[ -f "$SETTINGS_FILE" ]] || return 0
  local backup_path
  backup_path="${SETTINGS_FILE}.custom-statusline-backup.$(date +%Y%m%dT%H%M%S)"
  cp "$SETTINGS_FILE" "$backup_path"
  printf '%s' "$backup_path"
}

# Most recent backup for $SETTINGS_FILE, or empty if none exists.
latest_backup_path() {
  # nullglob so a non-matching pattern expands to zero words instead of the
  # literal glob string; local so the shopt change doesn't leak past this
  # function even though it isn't scoped by `local` semantics elsewhere.
  local backups
  shopt -s nullglob
  backups=("${SETTINGS_FILE}".custom-statusline-backup.*)
  shopt -u nullglob

  [[ "${#backups[@]}" -gt 0 ]] || return 0
  printf '%s\n' "${backups[@]}" | sort -r | head -1
}

run_status() {
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "status: $SETTINGS_FILE does not exist yet — nothing installed"
    return 0
  fi

  local current_command
  current_command="$(jq -r '.statusLine.command // empty' "$SETTINGS_FILE" 2>/dev/null)"
  if [[ -z "$current_command" ]]; then
    echo "status: no statusLine configured in $SETTINGS_FILE"
  elif [[ "$current_command" == "$STATUSLINE_SCRIPT" ]]; then
    echo "status: custom-statusline is installed and active"
    echo "  command: $current_command"
  else
    echo "status: a different statusLine is active"
    echo "  command: $current_command"
  fi
}

run_install() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "install (dry-run): would point statusLine at $STATUSLINE_SCRIPT"
    [[ -f "$SETTINGS_FILE" ]] && echo "install (dry-run): would back up $SETTINGS_FILE first"
    return 0
  fi

  mkdir -p "$(dirname "$SETTINGS_FILE")"

  # Back up whatever is really there BEFORE deciding what the base JSON is —
  # otherwise a fresh-install stub written two lines below gets backed up as
  # if it were a real prior config, and the "previous config backed up"
  # message becomes misleading.
  local backup_path=""
  backup_path="$(backup_settings_file)"

  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo '{}' >"$SETTINGS_FILE"
  elif ! jq -e . "$SETTINGS_FILE" >/dev/null 2>&1; then
    # Malformed existing JSON: the backup above already preserved it, so
    # self-heal by starting the patch from an empty object rather than
    # aborting with jq's raw parse error.
    echo "install: $SETTINGS_FILE was not valid JSON — starting fresh (original preserved in backup)" >&2
    echo '{}' >"$SETTINGS_FILE"
  fi

  local updated_json
  updated_json="$(jq --arg cmd "$STATUSLINE_SCRIPT" \
    '.statusLine = {"type": "command", "command": $cmd, "padding": 0}' \
    "$SETTINGS_FILE")"
  printf '%s\n' "$updated_json" >"$SETTINGS_FILE"

  echo "install: statusLine now points at $STATUSLINE_SCRIPT"
  [[ -n "$backup_path" ]] && echo "install: previous config backed up to $backup_path"
}

run_uninstall() {
  if [[ ! -f "$SETTINGS_FILE" ]]; then
    echo "uninstall: $SETTINGS_FILE does not exist — nothing to do"
    return 0
  fi

  local backup_path
  backup_path="$(latest_backup_path)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    if [[ -n "$backup_path" ]]; then
      echo "uninstall (dry-run): would restore $SETTINGS_FILE from $backup_path"
    else
      echo "uninstall (dry-run): no backup found — would clear statusLine instead"
    fi
    return 0
  fi

  if [[ -n "$backup_path" ]]; then
    cp "$backup_path" "$SETTINGS_FILE"
    echo "uninstall: restored $SETTINGS_FILE from $backup_path"
  else
    local updated_json
    updated_json="$(jq 'del(.statusLine)' "$SETTINGS_FILE")"
    printf '%s\n' "$updated_json" >"$SETTINGS_FILE"
    echo "uninstall: no backup found — cleared statusLine instead"
  fi
}

case "$ACTION" in
  install) run_install ;;
  uninstall) run_uninstall ;;
  status) run_status ;;
esac
