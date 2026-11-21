#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
# Public docs may mention credential variable names; they must not contain credential values,
# private email addresses, or non-placeholder deployment domains.
if rg -n -i '[[:alnum:]._%+-]+@[[:alnum:].-]+\.(com|net|org|io)|https?://(?!developers\.cloudflare\.com|api\.cloudflare\.com|github\.com)' "$root" --pcre2 --glob '!tests/test-public-privacy.sh' --glob '!references/authentication.md' --glob '!CLAUDE.md' --glob '!skills/**' >/tmp/cloudflare-privacy-findings; then
  cat /tmp/cloudflare-privacy-findings
  echo 'privacy scan failed' >&2
  exit 1
fi
printf '1 passed, 0 failed\n'
