#!/usr/bin/env bash
# Directory segment: the working directory Claude Code reports on stdin.

CUSTOM_STATUSLINE_DIRECTORY_MAX_CHARS="${CUSTOM_STATUSLINE_DIRECTORY_MAX_CHARS:-40}"

# Keep the start and end of a long path, dropping the middle — the leaf
# directory name matters most, and the leading segments identify the tree.
truncate_path_middle() {
  local path="$1" max_chars="$2"
  local len=${#path}
  [[ "$len" -gt "$max_chars" ]] || { printf '%s' "$path"; return 0; }

  local keep=$(((max_chars - 1) / 2))
  printf '%s…%s' "${path:0:keep}" "${path: -keep}"
}

segment_directory() {
  local payload_json="$1"
  local dir
  dir="$(printf '%s' "$payload_json" | jq -r '.workspace.current_dir // .cwd // empty')"
  [[ -n "$dir" ]] || return 0

  if [[ "$dir" == "$HOME" ]]; then
    dir="~"
  elif [[ "$dir" == "$HOME"/* ]]; then
    dir="~${dir#"$HOME"}"
  fi
  truncate_path_middle "$dir" "$CUSTOM_STATUSLINE_DIRECTORY_MAX_CHARS"
}
