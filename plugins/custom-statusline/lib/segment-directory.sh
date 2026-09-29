#!/usr/bin/env bash
# Directory segment: the working directory Claude Code reports on stdin.

segment_directory() {
  local payload_json="$1"
  local dir
  dir="$(printf '%s' "$payload_json" | jq -r '.workspace.current_dir // .cwd // empty')"
  printf '%s' "$dir"
}
