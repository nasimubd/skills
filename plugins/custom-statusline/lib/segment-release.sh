#!/usr/bin/env bash
# Release segment: the latest release and how long ago it was published.
#
#   v1.5.0 tag 13h ago
#
# GitHub's latest release is authoritative (it is what semantic-release
# publishes); it is fetched through `gh` and cached. When there is no GitHub
# answer (no gh, offline, no release) the newest local tag stands in, so the
# segment still renders in a repository that has never left the machine.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./runtime.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/runtime.sh"
# shellcheck source=./cache.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/cache.sh"

CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS="${CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS:-300}"

# Tag only; the package segment compares it with the manifest version.
fetch_latest_release_tag() {
  local owner="$1" repo="$2"
  probe_direct 3 gh api "repos/${owner}/${repo}/releases/latest" --jq '.tag_name' 2>/dev/null
}

# "<tag><TAB><published_at>", so the age can be recomputed on every render
# from the cached value instead of freezing at the moment it was fetched.
fetch_latest_release_info() {
  local owner="$1" repo="$2"
  probe_direct 3 gh api "repos/${owner}/${repo}/releases/latest" \
    --jq '[.tag_name, .published_at] | @tsv' 2>/dev/null
}

# "<tag><TAB><epoch>" for the newest local tag, by version order.
local_latest_tag() {
  local dir="$1" tag epoch
  tag="$(git -C "$dir" tag --sort=-v:refname 2>/dev/null | head -1)"
  [[ -n "$tag" ]] || return 0
  epoch="$(git -C "$dir" log -1 --format=%ct "$tag" 2>/dev/null)"
  [[ -n "$epoch" ]] && printf '%s\t%s' "$tag" "$epoch"
}

segment_release() {
  local payload_json="$1" owner repo dir
  IFS=$'\x1f' read -r owner repo dir <<<"$(printf '%s' "$payload_json" | jq -r '
    [(.workspace.repo.owner // ""), (.workspace.repo.name // ""),
     (.workspace.current_dir // .cwd // "")] | join("\u001f")' 2>/dev/null)"

  local tag="" epoch="" info published
  if [[ -n "$owner" && -n "$repo" ]]; then
    info="$(cache_fetch "${owner}/${repo}/release-info" "$CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS" \
      fetch_latest_release_info "$owner" "$repo")" || info=""
    IFS=$'\t' read -r tag published <<<"$info"
    [[ -n "$published" ]] && epoch="$(iso_to_epoch "$published")"
  fi
  if [[ -z "$tag" && -n "$dir" ]]; then
    IFS=$'\t' read -r tag epoch <<<"$(local_latest_tag "$dir")"
  fi
  [[ -n "$tag" ]] || return 0

  local age=""
  [[ "$epoch" =~ ^[0-9]+$ ]] && age="$(format_age_seconds $(($(date +%s) - epoch)))"
  if [[ -n "$age" ]]; then
    printf '%s %s' "$(sl_color cyan "$tag")" "$(sl_color dim "tag $age ago")"
  else
    printf '%s %s' "$(sl_color cyan "$tag")" "$(sl_color dim tag)"
  fi
}
