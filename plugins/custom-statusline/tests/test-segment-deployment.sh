#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/segment-deployment.sh"

export CUSTOM_STATUSLINE_CACHE_DIR="$(mktemp -d)"
trap 'rm -rf "$CUSTOM_STATUSLINE_CACHE_DIR"' EXIT

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

assert_eq "missing repo info yields empty" "" "$(segment_deployment '{}')"

assert_eq "real repo with neither source omits segment" "" \
  "$(segment_deployment '{"workspace":{"repo":{"owner":"nasimubd","name":"skills"}}}')"

# Pre-seed both cache entries for a repo that cannot exist, proving the
# render logic (not the fetch) is what's under test here.
cache_set "owner-zzz/repo-zzz/deployment" "production:success"
cache_set "owner-zzz/repo-zzz/deploy-workflow" "Deploy:success"
assert_eq "both sources present renders both" "production:success Deploy:success" \
  "$(segment_deployment '{"workspace":{"repo":{"owner":"owner-zzz","name":"repo-zzz"}}}')"

# Exercise the workflow-name-matching jq filter directly against a fixture,
# since neither real gh call above happens to hit a repo with workflows.
FIXTURE_RUNS='{"workflow_runs":[
  {"name":"CI","run_number":5,"conclusion":"success"},
  {"name":"Deploy to staging","run_number":6,"conclusion":"failure"},
  {"name":"DEPLOY to prod","run_number":7,"conclusion":"success"}
]}'
gh() {
  echo "$FIXTURE_RUNS"
}
export -f gh
assert_eq "picks the highest run_number among deploy* matches, case-insensitive" \
  "DEPLOY to prod:success" "$(fetch_latest_deploy_workflow_run owner-zzz repo-zzz)"
unset -f gh

echo "test-segment-deployment.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
