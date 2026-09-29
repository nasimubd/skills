#!/usr/bin/env bash
# Generic TTL file cache shared by the network-backed segments.

cache_dir() {
  printf '%s\n' "${CUSTOM_STATUSLINE_CACHE_DIR:-$HOME/.cache/custom-statusline}"
}

# A cache key is a free-form string (e.g. "owner/repo/release"); turn it into
# a safe filename by replacing anything that isn't alphanumeric, dot, dash or
# underscore with an underscore.
cache_key_to_filename() {
  local key="$1"
  printf '%s' "$key" | tr -c 'A-Za-z0-9._-' '_'
}
