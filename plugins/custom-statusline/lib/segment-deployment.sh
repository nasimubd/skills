#!/usr/bin/env bash
# Deployment segment: GitHub Deployments API status AND/OR the latest
# deploy*-named Actions workflow run. Renders whichever exists; omits the
# whole segment if neither does.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./cache.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/cache.sh"

CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS="${CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS:-180}"

# Latest deployment's environment + state, e.g. "production:success".
fetch_latest_deployment_status() {
  local owner="$1" repo="$2"
  local latest_deployment_id environment
  read -r latest_deployment_id environment <<<"$(
    gh api "repos/${owner}/${repo}/deployments" --jq \
      'sort_by(.id) | last | "\(.id) \(.environment)"' 2>/dev/null
  )"
  [[ -n "$latest_deployment_id" ]] || return 1

  local state
  state="$(gh api "repos/${owner}/${repo}/deployments/${latest_deployment_id}/statuses" \
    --jq 'sort_by(.id) | last | .state' 2>/dev/null)"
  [[ -n "$state" ]] || return 1

  printf '%s:%s' "$environment" "$state"
}
