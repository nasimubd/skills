#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 -m py_compile "$root/bin/cloudflare-operator"
python3 "$root/bin/cloudflare-operator" --help >/dev/null
printf '2 passed, 0 failed\n'
