#!/usr/bin/env bash
# Generic TTL file cache shared by the network-backed segments.

cache_dir() {
  printf '%s\n' "${CUSTOM_STATUSLINE_CACHE_DIR:-$HOME/.cache/custom-statusline}"
}
