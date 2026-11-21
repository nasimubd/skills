#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
python3 -m py_compile "$root/bin/asana-chief-of-staff"
python3 "$root/bin/asana-chief-of-staff" --help >/dev/null
printf '2 passed, 0 failed\n'
python3 - <<'PY'
import runpy
module=runpy.run_path('plugins/asana-chief-of-staff/bin/asana-chief-of-staff')
assert 'Human Handoff' in module['LEADSCOUT_SECTIONS']
assert 'human-handoff' in module['LEADSCOUT_TAGS']
print('2 setup invariants passed')
PY
