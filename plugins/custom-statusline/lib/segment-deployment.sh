#!/usr/bin/env bash
# Deployment segment: GitHub Deployments API status AND/OR the latest
# deploy*-named Actions workflow run. Renders whichever exists; omits the
# whole segment if neither does.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./cache.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/cache.sh"

CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS="${CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS:-180}"

# Latest deployment's environment + state, e.g. "production:success".
# `.id != null` guards the empty-array case: `sort_by(.id) | last` on `[]` is
# `null`, and `null.id` is also `null`, not an error — so an empty result set
# must be checked for explicitly, not just treated as "field absent".
fetch_latest_deployment_status() {
  local owner="$1" repo="$2"
  local deployments_json
  deployments_json="$(gh api "repos/${owner}/${repo}/deployments" 2>/dev/null)" || return 1

  local latest_deployment_id environment
  read -r latest_deployment_id environment <<<"$(
    printf '%s' "$deployments_json" | jq -r \
      'sort_by(.id) | last | if . == null then empty else "\(.id) \(.environment)" end'
  )"
  [[ -n "$latest_deployment_id" ]] || return 1

  local statuses_json state
  statuses_json="$(gh api "repos/${owner}/${repo}/deployments/${latest_deployment_id}/statuses" 2>/dev/null)" || return 1
  state="$(printf '%s' "$statuses_json" | jq -r \
    'sort_by(.id) | last | if . == null then empty else .state end')"
  [[ -n "$state" ]] || return 1

  printf '%s:%s' "$environment" "$state"
}
