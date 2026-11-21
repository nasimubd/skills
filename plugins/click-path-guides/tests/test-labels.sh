#!/usr/bin/env bash
# Tests for label extraction (lib/labels.sh via bin/click-path-guides labels).
# Auto-discovered by test-marketplace-hook-regression-suite. Run under /bin/bash on macOS.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$PLUGIN_ROOT/bin/click-path-guides"
FX="$PLUGIN_ROOT/tests/fixtures"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

has() { grep -Fxq -- "$2" <<<"$1"; }

# --- JSON ---------------------------------------------------------------------------------
out="$("$CLI" labels "$FX/app.json" --keys label,title 2>/dev/null)"
for want in "New expense" "Refresh" "File" "Export to CSV" "Settings" "Amount" "Category" "Submit" "Cancel" "Expenses"; do
  has "$out" "$want" && ok || bad "json keys: missing label '$want'"
done
has "$out" "btnNew" && bad "json keys: an id leaked in" || ok
has "$out" "Navigate" && bad "json keys: an action leaked in" || ok
has "$out" "Travel" && bad "json keys: option values are not under label keys" || ok

out_all="$("$CLI" labels "$FX/app.json" 2>/dev/null)"
has "$out_all" "Travel" && ok || bad "json without keys should include every string"
has "$out_all" "btnNew" && ok || bad "json without keys should include ids (broad mode)"

# Output is sorted and unique.
dup="$(printf '%s\n' "$out" | sort | uniq -d)"
[[ -z "$dup" ]] && ok || bad "labels should be unique"
[[ "$out" == "$(printf '%s\n' "$out" | sort -u)" ]] && ok || bad "labels should be sorted"

# --- YAML / Power Fx ------------------------------------------------------------------------
out="$("$CLI" labels "$FX/app.pa.yaml" --keys Text,HintText 2>/dev/null)"
for want in "New expense" "Refresh" "Amount" "Submit"; do
  has "$out" "$want" && ok || bad "yaml keys: missing '$want' (Power Fx quotes should be stripped)"
done
has "$out" "=\"Submit\"" && bad "yaml: the =\"...\" wrapper should be stripped" || ok
has "$out" "RGBA(0, 120, 212, 1)" && bad "yaml keys: Fill is not a label key" || ok

# --- plain text ---------------------------------------------------------------------------------
cat >"$WORK/notes.md" <<'EOF'
# Settings
Use the "Save as…" command or 'Print'.
- Open file:
Label: Export
EOF
out="$("$CLI" labels "$WORK/notes.md" 2>/dev/null)"
has "$out" "Settings" && ok || bad "text: heading"
has "$out" "Save as" && ok || bad "text: quoted string with trailing ellipsis normalised"
has "$out" "Print" && ok || bad "text: single-quoted string"
has "$out" "Open file" && ok || bad "text: list item with trailing colon normalised"
has "$out" "Export" && ok || bad "text: key: value"

# --- refusals -----------------------------------------------------------------------------------------
for img in shot.png shot.JPG doc.pdf; do
  : >"$WORK/$img"
  "$CLI" labels "$WORK/$img" >"$WORK/o" 2>"$WORK/e" && bad "$img should be refused" || { [[ $? -eq 1 ]] && grep -q 'not a definition' "$WORK/e" && ok || bad "$img refusal message/exit"; }
done
"$CLI" labels "$WORK/missing.json" >/dev/null 2>"$WORK/e" && bad "missing file should fail" || { grep -q 'not found' "$WORK/e" && ok || bad "missing file message"; }
"$CLI" labels "$FX/app.json" --keys nonexistent >/dev/null 2>"$WORK/e" && bad "no labels under the keys should fail" || { grep -q 'no labels found' "$WORK/e" && ok || bad "no-labels message"; }
printf '{}' >"$WORK/empty.json"
"$CLI" labels "$WORK/empty.json" >/dev/null 2>&1 && bad "an empty definition should fail" || ok
"$CLI" labels >/dev/null 2>&1 && bad "labels with no source is a usage error" || { [[ $? -eq 2 ]] && ok || bad "labels usage exit code"; }
"$CLI" labels "$FX/app.json" --keys >/dev/null 2>&1 && bad "--keys without a value is a usage error" || { [[ $? -eq 2 ]] && ok || bad "--keys usage exit code"; }
"$CLI" labels "$FX/app.json" --bogus >/dev/null 2>&1 && bad "unknown option is a usage error" || { [[ $? -eq 2 ]] && ok || bad "unknown option exit code"; }

echo "test-labels.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
