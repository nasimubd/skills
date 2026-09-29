#!/usr/bin/env bash
# Regression tests for scripts/install.sh. Every test runs against a scratch
# settings.json under CUSTOM_STATUSLINE_SETTINGS_FILE — never the real
# ~/.claude/settings.json.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_SCRIPT="$PLUGIN_ROOT/scripts/install.sh"

PASS_COUNT=0
FAIL_COUNT=0

assert_eq() {
  local description="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  ✗ $description"
    echo "    expected: $expected"
    echo "    actual:   $actual"
  fi
}

assert_contains() {
  local description="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  ✗ $description"
    echo "    expected to contain: $needle"
    echo "    actual: $haystack"
  fi
}

echo "test-install: starting"
