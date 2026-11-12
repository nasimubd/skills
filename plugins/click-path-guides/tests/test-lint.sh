#!/usr/bin/env bash
# Tests for the guide lint (lib/lint.awk via bin/click-path-guides lint).
# Auto-discovered by test-marketplace-hook-regression-suite. Run under /bin/bash on macOS.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$PLUGIN_ROOT/bin/click-path-guides"
SRC="$PLUGIN_ROOT/tests/fixtures/app.json"
KEYS="label,title"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

# A guide body is passed on stdin-like args; the preamble makes it valid so each test isolates one rule.
GOOD_HEAD=$'# Create an expense\n\nYou will have a saved expense.\n\n## Prerequisites\n\n- Access to the Expense Tracker app.\n\n## Steps\n\n'
GOOD_TAIL=$'\n## Result\n\nThe expense appears in the list.\n'

# lint <desc> <expected: pass|rule-id> <steps text> [extra args...]
lint() {
  local desc="$1" want="$2" steps="$3"
  shift 3
  printf '%s%s%s' "$GOOD_HEAD" "$steps" "$GOOD_TAIL" >"$WORK/g.md"
  local rc=0
  "$CLI" lint "$WORK/g.md" --source "$SRC" --keys "$KEYS" "$@" >"$WORK/out" 2>"$WORK/err" || rc=$?
  if [[ "$want" == pass ]]; then
    if [[ "$rc" -eq 0 ]]; then ok; else bad "$desc: expected pass, got exit $rc: $(grep -v '^Checked\|^Examined' "$WORK/out" | head -2 | tr '\n' ' ')"; fi
  else
    if [[ "$rc" -eq 3 ]] && grep -q ": $want:" "$WORK/out"; then ok; else bad "$desc: expected $want (exit 3), got exit $rc: $(cat "$WORK/out" "$WORK/err" | head -3 | tr '\n' ' ')"; fi
  fi
}

# --- a clean guide ------------------------------------------------------------------------
lint "clean guide" pass $'1. Select **New expense**.\n2. In the **Amount** box, enter the amount.\n3. Select **Submit**.\n'
lint "menu path done right" pass $'1. Select **File** > **Export to CSV**.\n'
lint "label with trailing ellipsis in the guide" pass $'1. Select **Export to CSV…**.\n'
lint "a callout is not a label" pass $'1. Select **Submit**.\n\n**Note:** the form closes after saving.\n'
lint "inline code is ignored" pass $'1. Run `**not a label**` in the console, then select **Submit**.\n'

# --- the central gate: bold must exist in the source ---------------------------------------------------
lint "invented control" ui-label-unverified $'1. Select **Publish**.\n'
lint "case matters" ui-label-unverified $'1. Select **submit**.\n'
lint "a near miss" ui-label-unverified $'1. Select **New expenses**.\n'
lint "one bad among good" ui-label-unverified $'1. Select **New expense**.\n2. Select **Frobnicate**.\n'
lint "allowed term passes" pass $'1. Select **Publish**.\n' --allow "Publish"
lint "allow does not cover other terms" ui-label-unverified $'1. Select **Publish**.\n2. Select **Deploy**.\n' --allow "Publish"
lint "bold in a heading is not judged" pass $'1. Select **Submit**.\n'
printf '# Create **an** expense\n\nYou will have a saved expense.\n\n## Prerequisites\n\n- Access.\n\n## Steps\n\n1. Select **Submit**.\n' >"$WORK/h.md"
"$CLI" lint "$WORK/h.md" --source "$SRC" --keys "$KEYS" >/dev/null 2>&1 && ok || bad "bold in a heading should not be judged"
printf '%s' "$GOOD_HEAD"$'1. Select **Submit**.\n\n```\nclick **Anything** here\n```\n'"$GOOD_TAIL" >"$WORK/f.md"
"$CLI" lint "$WORK/f.md" --source "$SRC" --keys "$KEYS" >/dev/null 2>&1 && ok || bad "bold inside a code fence should be ignored"

# --- menu paths -----------------------------------------------------------------------------------
lint "arrow separator" menu-separator $'1. Select **File** -> **Settings**.\n'
lint "unicode arrow" menu-separator $'1. Select **File** → **Settings**.\n'
lint "unbolded menu path" menu-bold $'1. Select File > Settings.\n'

# --- sensory and positional language ----------------------------------------------------------------
lint "on the left" sensory-language $'1. Select **Submit** on the left.\n'
lint "colour" sensory-language $'1. Select the green button, then **Submit**.\n'
lint "below" sensory-language $'1. Select the field below, then **Submit**.\n'
lint "top-right" sensory-language $'1. Select **Submit** in the top-right corner.\n'
lint "size" sensory-language $'1. Select the big button.\n'
lint "next to" sensory-language $'1. Select the icon next to the name.\n'
lint "right-click is an action, not a position" pass $'1. Right-click the row, then select **Submit**.\n'
lint "a bold label may contain direction words" pass $'1. Select **Submit**.\n'

# --- filler and leftovers ----------------------------------------------------------------------------
lint "simply" filler-word $'1. Simply select **Submit**.\n'
lint "easily" filler-word $'1. You can easily select **Submit**.\n'
lint "TODO" placeholder $'1. Select **Submit**. TODO check this.\n'
lint "angle placeholder" placeholder $'1. Enter the <amount>.\n'

# --- structure -------------------------------------------------------------------------------------------
lint "step gap" step-number $'1. Select **New expense**.\n3. Select **Submit**.\n'
lint "steps not starting at 1" step-number $'2. Select **Submit**.\n'
printf '# Guide\n\nShort.\n\n## Steps\n\n1. Select **Submit**.\n' >"$WORK/p.md"
rc=0; "$CLI" lint "$WORK/p.md" --source "$SRC" --keys "$KEYS" >"$WORK/out" 2>&1 || rc=$?
[[ "$rc" -eq 3 ]] && grep -q 'prerequisites-missing' "$WORK/out" && ok || bad "missing prerequisites should fail"
printf '# Guide\n\n1. Select **Submit**.\n\n## Prerequisites\n\n- Access.\n' >"$WORK/p2.md"
rc=0; "$CLI" lint "$WORK/p2.md" --source "$SRC" --keys "$KEYS" >"$WORK/out" 2>&1 || rc=$?
[[ "$rc" -eq 3 ]] && grep -q 'prerequisites-missing' "$WORK/out" && ok || bad "prerequisites after the steps should fail"
printf '# Guide\n\n## Prerequisites\n\n- Access.\n\nNo steps here.\n' >"$WORK/n.md"
rc=0; "$CLI" lint "$WORK/n.md" --source "$SRC" --keys "$KEYS" >"$WORK/out" 2>&1 || rc=$?
[[ "$rc" -eq 3 ]] && grep -q 'no-steps' "$WORK/out" && ok || bad "a guide with no steps should fail"

# The unfilled template must never pass.
"$CLI" template >"$WORK/t.md"
rc=0; "$CLI" lint "$WORK/t.md" --source "$SRC" --keys "$KEYS" >"$WORK/out" 2>&1 || rc=$?
[[ "$rc" -eq 3 ]] && grep -q 'placeholder' "$WORK/out" && grep -q 'ui-label-unverified' "$WORK/out" && ok || bad "the unfilled template should fail on placeholders and labels"

# --- output and exit codes -----------------------------------------------------------------------------------
printf '%s%s%s' "$GOOD_HEAD" $'1. Select **Publish**.\n' "$GOOD_TAIL" >"$WORK/g.md"
"$CLI" lint "$WORK/g.md" --source "$SRC" --keys "$KEYS" >"$WORK/out" 2>&1 || true
grep -Eq '^.*g\.md:[0-9]+: ui-label-unverified: ' "$WORK/out" && ok || bad "finding format file:line: rule: message"
grep -q 'Examined: guide ' "$WORK/out" && ok || bad "lint should print what it examined"
grep -Eq 'Checked [0-9]+ bold element\(s\) against [0-9]+ source label\(s\)' "$WORK/out" && ok || bad "lint should print a summary"
# The line number points at the offending line.
n="$(grep -n 'Publish' "$WORK/g.md" | head -1 | cut -d: -f1)"
grep -q "g.md:$n: ui-label-unverified" "$WORK/out" && ok || bad "finding should carry the offending line number ($n)"

"$CLI" lint >/dev/null 2>&1 && bad "lint with no args is a usage error" || { [[ $? -eq 2 ]] && ok || bad "lint usage exit"; }
"$CLI" lint "$WORK/g.md" >/dev/null 2>&1 && bad "lint without --source is a usage error" || { [[ $? -eq 2 ]] && ok || bad "lint --source usage exit"; }
"$CLI" lint "$WORK/missing.md" --source "$SRC" >/dev/null 2>&1 && bad "missing guide should fail" || { [[ $? -eq 1 ]] && ok || bad "missing guide exit"; }
: >"$WORK/s.png"
"$CLI" lint "$WORK/g.md" --source "$WORK/s.png" >/dev/null 2>"$WORK/e" && bad "an image source should be refused" || { [[ $? -eq 1 ]] && grep -q 'not a definition' "$WORK/e" && ok || bad "image source refusal"; }
"$CLI" lint "$WORK/g.md" --source "$SRC" --keys nope >/dev/null 2>"$WORK/e" && bad "no labels should fail, not pass" || { [[ $? -eq 1 ]] && grep -q 'nothing to verify' "$WORK/e" && ok || bad "no-labels refusal"; }
"$CLI" bogus >/dev/null 2>&1 && bad "unknown command" || { [[ $? -eq 2 ]] && ok || bad "unknown command exit"; }

# A guide checked against the YAML source with Power Fx quoting.
printf '%s%s%s' "$GOOD_HEAD" $'1. Select **Refresh**, then **Submit**.\n' "$GOOD_TAIL" >"$WORK/y.md"
"$CLI" lint "$WORK/y.md" --source "$PLUGIN_ROOT/tests/fixtures/app.pa.yaml" --keys Text,HintText >/dev/null 2>&1 && ok || bad "guide against the YAML source should pass"

echo "test-lint.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
