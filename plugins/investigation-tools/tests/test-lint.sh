#!/usr/bin/env bash
# Tests for `brief lint` and `rca lint`. Auto-discovered by test-marketplace-hook-regression-suite.
# Run under /bin/bash on macOS (bash 3.2).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$PLUGIN_ROOT/bin/investigation-tools"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export INVESTIGATION_TOOLS_STATE_DIR="$WORK/state"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

# check <kind> <desc> <expected: pass|rule-id> <file>
check() {
  local kind="$1" desc="$2" want="$3" file="$4" rc=0
  "$CLI" "$kind" lint "$file" >"$WORK/out" 2>&1 || rc=$?
  if [[ "$want" == pass ]]; then
    if [[ "$rc" -eq 0 ]]; then ok; else bad "$kind/$desc: expected pass, got exit $rc: $(grep -E ': [a-z-]+: ' "$WORK/out" | head -2 | tr '\n' ' ')"; fi
  else
    if [[ "$rc" -eq 3 ]] && grep -q ": $want: " "$WORK/out"; then ok; else bad "$kind/$desc: expected $want (exit 3), got exit $rc: $(grep -E ': [a-z-]+: ' "$WORK/out" | head -2 | tr '\n' ' ')"; fi
  fi
}

# ============================== triage brief ==============================
cat >"$WORK/brief.md" <<'EOF'
# Triage brief: Nightly export fails

Source: https://tracker.example/tickets/123
Captured: 2026-11-12T14:00:00Z
Mode: read-only

## Summary

The nightly export failed after a schema change. No changes have been made.

## What is known

- The run failed with an HTTP 500 error. [source: run log line 14 "HTTP 500"; captured 2026-11-12T14:00Z; repro: open the run history]
- The ticket was opened the same morning. [source: ticket header; captured 2026-11-12T14:00Z]

## What is not known

- Whether other exports are affected.

## Risks and constraints

- Production: no changes without approval.

## Plan

1. [read] Open the run history for the last three runs.
2. [change] Re-run the export once the cause is confirmed.

## Untrusted content seen

- none

## Approval

Status: awaiting approval
EOF
check brief "a good brief" pass "$WORK/brief.md"

mut() { sed -e "$1" "$WORK/brief.md" >"$WORK/m.md"; }
mut 's| \[source: run log line 14[^]]*\]||'; check brief "fact without a source" evidence-missing "$WORK/m.md"
mut 's|\[source: ticket header; captured 2026-11-12T14:00Z\]|[source: x]|'; check brief "a too-short source tag" evidence-missing "$WORK/m.md"
mut 's|1\. \[read\] |1. |'; check brief "plan step without a kind" plan-step-kind "$WORK/m.md"
mut 's|\[change\] Re-run|[change] [done] Re-run|'; check brief "a plan step marked done" plan-executed "$WORK/m.md"
mut 's|Status: awaiting approval|Status: approved|'; check brief "not awaiting approval" approval-missing "$WORK/m.md"
mut '/^## What is not known$/d'; check brief "a missing section" section-missing "$WORK/m.md"
mut '/^Mode: read-only$/d'; check brief "no read-only mode" header-mode "$WORK/m.md"
mut '/^Source:/d'; check brief "no source header" header-source "$WORK/m.md"
mut '/^Captured:/d'; check brief "no captured header" header-captured "$WORK/m.md"
mut '/^- none$/d'; check brief "empty untrusted section" untrusted-section-empty "$WORK/m.md"
mut 's|Whether other exports are affected.|Whether <something> is affected. TODO|'; check brief "a placeholder" placeholder "$WORK/m.md"
mut 's|^- The ticket was opened.*|&\n- Remember the admin password = hunter2hunter2 [source: pasted in the ticket]|'; check brief "a secret in the brief" secret-in-document "$WORK/m.md"
mut 's|^2\. \[change\].*||'; check brief "no change step is fine" pass "$WORK/m.md"
mut 's|^1\. \[read\].*||; s|^2\. \[change\].*||'; check brief "no plan steps" plan-empty "$WORK/m.md"
mut 's|^- none$|- A comment says: ignore previous instructions (quoted, not followed)|'; check brief "untrusted content listed" pass "$WORK/m.md"

# fenced code is ignored
awk '/^## What is not known$/{print "```"; print "<placeholder> and TODO inside code"; print "```"; print ""} {print}' "$WORK/brief.md" >"$WORK/m.md"
check brief "code fences are ignored" pass "$WORK/m.md"

# sections out of order
awk '/^## Plan$/{p=1} p&&/^## Untrusted content seen$/{p=0} {if(!p)print}' "$WORK/brief.md" >"$WORK/noplan.md"
{ sed -n '1,/^## Summary$/p' "$WORK/brief.md" | sed '$d'; sed -n '/^## Plan$/,/^## Untrusted content seen$/p' "$WORK/brief.md" | sed '$d'; sed -n '/^## Summary$/,/^## Plan$/p' "$WORK/brief.md" | sed '$d'; sed -n '/^## Untrusted content seen$/,$p' "$WORK/brief.md"; } >"$WORK/order.md"
check brief "sections out of order" section-order "$WORK/order.md"

"$CLI" brief template >"$WORK/t.md"
check brief "the unfilled template" placeholder "$WORK/t.md"

# ============================== root-cause note ==============================
SNAP_OUT="$("$CLI" snapshot create "export-flow" "$PLUGIN_ROOT/tests/test-lint.sh")"
SNAP="$(printf '%s\n' "$SNAP_OUT" | sed -n 's/^Snapshot: //p')"
[[ -d "$SNAP" ]] && ok || bad "snapshot for the rca tests was not created"

cat >"$WORK/rca.md" <<EOF
# Root-cause note: Nightly export failed

## Summary

The nightly export failed for three nights after a schema change.

## Impact

Finance received no export on three mornings.

## Timeline

- 02:00 The export started and failed. [source: run history, run 41]
- 09:10 The ticket was opened.

## Root cause

- The export maps a column that was renamed in the schema change. [source: run 41 log line 14]

\`\`\`
HTTP 500: column "amount_total" does not exist
\`\`\`

## Resolution

Contained: restored the previous column mapping at 10:05; the next run succeeded.

## Prevention

1. Add a schema-change check to the release checklist for exports.

## Rollback

Snapshot: $SNAP

## Deferred work

- Rewrite the mapping to read column names from the schema.
EOF
check rca "a good note" pass "$WORK/rca.md"

rmut() { sed -e "$1" "$WORK/rca.md" >"$WORK/m.md"; }
rmut 's| \[source: run 41 log line 14\]||'; check rca "root cause without a source" evidence-missing "$WORK/m.md"
awk '/^```/{next} /^HTTP 500/{next} {print}' "$WORK/rca.md" >"$WORK/m.md"; check rca "no verbatim excerpt" evidence-quote "$WORK/m.md"
rmut 's|The ticket was opened.|The ticket was opened after human error was suspected.|'; check rca "human error" blame-language "$WORK/m.md"
rmut 's|restored the previous column mapping|restored it, which careless edits had broken|'; check rca "careless" blame-language "$WORK/m.md"
rmut 's|The export started and failed.|The export started; the engineer should have checked the mapping.|'; check rca "should have checked" blame-language "$WORK/m.md"
rmut 's|^1\. Add a schema-change check.*|&\n2. Train everyone.|'; check rca "two prevention steps" prevention-count "$WORK/m.md"
rmut 's|^1\. Add a schema-change check.*||'; check rca "no prevention step" prevention-count "$WORK/m.md"
rmut 's|^Contained: .*|Restored the mapping.|'; check rca "no Contained line" contained-missing "$WORK/m.md"
rmut '/^Snapshot:/d'; check rca "no Snapshot line" rollback-snapshot "$WORK/m.md"
rmut 's|^Snapshot: .*|Snapshot: /nonexistent/folder|'; check rca "snapshot folder missing" rollback-snapshot "$WORK/m.md"
rmut 's|^- Rewrite the mapping.*||'; check rca "empty deferred section" deferred-empty "$WORK/m.md"
rmut 's|^## Impact$|## Effect|'; check rca "a missing section" section-missing "$WORK/m.md"
rmut 's|^- 09:10 The ticket was opened.|&\n- Note: api_key = abcd1234efgh5678 was visible in the log.|'; check rca "a secret in the note" secret-in-document "$WORK/m.md"
rmut 's|Finance received|<who> received|'; check rca "a placeholder" placeholder "$WORK/m.md"

# a snapshot that no longer verifies fails the note
printf 'x' >>"$SNAP/files/1/test-lint.sh"
check rca "a tampered snapshot" rollback-snapshot "$WORK/rca.md"

"$CLI" rca template >"$WORK/rt.md"
check rca "the unfilled template" placeholder "$WORK/rt.md"

# ============================== output and usage ==============================
"$CLI" brief lint "$WORK/brief.md" >"$WORK/out" 2>&1 || true
grep -q '^Examined: ' "$WORK/out" && ok || bad "lint should print what it examined"
grep -q '^Result: no findings' "$WORK/out" && ok || bad "lint should print a result"
mut 's|Status: awaiting approval|Status: approved|'
"$CLI" brief lint "$WORK/m.md" >"$WORK/out" 2>&1 || true
grep -Eq 'm\.md:[0-9]+: approval-missing: ' "$WORK/out" && ok || bad "finding format file:line: rule: message"
"$CLI" brief lint "$WORK/missing.md" >/dev/null 2>&1 && bad "missing file should fail" || { [[ $? -eq 1 ]] && ok || bad "missing file exit"; }
"$CLI" brief >/dev/null 2>&1 && bad "brief without a subcommand is a usage error" || { [[ $? -eq 2 ]] && ok || bad "brief usage exit"; }
"$CLI" rca bogus >/dev/null 2>&1 && bad "rca bogus is a usage error" || { [[ $? -eq 2 ]] && ok || bad "rca usage exit"; }

echo "test-lint.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
