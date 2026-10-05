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

if [[ "$OUTPUT" == *"~/skills"* ]]; then
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
# interactive shell's — `gh` lives only at a Homebrew/Linuxbrew path, unlike
# `jq`/`git` which ship system-wide. Reproduce that exact condition (a
# stripped PATH, a genuinely empty cache) against this repo's own release,
# which is known to always have at least one published tag, and assert the
# release segment still produces a real tag rather than going silently
# empty. Guarded: only meaningful on a machine where gh actually lives at
# one of the fallback locations statusline.sh searches.
if [[ -x /opt/homebrew/bin/gh || -x /usr/local/bin/gh ]]; then
  REPO_PAYLOAD='{"workspace":{"repo":{"owner":"nasimubd","name":"skills"}}}'
  CACHE_SCRATCH_DIR="$(mktemp -d)"
  MINIMAL_PATH_OUTPUT="$(env -i HOME="$HOME" PATH="/usr/bin:/bin" \
    CUSTOM_STATUSLINE_CACHE_DIR="$CACHE_SCRATCH_DIR" \
    bash -c "printf '%s' '$REPO_PAYLOAD' | bash '$PLUGIN_ROOT/scripts/statusline.sh'")"
  rm -rf "$CACHE_SCRATCH_DIR"

  if [[ "$MINIMAL_PATH_OUTPUT" =~ v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ release segment went empty under a minimal PATH: '$MINIMAL_PATH_OUTPUT'"
  fi
else
  echo "  ⓘ skipping minimal-PATH gh-resolution check — gh not found at a known fallback location"
fi

echo "test-statusline-integration.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
