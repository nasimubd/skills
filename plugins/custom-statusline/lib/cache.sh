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

cache_path_for_key() {
  local key="$1"
  printf '%s/%s\n' "$(cache_dir)" "$(cache_key_to_filename "$key")"
}

# File modification time in epoch seconds, portable across BSD (macOS) and
# GNU stat.
cache_file_mtime_epoch() {
  local path="$1"
  stat -f '%m' "$path" 2>/dev/null || stat -c '%Y' "$path" 2>/dev/null
}

# Print the cached value for $1 if it exists and is younger than $2 seconds.
# Prints nothing and returns 1 on a miss (absent, unreadable, or expired) —
# callers treat a miss as "go fetch", never as an error.
cache_get() {
  local key="$1" ttl_seconds="$2"
  local path
  path="$(cache_path_for_key "$key")"
  [[ -f "$path" ]] || return 1

  local mtime now age
  mtime="$(cache_file_mtime_epoch "$path")" || return 1
  now="$(date +%s)"
  age=$((now - mtime))
  [[ "$age" -lt "$ttl_seconds" ]] || return 1

  cat "$path"
}

# Write $2 as the cached value for key $1. Writes to a temp file and renames
# into place so a reader never observes a half-written cache entry.
cache_set() {
  local key="$1" value="$2"
  local dir path tmp
  dir="$(cache_dir)"
  path="$(cache_path_for_key "$key")"
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/.tmp.XXXXXX")"
  printf '%s' "$value" >"$tmp"
  mv "$tmp" "$path"
}

# cache_fetch <key> <ttl_seconds> <command...>
#
# Serve the cached value if fresh; otherwise run the command, cache stdout on
# success, and print it. A failing command (non-zero exit) is never cached
# and produces no output — callers treat empty output as "no data", not as
# an error to surface.
cache_fetch() {
  local key="$1" ttl_seconds="$2"
  shift 2

  local cached
  if cached="$(cache_get "$key" "$ttl_seconds")"; then
    printf '%s' "$cached"
    return 0
  fi

  local output
  if output="$("$@" 2>/dev/null)"; then
    cache_set "$key" "$output"
    printf '%s' "$output"
    return 0
  fi

  return 1
}
