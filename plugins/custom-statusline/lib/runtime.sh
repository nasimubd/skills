#!/usr/bin/env bash
# Runtime helpers every segment shares: a hardened PATH, time-limited and
# proxy-free network calls, and colour. Sourced first, so it must work on
# macOS's bash 3.2 (no associative arrays, no mapfile).

# Sourced by every segment; load once so PATH is not extended again each time.
[[ -n "${CUSTOM_STATUSLINE_RUNTIME_LOADED:-}" ]] && return 0
CUSTOM_STATUSLINE_RUNTIME_LOADED=1

# Claude Code starts the statusLine command with a minimal PATH, not the
# interactive shell's. `gh` lives only where Homebrew or Linuxbrew put it,
# unlike `jq` and `git`, which ship system-wide on macOS. Without this the
# gh-backed segments silently go empty: not an error, just quietly wrong.
for _csl_bin_dir in /opt/homebrew/bin /usr/local/bin /home/linuxbrew/.linuxbrew/bin "$HOME/.local/bin"; do
  [[ -d "$_csl_bin_dir" ]] && PATH="$_csl_bin_dir:$PATH"
done
export PATH
unset _csl_bin_dir

# Run a command with a time limit. macOS ships no `timeout`; calling it
# anyway makes the shell report "command not found" (exit 127), which is how
# a status line ends up printing "gh exit 127" with gh installed and working.
# Use timeout or gtimeout when present, else a background watchdog.
with_timeout() {
  local secs="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@"
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@"
  else
    local pid watchdog rc
    "$@" &
    pid=$!
    (sleep "$secs"; kill "$pid" 2>/dev/null) >/dev/null 2>&1 &
    watchdog=$!
    wait "$pid" 2>/dev/null
    rc=$?
    kill "$watchdog" 2>/dev/null
    return "$rc"
  fi
}

# probe_direct <seconds> <command> [args...]
# Strips proxy variables first, so a proxy configured for other purposes can
# never silently break (or intercept) the status line's outbound calls.
probe_direct() {
  local secs="$1"
  shift
  with_timeout "$secs" env -u HTTPS_PROXY -u HTTP_PROXY -u ALL_PROXY \
    -u https_proxy -u http_proxy -u all_proxy "$@"
}

# sl_color <dim|red|yellow|green|cyan> <text>. Honours NO_COLOR (no-color.org).
sl_color() {
  if [[ -n "${NO_COLOR:-}" ]]; then
    printf '%s' "$2"
    return 0
  fi
  local code
  case "$1" in
    dim) code=90 ;;
    red) code=91 ;;
    yellow) code=33 ;;
    green) code=92 ;;
    cyan) code=96 ;;
    *) code=0 ;;
  esac
  printf '\033[%sm%s\033[0m' "$code" "$2"
}

# Seconds as "<1m", "5m", "13h", "3d" or "2w": the coarsest unit that fits.
format_age_seconds() {
  local s="$1"
  [[ "$s" =~ ^[0-9]+$ ]] || return 0
  if [[ "$s" -lt 60 ]]; then printf '<1m'
  elif [[ "$s" -lt 3600 ]]; then printf '%dm' $((s / 60))
  elif [[ "$s" -lt 86400 ]]; then printf '%dh' $((s / 3600))
  elif [[ "$s" -lt 604800 ]]; then printf '%dd' $((s / 86400))
  else printf '%dw' $((s / 604800))
  fi
}

# ISO 8601 UTC ("2026-11-11T18:05:09Z") to epoch seconds, on BSD or GNU date.
iso_to_epoch() {
  TZ=UTC date -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" '+%s' 2>/dev/null \
    || date -u -d "$1" '+%s' 2>/dev/null
}
