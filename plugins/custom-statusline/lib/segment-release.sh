#!/usr/bin/env bash
# Release segment: latest GitHub Release tag for the repo, via `gh`, cached.

CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS="${CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS:-300}"

fetch_latest_release_tag() {
  local owner="$1" repo="$2"
  gh api "repos/${owner}/${repo}/releases/latest" --jq '.tag_name' 2>/dev/null
}
