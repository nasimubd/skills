#!/usr/bin/env bash
# Remote segment: the working directory, then the repository URL and whether
# the repository is public or private.
#
#   ~/AegisLaw/skills | https://github.com/nasimubd/skills [public]
#
# On a branch other than main or master the GitHub URL points at that branch
# (`/tree/<branch>`), which is how the branch name reaches the status line.
#
# Owner and name come from the payload (parsed from `origin` by Claude Code),
# falling back to the origin URL. Visibility needs `gh` and is cached for an
# hour; without it the badge is left out rather than replaced by an error.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./runtime.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/runtime.sh"
# shellcheck source=./cache.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/cache.sh"
# shellcheck source=./segment-directory.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/segment-directory.sh"

CUSTOM_STATUSLINE_VISIBILITY_TTL_SECONDS="${CUSTOM_STATUSLINE_VISIBILITY_TTL_SECONDS:-3600}"

fetch_repo_visibility() {
  local owner="$1" repo="$2"
  probe_direct 2 gh api "repos/${owner}/${repo}" \
    --jq 'if .private then "private" else "public" end' 2>/dev/null
}

# "host owner name" from a git remote URL (ssh or https), or nothing.
parse_remote_url() {
  local url="$1" rest
  case "$url" in
    git@*:*) rest="${url#git@}"; printf '%s %s' "${rest%%:*}" "$(remote_path_to_owner_name "${rest#*:}")" ;;
    ssh://git@*/* | https://*/* | http://*/*)
      rest="${url#*://}"; rest="${rest#*@}"
      printf '%s %s' "${rest%%/*}" "$(remote_path_to_owner_name "${rest#*/}")" ;;
  esac
}

remote_path_to_owner_name() {
  local path="${1%.git}"
  printf '%s %s' "${path%%/*}" "${path#*/}"
}

segment_remote() {
  local payload_json="$1" host owner repo dir
  IFS=$'\x1f' read -r host owner repo dir <<<"$(printf '%s' "$payload_json" | jq -r '
    [(.workspace.repo.host // ""), (.workspace.repo.owner // ""), (.workspace.repo.name // ""),
     (.workspace.current_dir // .cwd // "")] | join("\u001f")' 2>/dev/null)"

  local where
  where="$(segment_directory "$payload_json")"

  if [[ -z "$owner" || -z "$repo" ]] && [[ -n "$dir" ]]; then
    local origin parsed
    origin="$(git -C "$dir" remote get-url origin 2>/dev/null)" || origin=""
    parsed="$(parse_remote_url "$origin")"
    [[ -n "$parsed" ]] && read -r host owner repo <<<"$parsed"
  fi

  if [[ -z "$host" || -z "$owner" || -z "$repo" ]]; then
    [[ -n "$where" ]] && sl_color dim "$where"
    return 0
  fi

  local url="https://${host}/${owner}/${repo}"
  if [[ "$host" == "github.com" && -n "$dir" ]]; then
    local branch
    branch="$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null)" || branch=""
    [[ -n "$branch" && "$branch" != "main" && "$branch" != "master" ]] && url+="/tree/$branch"
  fi
  local out
  out="$(sl_color green "$where") $(sl_color dim '|') $(sl_color dim "$url")"
  if [[ "$host" == "github.com" ]]; then
    local vis
    vis="$(cache_fetch "${owner}/${repo}/visibility" "$CUSTOM_STATUSLINE_VISIBILITY_TTL_SECONDS" \
      fetch_repo_visibility "$owner" "$repo")" || vis=""
    [[ -n "$vis" ]] && out+=" $(sl_color dim "[$vis]")"
  fi
  printf '%s' "$out"
}
