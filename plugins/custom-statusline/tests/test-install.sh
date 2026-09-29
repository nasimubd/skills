#!/usr/bin/env bash
# Regression tests for scripts/install.sh. Every test runs against a scratch
# settings.json under CUSTOM_STATUSLINE_SETTINGS_FILE — never the real
# ~/.claude/settings.json. Auto-discovered by
# test-marketplace-hook-regression-suite.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$PLUGIN_ROOT/scripts/install.sh"

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $desc: expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $desc: expected to contain '$needle', got '$haystack'"
  fi
}

# Fresh scratch settings file per test, never the real one.
new_scratch_settings() {
  local dir
  dir="$(mktemp -d)"
  printf '%s/settings.json' "$dir"
}

# status on a settings file that doesn't exist yet.
SCRATCH="$(new_scratch_settings)"
OUTPUT="$(CUSTOM_STATUSLINE_SETTINGS_FILE="$SCRATCH" bash "$INSTALL_SCRIPT" status)"
assert_contains "status reports nothing installed on missing file" "$OUTPUT" "does not exist yet"

# install against a settings file that doesn't exist yet.
SCRATCH="$(new_scratch_settings)"
CUSTOM_STATUSLINE_SETTINGS_FILE="$SCRATCH" bash "$INSTALL_SCRIPT" install >/dev/null
INSTALLED_COMMAND="$(jq -r '.statusLine.command' "$SCRATCH")"
assert_eq "install points statusLine at this plugin's script" \
  "$PLUGIN_ROOT/scripts/statusline.sh" "$INSTALLED_COMMAND"

# status after install reports this plugin is active.
STATUS_OUTPUT="$(CUSTOM_STATUSLINE_SETTINGS_FILE="$SCRATCH" bash "$INSTALL_SCRIPT" status)"
assert_contains "status reports active after install" "$STATUS_OUTPUT" "is installed and active"

# install backs up a genuinely prior config.
SCRATCH="$(new_scratch_settings)"
printf '{"statusLine":{"command":"/prior.sh"},"keepMe":true}' >"$SCRATCH"
CUSTOM_STATUSLINE_SETTINGS_FILE="$SCRATCH" bash "$INSTALL_SCRIPT" install >/dev/null
BACKUP_COUNT="$(compgen -G "${SCRATCH}.custom-statusline-backup.*" | wc -l | tr -d ' ')"
assert_eq "install creates exactly one backup of a real prior config" "1" "$BACKUP_COUNT"
BACKUP_FILE="$(compgen -G "${SCRATCH}.custom-statusline-backup.*")"
assert_eq "backup preserves the prior command" "/prior.sh" "$(jq -r '.statusLine.command' "$BACKUP_FILE")"
assert_eq "install preserves unrelated keys" "true" "$(jq -r '.keepMe' "$SCRATCH")"

# --dry-run makes no changes and creates no backup.
SCRATCH="$(new_scratch_settings)"
printf '{"statusLine":{"command":"/prior.sh"}}' >"$SCRATCH"
BEFORE_HASH="$(shasum "$SCRATCH")"
CUSTOM_STATUSLINE_SETTINGS_FILE="$SCRATCH" bash "$INSTALL_SCRIPT" install --dry-run >/dev/null
AFTER_HASH="$(shasum "$SCRATCH")"
assert_eq "dry-run install leaves settings.json byte-identical" "$BEFORE_HASH" "$AFTER_HASH"
DRY_RUN_BACKUP_COUNT="$(compgen -G "${SCRATCH}.custom-statusline-backup.*" | wc -l | tr -d ' ')"
assert_eq "dry-run install creates no backup" "0" "$DRY_RUN_BACKUP_COUNT"

# uninstall restores the most recent backup.
SCRATCH="$(new_scratch_settings)"
printf '{"statusLine":{"command":"/prior.sh"}}' >"$SCRATCH"
CUSTOM_STATUSLINE_SETTINGS_FILE="$SCRATCH" bash "$INSTALL_SCRIPT" install >/dev/null
CUSTOM_STATUSLINE_SETTINGS_FILE="$SCRATCH" bash "$INSTALL_SCRIPT" uninstall >/dev/null
RESTORED_COMMAND="$(jq -r '.statusLine.command' "$SCRATCH")"
assert_eq "uninstall restores the prior command" "/prior.sh" "$RESTORED_COMMAND"

# uninstall with no backup present clears the statusLine field instead.
SCRATCH="$(new_scratch_settings)"
printf '{"statusLine":{"command":"/prior.sh"},"keepMe":true}' >"$SCRATCH"
CUSTOM_STATUSLINE_SETTINGS_FILE="$SCRATCH" bash "$INSTALL_SCRIPT" uninstall >/dev/null
assert_eq "uninstall with no backup clears statusLine" \
  "null" "$(jq -r '.statusLine // "null"' "$SCRATCH")"
assert_eq "uninstall with no backup preserves unrelated keys" \
  "true" "$(jq -r '.keepMe' "$SCRATCH")"

echo "test-install.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
