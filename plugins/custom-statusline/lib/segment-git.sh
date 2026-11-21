#!/usr/bin/env bash
# Git segment: working-tree indicators computed locally with git.
#   M modified  D deleted  S staged  U untracked  ↑ ahead  ↓ behind
#   ≡ stashes   ⚠ merge conflicts
# Prints nothing outside a git repository. ↑ and ↓ appear only when the branch
# has an upstream, because without one there is nothing to be ahead of.

CUSTOM_STATUSLINE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./runtime.sh
source "$CUSTOM_STATUSLINE_LIB_DIR/runtime.sh"

# Prints "modified deleted staged untracked conflicts", space-separated.
git_dirty_counts() {
  local dir="$1" porcelain
  porcelain="$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" status --porcelain=v1 2>/dev/null)" || {
    printf '0 0 0 0 0'
    return 0
  }
  local modified=0 deleted=0 staged=0 untracked=0 conflicts=0 line x y
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    x="${line:0:1}"
    y="${line:1:1}"
    case "$x$y" in
      '??') untracked=$((untracked + 1)); continue ;;
      '!!') continue ;;
      DD | AU | UD | UA | DU | AA | UU) conflicts=$((conflicts + 1)); continue ;;
    esac
    [[ "$x" != " " ]] && staged=$((staged + 1))
    [[ "$y" == "M" || "$y" == "T" ]] && modified=$((modified + 1))
    [[ "$y" == "D" ]] && deleted=$((deleted + 1))
  done <<<"$porcelain"
  printf '%d %d %d %d %d' "$modified" "$deleted" "$staged" "$untracked" "$conflicts"
}

# Prints "ahead behind", or nothing when the branch has no upstream.
git_ahead_behind() {
  local counts behind ahead
  counts="$(git -C "$1" rev-list --left-right --count '@{upstream}...HEAD' 2>/dev/null)" || return 0
  read -r behind ahead <<<"$counts"
  printf '%d %d' "${ahead:-0}" "${behind:-0}"
}

git_stash_count() {
  git -C "$1" stash list 2>/dev/null | wc -l | tr -d ' '
}

# One indicator: dim at zero, coloured when there is something to look at.
git_indicator() {
  local label="$1" value="$2" color="$3"
  if [[ "$value" -eq 0 ]]; then
    sl_color dim "$label:$value"
  else
    sl_color "$color" "$label:$value"
  fi
}

segment_git() {
  local payload_json="$1" dir
  dir="$(printf '%s' "$payload_json" | jq -r '.workspace.current_dir // .cwd // empty')"
  [[ -n "$dir" ]] || dir="."
  git -C "$dir" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  local modified deleted staged untracked conflicts ahead behind stashes
  read -r modified deleted staged untracked conflicts <<<"$(git_dirty_counts "$dir")"
  stashes="$(git_stash_count "$dir")"

  local out
  out="$(git_indicator M "$modified" yellow) $(git_indicator D "$deleted" yellow)"
  out+=" $(git_indicator S "$staged" green) $(git_indicator U "$untracked" yellow)"
  if read -r ahead behind <<<"$(git_ahead_behind "$dir")" && [[ -n "${ahead:-}" ]]; then
    out+=" $(git_indicator ↑ "$ahead" cyan) $(git_indicator ↓ "$behind" yellow)"
  fi
  out+=" $(git_indicator ≡ "${stashes:-0}" cyan) $(git_indicator ⚠ "$conflicts" red)"
  printf '%s' "$out"
}
