#!/usr/bin/env bash
# Tests for `snapshot create|verify|list|restore`. Auto-discovered by
# test-marketplace-hook-regression-suite. Run under /bin/bash on macOS (bash 3.2).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$PLUGIN_ROOT/bin/investigation-tools"
WORK="$(mktemp -d)"
trap 'chmod -R u+rwx "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
export INVESTIGATION_TOOLS_STATE_DIR="$WORK/state"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

# --- a small "definition" to protect: a file with a space in its name, and a folder ---------
mkdir -p "$WORK/src/flows"
printf '{"name":"export","mapping":{"amount":"amount_total"}}\n' >"$WORK/src/flow one.json"
printf 'schedule: nightly\n' >"$WORK/src/flows/schedule.yaml"
printf 'second\n' >"$WORK/src/flows/second.txt"

# --- create -----------------------------------------------------------------------------------
out="$("$CLI" snapshot create "Export Flow!!" "$WORK/src/flow one.json" "$WORK/src/flows")"
SNAP="$(printf '%s\n' "$out" | sed -n 's/^Snapshot: //p')"
[[ -d "$SNAP" ]] && ok || bad "create should print and make the snapshot folder"
case "$SNAP" in *-export-flow) ok ;; *) bad "label should be sanitised to export-flow, got $SNAP" ;; esac
printf '%s\n' "$out" | grep -q '^Files: 3 ' && ok || bad "create should report 3 files: $out"
[[ -f "$SNAP/MANIFEST.sha256" && -f "$SNAP/meta.txt" ]] && ok || bad "manifest and meta missing"
[[ "$(wc -l <"$SNAP/MANIFEST.sha256" | tr -d ' ')" == "3" ]] && ok || bad "manifest should list 3 files"
grep -q 'files/1/flow one.json' "$SNAP/MANIFEST.sha256" && ok || bad "a file with a space in its name should be recorded"
grep -q 'files/2/flows/schedule.yaml' "$SNAP/MANIFEST.sha256" && ok || bad "a folder should be copied recursively"
grep -q '^label: export-flow' "$SNAP/meta.txt" && grep -q '^source 1: ' "$SNAP/meta.txt" && ok || bad "meta should record the label and sources"

# permissions: owner only
perm="$(stat -f '%Lp' "$SNAP" 2>/dev/null || stat -c '%a' "$SNAP")"
[[ "$perm" == "700" ]] && ok || bad "snapshot folder should be mode 700, got $perm"
fperm="$(stat -f '%Lp' "$SNAP/files/1/flow one.json" 2>/dev/null || stat -c '%a' "$SNAP/files/1/flow one.json")"
[[ "$fperm" == *00 ]] && ok || bad "snapshot files should not be group or world accessible, got $fperm"

# the original is untouched
[[ "$(cat "$WORK/src/flows/second.txt")" == "second" ]] && ok || bad "create must not touch the originals"

# --- verify ----------------------------------------------------------------------------------------
"$CLI" snapshot verify "$SNAP" >"$WORK/o" 2>&1 && ok || bad "a fresh snapshot should verify: $(cat "$WORK/o")"
grep -q 'problems: 0' "$WORK/o" && ok || bad "verify should report zero problems"

printf 'tampered' >>"$SNAP/files/2/flows/second.txt"
"$CLI" snapshot verify "$SNAP" >"$WORK/o" 2>&1 && bad "a changed file should fail verify" || { [[ $? -eq 3 ]] && grep -q 'CHANGED  files/2/flows/second.txt' "$WORK/o" && ok || bad "changed-file report/exit: $(cat "$WORK/o")"; }
printf 'second\n' >"$SNAP/files/2/flows/second.txt"
"$CLI" snapshot verify "$SNAP" >/dev/null 2>&1 && ok || bad "restoring the content should verify again"

rm "$SNAP/files/2/flows/schedule.yaml"
"$CLI" snapshot verify "$SNAP" >"$WORK/o" 2>&1 && bad "a missing file should fail verify" || { grep -q 'MISSING  files/2/flows/schedule.yaml' "$WORK/o" && ok || bad "missing-file report"; }
printf 'schedule: nightly\n' >"$SNAP/files/2/flows/schedule.yaml"

printf 'sneaky' >"$SNAP/files/2/flows/extra.txt"
"$CLI" snapshot verify "$SNAP" >"$WORK/o" 2>&1 && bad "an added file should fail verify" || { grep -q 'EXTRA    files/2/flows/extra.txt' "$WORK/o" && ok || bad "extra-file report: $(cat "$WORK/o")"; }
rm "$SNAP/files/2/flows/extra.txt"
"$CLI" snapshot verify "$SNAP" >/dev/null 2>&1 && ok || bad "removing the extra file should verify again"

# --- restore ---------------------------------------------------------------------------------------
"$CLI" snapshot restore "$SNAP" "$WORK/restored" >"$WORK/o" 2>&1 && ok || bad "restore into a new folder: $(cat "$WORK/o")"
[[ "$(cat "$WORK/restored/1/flow one.json")" == "$(cat "$WORK/src/flow one.json")" ]] && ok || bad "restored file should equal the original"
diff -r "$WORK/restored/2/flows" "$WORK/src/flows" >/dev/null && ok || bad "restored folder should equal the original"
grep -q 'source 1: ' "$WORK/o" && ok || bad "restore should say where each file came from"
grep -q 'originals untouched' "$WORK/o" && ok || bad "restore should say the originals are untouched"

"$CLI" snapshot restore "$SNAP" "$WORK/restored" >/dev/null 2>"$WORK/e" && bad "restore into a non-empty folder must be refused" || { [[ $? -eq 1 ]] && grep -q 'never overwrites' "$WORK/e" && ok || bad "non-empty refusal"; }
mkdir "$WORK/emptydest"
"$CLI" snapshot restore "$SNAP" "$WORK/emptydest" >/dev/null 2>&1 && ok || bad "an existing empty folder is a valid destination"

printf 'tampered' >>"$SNAP/files/2/flows/second.txt"
"$CLI" snapshot restore "$SNAP" "$WORK/never" >/dev/null 2>"$WORK/e" && bad "a snapshot that does not verify must not be restored" || { [[ $? -eq 3 ]] && [[ ! -e "$WORK/never" ]] && ok || bad "tampered restore refusal or destination was created"; }
printf 'second\n' >"$SNAP/files/2/flows/second.txt"

# --- list ----------------------------------------------------------------------------------------------
"$CLI" snapshot list >"$WORK/o" 2>&1 && grep -q 'Snapshots: 1' "$WORK/o" && grep -q "$SNAP" "$WORK/o" && ok || bad "list should show the snapshot: $(cat "$WORK/o")"

# --- refusals: nothing is created on a bad request -------------------------------------------------------
before="$("$CLI" snapshot list | tail -1)"
"$CLI" snapshot create "x" "$WORK/src/flow one.json" "$WORK/does-not-exist" >/dev/null 2>"$WORK/e" && bad "a missing path must fail" || { [[ $? -eq 1 ]] && grep -q 'no snapshot was made' "$WORK/e" && ok || bad "missing path message"; }
[[ "$("$CLI" snapshot list | tail -1)" == "$before" ]] && ok || bad "a failed create must not leave a snapshot behind"
"$CLI" snapshot create >/dev/null 2>&1 && bad "create with no args is a usage error" || { [[ $? -eq 2 ]] && ok || bad "create usage exit"; }
"$CLI" snapshot create "label-only" >/dev/null 2>&1 && bad "create without paths is a usage error" || { [[ $? -eq 2 ]] && ok || bad "create paths usage exit"; }
"$CLI" snapshot create '!!!' "$WORK/src/flow one.json" >/dev/null 2>&1 && bad "an unusable label is a usage error" || { [[ $? -eq 2 ]] && ok || bad "label usage exit"; }
"$CLI" snapshot verify "$WORK/src" >/dev/null 2>&1 && bad "verify on a non-snapshot must fail" || { [[ $? -eq 1 ]] && ok || bad "verify non-snapshot exit"; }
"$CLI" snapshot bogus >/dev/null 2>&1 && bad "unknown snapshot subcommand" || { [[ $? -eq 2 ]] && ok || bad "snapshot usage exit"; }

# --- secrets: the snapshot warns, never prints the value ---------------------------------------------------
printf 'password = SUPERSECRETVALUE99\n' >"$WORK/src/secret.cfg"
out="$("$CLI" snapshot create "with-secret" "$WORK/src/secret.cfg")"
printf '%s\n' "$out" | grep -q 'secret-like strings' && ok || bad "snapshot of a file with a secret should warn"
printf '%s\n' "$out" | grep -q 'SUPERSECRETVALUE99' && bad "the warning must not print the value" || ok

# two snapshots in the same second do not collide
a="$("$CLI" snapshot create "twin" "$WORK/src/flow one.json" | sed -n 's/^Snapshot: //p')"
b="$("$CLI" snapshot create "twin" "$WORK/src/flow one.json" | sed -n 's/^Snapshot: //p')"
[[ "$a" != "$b" && -d "$a" && -d "$b" ]] && ok || bad "snapshots made in the same second must not collide"

echo "test-snapshot.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
