#!/usr/bin/env bash
# Entrypoint: reads the statusline JSON payload from stdin once, calls each
# segment, and prints the assembled multi-line status.
set -euo pipefail

CUSTOM_STATUSLINE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_STATUSLINE_PLUGIN_ROOT="$(cd "$CUSTOM_STATUSLINE_SCRIPT_DIR/.." && pwd)"

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

PAYLOAD_JSON="$(cat)"
