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
#
# The org endpoint accepts an unfiltered listing; the user endpoint requires
# an explicit package_type (422 without one), and there is no "all types" in
# one call — so the user path queries each known type and concatenates.
CUSTOM_STATUSLINE_PACKAGE_TYPES=(npm maven rubygems docker nuget container)

fetch_owner_packages() {
  local owner="$1"
  local org_result
  if org_result="$(gh api "orgs/${owner}/packages" 2>/dev/null)"; then
    printf '%s' "$org_result"
    return 0
  fi

  local combined="[]" package_type user_result
  for package_type in "${CUSTOM_STATUSLINE_PACKAGE_TYPES[@]}"; do
    user_result="$(gh api "users/${owner}/packages?package_type=${package_type}" 2>/dev/null)" || continue
    combined="$(jq -sc 'add' <<<"$combined"$'\n'"$user_result")"
  done
  printf '%s' "$combined"
}

# Local manifest version, checked in a fixed priority order: package.json,
# Cargo.toml, pyproject.toml, then a bare VERSION file. Prints nothing if the
# directory has none of these.
detect_manifest_version() {
  local dir="$1"

  if [[ -f "$dir/package.json" ]]; then
    jq -r '.version // empty' "$dir/package.json" 2>/dev/null
    return 0
  fi
  if [[ -f "$dir/Cargo.toml" ]]; then
    sed -n '/^\[package\]/,/^\[/p' "$dir/Cargo.toml" \
      | grep -m1 '^version' | sed -E 's/^version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/'
    return 0
  fi
  if [[ -f "$dir/pyproject.toml" ]]; then
    sed -n '/^\[project\]/,/^\[/p' "$dir/pyproject.toml" \
      | grep -m1 '^version' | sed -E 's/^version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/'
    return 0
  fi
  if [[ -f "$dir/VERSION" ]]; then
    tr -d '[:space:]' <"$dir/VERSION"
    return 0
  fi
}

# Latest version of whichever package (if any) is tied to this repository.
fetch_repo_package_summary() {
  local owner="$1" repo="$2"
  local packages_json
  packages_json="$(fetch_owner_packages "$owner")" || return 1

  printf '%s' "$packages_json" | jq -r --arg full_name "${owner}/${repo}" \
    '[.[]? | select(.repository != null and .repository.full_name == $full_name)]
     | sort_by(.updated_at) | last
     | if . == null then empty else "\(.name):\(.version_count // 0)v" end'
}
