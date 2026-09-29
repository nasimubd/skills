#!/usr/bin/env bash
# Git segment: branch, dirty-state counts, ahead/behind — computed locally
# with git, not from the stdin payload.

git_current_branch() {
  local dir="$1"
  local branch
  branch="$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null)"
  if [[ -n "$branch" ]]; then
    printf '%s' "$branch"
    return 0
  fi
  # Detached HEAD: fall back to a short commit hash, prefixed so it reads
  # unmistakably as a commit rather than a branch name.
  local short_sha
  short_sha="$(git -C "$dir" rev-parse --short -q HEAD 2>/dev/null)"
  [[ -n "$short_sha" ]] && printf 'detached:%s' "$short_sha"
  return 0
}

# Prints "staged modified untracked" as three space-separated counts.
git_dirty_counts() {
  local dir="$1"
  local porcelain
  porcelain="$(git -C "$dir" status --porcelain=v1 2>/dev/null)" || {
    printf '0 0 0'
    return 0
  }

  local staged=0 modified=0 untracked=0
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    local index_status="${line:0:1}" worktree_status="${line:1:1}"
    [[ "$index_status" != " " && "$index_status" != "?" ]] && staged=$((staged + 1))
    [[ "$worktree_status" == "M" || "$worktree_status" == "D" ]] && modified=$((modified + 1))
    [[ "$index_status" == "?" ]] && untracked=$((untracked + 1))
  done <<<"$porcelain"

  printf '%d %d %d' "$staged" "$modified" "$untracked"
}
