#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/configure-codex-statusline.sh"
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
CONFIG="$SCRATCH/config.toml"

printf '%s\n' 'model = "test"' '' '[tui]' 'theme = "dark"' '' '[projects."/tmp"]' 'trust_level = "trusted"' >"$CONFIG"

CUSTOM_STATUSLINE_CONFIG_FILE="$CONFIG"
CODEX_CONFIG_FILE="$CONFIG" bash "$SCRIPT" install >/dev/null
grep -F 'status_line = ["current-dir", "git-branch", "model-with-reasoning", "context-used"]' "$CONFIG" >/dev/null
grep -F 'trust_level = "trusted"' "$CONFIG" >/dev/null

CODEX_CONFIG_FILE="$CONFIG" bash "$SCRIPT" status | grep -F 'configured' >/dev/null
CODEX_CONFIG_FILE="$CONFIG" bash "$SCRIPT" uninstall >/dev/null
grep -F 'theme = "dark"' "$CONFIG" >/dev/null
! grep -F 'status_line =' "$CONFIG"

echo 'test-configure-codex-statusline.sh: passed'
