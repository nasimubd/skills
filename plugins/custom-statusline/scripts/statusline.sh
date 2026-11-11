#!/usr/bin/env bash
# Claude Code status line. Reads the status JSON on stdin and prints up to six
# lines, each built by one tested segment in ../lib:
#
#   1  M:0 D:0 S:0 U:0 ↑:0 ↓:0 ≡:0 ⚠:0 | v1.5.0 tag 13h ago      git, latest release
#   2  claude-sonnet-5-5 · high · thinking:true                  model, effort, thinking
#   3  ctx ▕██████·······|≈≈≈≈≈≈≈▏ 30% · 60k/200k · ~71k until compact
#   4  Wed 11 Nov 2026 18:05 UTC | 13:05 EST                     clock
#   5  ~/repo | https://github.com/owner/repo [public]            directory, remote
#   6  ~/.claude/projects JSONL ID: <session id>                 session transcript
#
# A line with nothing to show is left out. CUSTOM_STATUSLINE_EXTRAS adds the
# network-backed `deployment` and/or `package` lines (comma separated); both
# are off by default. NO_COLOR turns colour off. Settings are listed in the
# README.
#
# This script must never fail the status line: no `set -e`, every segment
# degrades to empty, and it always exits 0.

CUSTOM_STATUSLINE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_STATUSLINE_LIB="$CUSTOM_STATUSLINE_SCRIPT_DIR/../lib"

# shellcheck source=../lib/runtime.sh
source "$CUSTOM_STATUSLINE_LIB/runtime.sh"

# The status line must observe the repository, never contend for it: without
# this, every render's `git status` can take .git/index.lock and race a
# concurrent commit in the same checkout.
export GIT_OPTIONAL_LOCKS=0

if ! command -v jq >/dev/null 2>&1; then
  echo "custom-statusline: jq is required but was not found on PATH"
  exit 0
fi

for _csl_segment in git model context clock session release remote deployment package; do
  # shellcheck source=/dev/null
  source "$CUSTOM_STATUSLINE_LIB/segment-$_csl_segment.sh"
done
unset _csl_segment

payload="$(cat)"
# Normalise once, here: a malformed payload would otherwise produce a jq parse
# error from every segment that reads it.
jq -e . >/dev/null 2>&1 <<<"$payload" || payload='{}'

emit() {
  [[ -n "$1" ]] && printf '%s\n' "$1"
  return 0
}

git_part="$(segment_git "$payload")"
release_part="$(segment_release "$payload")"
line1="$git_part"
if [[ -n "$line1" && -n "$release_part" ]]; then
  line1+=" $(sl_color dim '|') $release_part"
elif [[ -n "$release_part" ]]; then
  line1="$release_part"
fi

emit "$line1"
emit "$(segment_model "$payload")"
emit "$(segment_context "$payload")"
emit "$(segment_clock)"
emit "$(segment_remote "$payload")"
emit "$(segment_session "$payload")"

for _csl_extra in ${CUSTOM_STATUSLINE_EXTRAS//,/ }; do
  case "$_csl_extra" in
    deployment) emit "$(segment_deployment "$payload")" ;;
    package) emit "$(segment_package "$payload")" ;;
  esac
done

exit 0
