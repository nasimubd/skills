#!/usr/bin/env bash
# Human approval gate for any future mutating Cloudflare command wrapper.
set -euo pipefail
operation="${1:-unknown}"
case "$operation" in
  delete|overwrite|bulk|purge|credential|public-access|routing|certificate|nameserver|dnssec|zone-settings|worker-deploy|r2-policy)
    echo "EXPLICIT_APPROVAL_REQUIRED:$operation" >&2
    exit 42
    ;;
  *) exit 0 ;;
esac
