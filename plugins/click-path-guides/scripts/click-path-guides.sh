#!/usr/bin/env bash
# click-path-guides — check that a step-by-step UI guide only names things that exist.
#
#   click-path-guides labels <source> [--keys k1,k2]       list the labels found in the source
#   click-path-guides lint <guide.md> --source <file> [--keys k1,k2] [--allow "A,B"]
#   click-path-guides template                              print the guide template
#
# Exit codes: 0 ok, 1 runtime error, 2 usage, 3 the guide has findings.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/labels.sh
source "$ROOT/lib/labels.sh"

usage() {
  cat <<'USAGE'
usage: click-path-guides <command>

  labels <source> [--keys k1,k2]
        list the interface labels found in an app or flow definition
        (JSON, YAML, text). --keys limits it to values stored under those keys.
  lint <guide.md> --source <file> [--keys k1,k2] [--allow "A,B"]
        check every bold interface element against the source, plus menu paths,
        positional or colour wording, filler, prerequisites and step numbering.
        --allow lists terms the source cannot hold (for example host application
        menus); the guide must then say they were not verified.
  template
        print the guide template
USAGE
}

need_value() { [[ $# -ge 2 && -n "$2" ]] || { echo "click-path-guides: $1 needs a value" >&2; exit 2; }; }

cmd_labels() {
  local source="" keys=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --keys) need_value "$@"; keys="$2"; shift 2 ;;
      -*) echo "click-path-guides: unknown option $1" >&2; exit 2 ;;
      *) [[ -z "$source" ]] || { echo "click-path-guides: one source only" >&2; exit 2; }; source="$1"; shift ;;
    esac
  done
  [[ -n "$source" ]] || { echo "usage: click-path-guides labels <source> [--keys k1,k2]" >&2; exit 2; }
  local out
  out="$(cgp_labels "$source" "$keys")" || exit 1
  [[ -n "$out" ]] || { echo "click-path-guides: no labels found in $source${keys:+ under keys: $keys}" >&2; exit 1; }
  printf '%s\n' "$out"
  echo "Labels: $(printf '%s\n' "$out" | wc -l | tr -d ' ') from $source${keys:+ (keys: $keys)}" >&2
}

cmd_lint() {
  local guide="" source="" keys="" allow=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --source) need_value "$@"; source="$2"; shift 2 ;;
      --keys) need_value "$@"; keys="$2"; shift 2 ;;
      --allow) need_value "$@"; allow="$2"; shift 2 ;;
      -*) echo "click-path-guides: unknown option $1" >&2; exit 2 ;;
      *) [[ -z "$guide" ]] || { echo "click-path-guides: one guide only" >&2; exit 2; }; guide="$1"; shift ;;
    esac
  done
  [[ -n "$guide" && -n "$source" ]] || { echo "usage: click-path-guides lint <guide.md> --source <file> [--keys k1,k2] [--allow \"A,B\"]" >&2; exit 2; }
  [[ -f "$guide" ]] || { echo "click-path-guides: guide not found: $guide" >&2; exit 1; }

  local tmp rc=0
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  cgp_labels "$source" "$keys" >"$tmp" || exit 1
  if [[ ! -s "$tmp" ]]; then
    echo "click-path-guides: no labels found in $source${keys:+ under keys: $keys}; nothing to verify the guide against" >&2
    exit 1
  fi
  echo "Examined: guide $guide against $(wc -l <"$tmp" | tr -d ' ') label(s) from $source${keys:+ (keys: $keys)}${allow:+; allowed unverified: $allow}"
  awk -v guide="$guide" -v allow="$allow" -f "$ROOT/lib/lint.awk" "$tmp" "$guide" || rc=$?
  exit "$rc"
}

case "${1:-}" in
  labels) shift; cmd_labels "$@" ;;
  lint) shift; cmd_lint "$@" ;;
  template) cat "$ROOT/templates/guide.md" ;;
  -h | --help | help | "") usage ;;
  *) echo "click-path-guides: unknown command '$1'" >&2; usage >&2; exit 2 ;;
esac
