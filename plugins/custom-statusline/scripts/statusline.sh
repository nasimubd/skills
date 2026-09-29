#!/usr/bin/env bash
# Entrypoint: reads the statusline JSON payload from stdin once, calls each
# segment, and prints the assembled multi-line status.
set -euo pipefail

CUSTOM_STATUSLINE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CUSTOM_STATUSLINE_PLUGIN_ROOT="$(cd "$CUSTOM_STATUSLINE_SCRIPT_DIR/.." && pwd)"

PAYLOAD_JSON="$(cat)"
