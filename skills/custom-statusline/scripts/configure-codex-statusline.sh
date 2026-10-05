#!/usr/bin/env bash
# Install/uninstall/status for the Codex TUI footer configuration.
set -euo pipefail

usage() {
  echo "usage: configure-codex-statusline.sh <install|uninstall|status> [--dry-run]" >&2
}

ACTION="${1:-}"
shift || true
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) usage; exit 1 ;;
  esac
done

case "$ACTION" in install|uninstall|status) ;; *) usage; exit 1 ;; esac

CONFIG_FILE="${CODEX_CONFIG_FILE:-${CODEX_HOME:-$HOME/.codex}/config.toml}"
BACKUP_PREFIX="${CONFIG_FILE}.custom-statusline-backup."
STATUS_ITEMS='["current-dir", "git-branch", "model-with-reasoning", "context-used"]'

latest_backup() {
  local candidate
  candidate="$(find "$(dirname "$CONFIG_FILE")" -maxdepth 1 -type f -name "$(basename "$BACKUP_PREFIX")*" -print 2>/dev/null | sort | tail -1)"
  [[ -n "$candidate" ]] && printf '%s\n' "$candidate"
}

if [[ "$ACTION" == status ]]; then
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "status: $CONFIG_FILE does not exist yet — nothing installed"
  else
    python3 - "$CONFIG_FILE" <<'PY_STATUS'
import sys, tomllib
from pathlib import Path
value = tomllib.loads(Path(sys.argv[1]).read_text()).get("tui", {}).get("status_line")
if value is None:
    print("status: no Codex tui.status_line configuration found in " + sys.argv[1])
else:
    print("status: Codex custom status line is configured")
    print("  items: " + ", ".join(value))
PY_STATUS
  fi
  exit 0
fi

if [[ "$ACTION" == install ]]; then
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "install (dry-run): would configure tui.status_line in $CONFIG_FILE"
    [[ -f "$CONFIG_FILE" ]] && echo "install (dry-run): would back up $CONFIG_FILE first"
    exit 0
  fi

  if [[ -f "$CONFIG_FILE" ]]; then
    python3 - "$CONFIG_FILE" <<'VALIDATE'
import sys, tomllib
from pathlib import Path
tomllib.loads(Path(sys.argv[1]).read_text())
VALIDATE
  fi
  mkdir -p "$(dirname "$CONFIG_FILE")"
  if [[ -f "$CONFIG_FILE" ]]; then
    cp "$CONFIG_FILE" "${BACKUP_PREFIX}$(date +%Y%m%dT%H%M%S)"
  else
    printf '%s\n' '# Codex configuration' >"$CONFIG_FILE"
  fi

  python3 - "$CONFIG_FILE" "$STATUS_ITEMS" <<'PY'
import sys, tomllib
from pathlib import Path

path = Path(sys.argv[1])
value = sys.argv[2]
lines = path.read_text(encoding="utf-8").splitlines()
out = []
in_tui = False
replaced = False
iterator = iter(lines)
for line in iterator:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        if in_tui and not replaced:
            out.append(f"status_line = {value}")
            replaced = True
        in_tui = stripped == "[tui]"
    if in_tui and stripped.partition("=")[0].strip() == "status_line" and "=" in stripped:
        assignment = line
        while True:
            try:
                tomllib.loads(assignment)
                break
            except tomllib.TOMLDecodeError:
                assignment += "\n" + next(iterator)
        if not replaced:
            out.append(f"status_line = {value}")
            replaced = True
        continue
    out.append(line)
if in_tui and not replaced:
    out.append(f"status_line = {value}")
if not any(line.strip() == "[tui]" for line in lines):
    if out and out[-1] != "":
        out.append("")
    out.extend(["[tui]", f"status_line = {value}"])
path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
  echo "install: Codex status line configured in $CONFIG_FILE"
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  backup="$(latest_backup || true)"
  if [[ -n "$backup" ]]; then
    echo "uninstall (dry-run): would restore $CONFIG_FILE from $backup"
  else
    echo "uninstall (dry-run): no backup found — would remove status_line"
  fi
  exit 0
fi

backup="$(latest_backup || true)"
if [[ -n "$backup" ]]; then
  cp "$backup" "$CONFIG_FILE"
  echo "uninstall: restored $CONFIG_FILE from $backup"
elif [[ -f "$CONFIG_FILE" ]]; then
  python3 - "$CONFIG_FILE" <<'PY'
import sys, tomllib
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").splitlines()
out = []
in_tui = False
iterator = iter(lines)
for line in iterator:
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        in_tui = stripped == "[tui]"
    if in_tui and stripped.partition("=")[0].strip() == "status_line" and "=" in stripped:
        assignment = line
        while True:
            try:
                tomllib.loads(assignment)
                break
            except tomllib.TOMLDecodeError:
                assignment += "\n" + next(iterator)
        continue
    out.append(line)
path.write_text("\n".join(out).rstrip() + "\n", encoding="utf-8")
PY
  echo "uninstall: removed status_line from $CONFIG_FILE"
else
  echo "uninstall: $CONFIG_FILE does not exist — nothing to do"
fi
