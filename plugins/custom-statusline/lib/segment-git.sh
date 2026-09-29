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
