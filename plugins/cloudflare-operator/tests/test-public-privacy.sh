#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
if rg -n -i '(api[_ -]?token|secret|password|[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,})' "$root" --glob '!tests/test-public-privacy.sh' --glob '!references/authentication.md' --glob '!CLAUDE.md' --glob '!skills/**' >/tmp/cloudflare-privacy-findings; then
  cat /tmp/cloudflare-privacy-findings
  echo 'privacy scan failed' >&2
  exit 1
fi
printf '1 passed, 0 failed\n'
