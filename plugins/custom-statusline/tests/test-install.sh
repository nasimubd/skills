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

echo "test-install.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
