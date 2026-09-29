#!/usr/bin/env bash
# Package segment: GitHub Packages API result AND/OR release-tag-vs-manifest
# drift. Renders whichever exists; omits the whole segment if neither does.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./cache.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/cache.sh"

CUSTOM_STATUSLINE_PACKAGE_TTL_SECONDS="${CUSTOM_STATUSLINE_PACKAGE_TTL_SECONDS:-600}"

# GitHub Packages has no /repos/{owner}/{repo}/packages endpoint; packages
# are scoped to an org or a user account. Try org first, fall back to user —
# a 404 on the org endpoint just means the owner is a personal account.
fetch_owner_packages() {
  local owner="$1"
  gh api "orgs/${owner}/packages" 2>/dev/null || gh api "users/${owner}/packages" 2>/dev/null
}
