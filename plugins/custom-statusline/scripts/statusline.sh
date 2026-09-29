#!/usr/bin/env bash
# Entrypoint: reads the statusline JSON payload from stdin once, calls each
# segment, and prints the assembled multi-line status.
set -euo pipefail

CUSTOM_STATUSLINE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_STATUSLINE_PLUGIN_ROOT="$(cd "$CUSTOM_STATUSLINE_SCRIPT_DIR/.." && pwd)"

if ! command -v jq >/dev/null 2>&1; then
  echo "custom-statusline: jq is required but not on PATH" >&2
  exit 1
fi

LIB_DIR="$CUSTOM_STATUSLINE_PLUGIN_ROOT/lib"
source "$LIB_DIR/cache.sh"
source "$LIB_DIR/segment-session.sh"
source "$LIB_DIR/segment-directory.sh"
source "$LIB_DIR/segment-git.sh"
source "$LIB_DIR/segment-context.sh"
source "$LIB_DIR/segment-model.sh"
source "$LIB_DIR/segment-release.sh"
source "$LIB_DIR/segment-deployment.sh"
source "$LIB_DIR/segment-package.sh"

# Join non-empty arguments with " | ", skipping empty ones entirely — so a
# missing segment collapses cleanly instead of leaving a stray separator.
join_nonempty() {
  local piece joined=""
  for piece in "$@"; do
    [[ -n "$piece" ]] || continue
    if [[ -n "$joined" ]]; then
      joined+=" | $piece"
    else
      joined="$piece"
    fi
  done
  printf '%s' "$joined"
}

PAYLOAD_JSON="$(cat)"
# Malformed stdin would otherwise cascade into a jq parse error from every
# single segment that reads it. Normalize once, here, rather than let each
# segment discover the same brokenness independently.
printf '%s' "$PAYLOAD_JSON" | jq -e . >/dev/null 2>&1 || PAYLOAD_JSON="{}"

LINE1_SESSION="$(segment_session "$PAYLOAD_JSON")"
LINE1_DIRECTORY="$(segment_directory "$PAYLOAD_JSON")"
LINE1="$(join_nonempty "$LINE1_SESSION" "$LINE1_DIRECTORY")"
[[ -n "$LINE1" ]] && printf '%s\n' "$LINE1"

LINE2_GIT="$(segment_git "$PAYLOAD_JSON")"
LINE2_RELEASE="$(segment_release "$PAYLOAD_JSON")"
LINE2="$(join_nonempty "$LINE2_GIT" "$LINE2_RELEASE")"
[[ -n "$LINE2" ]] && printf '%s\n' "$LINE2"

LINE3="$(segment_context "$PAYLOAD_JSON")"
[[ -n "$LINE3" ]] && printf '%s\n' "$LINE3"

LINE4_DEPLOYMENT="$(segment_deployment "$PAYLOAD_JSON")"
LINE4_PACKAGE="$(segment_package "$PAYLOAD_JSON")"
LINE4="$(join_nonempty "$LINE4_DEPLOYMENT" "$LINE4_PACKAGE")"
[[ -n "$LINE4" ]] && printf '%s\n' "$LINE4"

LINE5="$(segment_model "$PAYLOAD_JSON")"
[[ -n "$LINE5" ]] && printf '%s\n' "$LINE5"

# A statusline command's exit status must always be 0 — the script's own
# success has nothing to do with whether the LAST segment happened to be
# empty, and without this, an empty final segment leaves `$?` at 1 (from the
# short-circuited `[[ ]] && printf` above), which is what the last command
# executed happens to return, not a real failure.
exit 0
