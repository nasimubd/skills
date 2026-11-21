#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export NO_COLOR=1
source "$PLUGIN_ROOT/lib/segment-context.sh"

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

# The trigger estimate: window - 33,000 with no override.
assert_eq "200k window, no override" "167000" "$(context_compact_threshold 200000)"
assert_eq "1M window, no override" "967000" "$(context_compact_threshold 1000000)"
# An override only moves the trigger earlier, never later.
assert_eq "73% override on 200k" "131400" "$(context_compact_threshold 200000 73)"
assert_eq "an override above the default is ignored" "167000" "$(context_compact_threshold 200000 95)"
assert_eq "an invalid override is ignored" "167000" "$(context_compact_threshold 200000 lots)"
assert_eq "a smaller window cap applies first" "$(((500000 - 20000) * 73 / 100))" \
  "$(context_compact_threshold 1000000 73 500000)"
assert_eq "a cap above the window is ignored" "167000" "$(context_compact_threshold 200000 "" 900000)"
assert_eq "a tiny window never goes negative" "0" "$(context_compact_threshold 10000)"

assert_eq "format 60k" "60k" "$(format_tokens 60000)"
assert_eq "format 1M" "1M" "$(format_tokens 1000000)"
assert_eq "format 1500k" "1500k" "$(format_tokens 1500000)"
assert_eq "format small" "900" "$(format_tokens 900)"

payload() { printf '{"context_window":{"used_percentage":%s,"total_input_tokens":%s,"context_window_size":%s}}' "$1" "$2" "$3"; }
assert_eq "30% of 200k with the override" \
  "ctx ▕██████·······|≈≈≈≈≈≈≈▏ 30% · 60k/200k · ~71k until compact" \
  "$(CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=73 segment_context "$(payload 30 60000 200000)")"
assert_eq "30% of 200k without it" \
  "ctx ▕██████···········|≈≈≈▏ 30% · 60k/200k · ~107k until compact" \
  "$(segment_context "$(payload 30 60000 200000)")"
assert_eq "past the trigger" \
  "ctx ▕█████████████████|██≈▏ 97% · 194k/200k · past compact" \
  "$(segment_context "$(payload 97 194000 200000)")"
assert_eq "1M window" "ctx ▕██·················|≈▏ 12% · 120k/1M · ~847k until compact" \
  "$(segment_context "$(payload 12 120000 1000000)")"
assert_eq "fractional percentage is floored" \
  "ctx ▕█················|≈≈≈▏ 4% · 9k/200k · ~157k until compact" \
  "$(segment_context "$(payload 4.7 9400 200000)")"
assert_eq "early session (nulls) yields nothing" "" \
  "$(segment_context '{"context_window":{"used_percentage":null,"context_window_size":200000}}')"
assert_eq "no context data yields nothing" "" "$(segment_context '{}')"
# Tone: dim far from the trigger, yellow near it, red past it.
assert_eq "dim far away" "0" "$(NO_COLOR='' segment_context "$(payload 10 20000 200000)" | grep -c $'\033\[33m')"
assert_eq "yellow near the trigger" "1" "$(NO_COLOR='' segment_context "$(payload 75 150000 200000)" | grep -c $'\033\[33m')"
assert_eq "red past the trigger" "1" "$(NO_COLOR='' segment_context "$(payload 90 180000 200000)" | grep -c $'\033\[91m')"

echo "test-segment-context.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
