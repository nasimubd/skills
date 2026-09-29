#!/usr/bin/env bash
# Git segment: branch, dirty-state counts, ahead/behind — computed locally
# with git, not from the stdin payload.

git_current_branch() {
  local dir="$1"
  git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null
}
