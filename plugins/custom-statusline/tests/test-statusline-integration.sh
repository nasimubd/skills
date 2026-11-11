#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

assert_exit_zero() {
  local desc="$1" payload="$2"
  # `if pipeline; then` is exempt from set -e — the pipeline's failure is the
  # thing under test here, not a real script error.
  if printf '%s' "$payload" | bash "$PLUGIN_ROOT/scripts/statusline.sh" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $desc: exited non-zero, expected 0"
  fi
}

assert_exit_zero "empty payload" "{}"
assert_exit_zero "malformed payload" "not json"
assert_exit_zero "empty stdin" ""

FULL_PAYLOAD='{"session_id":"3e83be9e-2559-4c75-869f-a65a883d85d1","model":{"display_name":"Sonnet 5"},"context_window":{"total_input_tokens":42000,"context_window_size":100000},"cost":{"total_cost_usd":1.5,"total_duration_ms":60000}}'
OUTPUT="$(printf '%s' "$FULL_PAYLOAD" | bash "$PLUGIN_ROOT/scripts/statusline.sh")"

# statusline.sh renders the working directory with $HOME shown as ~; expect exactly that
# for wherever the suite runs, not one machine's checkout path.
EXPECTED_PATH="$(pwd | sed "s|$HOME|~|")"
if [[ "$OUTPUT" == *"$EXPECTED_PATH"* ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ output missing repository path: $OUTPUT"
fi

if [[ "$OUTPUT" == *"Sonnet 5"* ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ output missing model name: $OUTPUT"
fi

if [[ "$OUTPUT" == *"42%"* ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ output missing context percentage: $OUTPUT"
fi

# Claude Code spawns the statusLine command with a minimal PATH, not the
# interactive shell's, and `gh` lives only at a Homebrew-style path. Reproduce
# that condition hermetically: a stub `gh` under a scratch $HOME/.local/bin
# (one of the directories statusline.sh adds to PATH), a scratch repo with a
# GitHub origin so the visibility cache starts empty, and PATH=/usr/bin:/bin.
# The visibility badge must still render. This also covers macOS, which ships
# no `timeout` command: the lookup must not depend on one.
SCRATCH="$(mktemp -d)"
mkdir -p "$SCRATCH/home/.local/bin" "$SCRATCH/repo"
printf '#!/bin/sh\necho public\n' > "$SCRATCH/home/.local/bin/gh"
chmod +x "$SCRATCH/home/.local/bin/gh"
git -C "$SCRATCH/repo" init -q
git -C "$SCRATCH/repo" remote add origin https://github.com/example/repo.git
MINIMAL_PATH_OUTPUT="$(cd "$SCRATCH/repo" && printf '%s' '{}' |
  env -i HOME="$SCRATCH/home" PATH="/usr/bin:/bin" bash "$PLUGIN_ROOT/scripts/statusline.sh")"
rm -rf "$SCRATCH"

if [[ "$MINIMAL_PATH_OUTPUT" == *"[public]"* ]]; then
  PASS=$((PASS + 1))
else
  FAIL=$((FAIL + 1))
  echo "  ✗ visibility badge missing under a minimal PATH: '$MINIMAL_PATH_OUTPUT'"
fi

echo "test-statusline-integration.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
