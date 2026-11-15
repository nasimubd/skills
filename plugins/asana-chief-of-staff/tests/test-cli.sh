#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 -m py_compile "$root/bin/asana-chief-of-staff"
python3 "$root/bin/asana-chief-of-staff" --help >/dev/null
printf '2 passed, 0 failed\n'
