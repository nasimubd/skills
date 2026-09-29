#!/usr/bin/env bash
# Release segment: latest GitHub Release tag for the repo, via `gh`, cached.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./cache.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/cache.sh"

CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS="${CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS:-300}"

fetch_latest_release_tag() {
  local owner="$1" repo="$2"
  gh api "repos/${owner}/${repo}/releases/latest" --jq '.tag_name' 2>/dev/null
}

segment_release() {
  local payload_json="$1"
  local owner repo
  owner="$(printf '%s' "$payload_json" | jq -r '.workspace.repo.owner // empty')"
  repo="$(printf '%s' "$payload_json" | jq -r '.workspace.repo.name // empty')"
  [[ -n "$owner" && -n "$repo" ]] || return 0

  local tag
  tag="$(cache_fetch "${owner}/${repo}/release" "$CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS" \
    fetch_latest_release_tag "$owner" "$repo")" || return 0
  [[ -n "$tag" ]] || return 0
  printf '%s' "$tag"
}
