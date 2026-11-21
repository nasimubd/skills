#!/usr/bin/env bash
# End-to-end tests for hooks/guard-bash.sh and the change-guardrails command: the real hook
# JSON, fail-open behaviour, the audit log, and the manifest. Auto-discovered by
# test-marketplace-hook-regression-suite. Run it under /bin/bash on macOS (bash 3.2).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_ROOT/hooks/guard-bash.sh"
CLI="$PLUGIN_ROOT/bin/change-guardrails"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
export CHANGE_GUARDRAILS_CONFIG_DIR="$WORK/config"
export CHANGE_GUARDRAILS_STATE_DIR="$WORK/state"
mkdir -p "$CHANGE_GUARDRAILS_CONFIG_DIR"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }

hook_out() {
  jq -n --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}' | /bin/bash "$HOOK"
}

decision() {
  local out
  out="$(hook_out "$1")"
  if [[ -z "$out" ]]; then echo allow; else jq -r '.hookSpecificOutput.permissionDecision' <<<"$out"; fi
}

expect() {
  local want="$1" desc="$2" got
  got="$(decision "$3")"
  if [[ "$got" == "$want" ]]; then ok; else bad "$desc: expected $want, got $got"; fi
}

# --- decisions through the real hook ----------------------------------------------------
expect deny "force push to main" 'git push --force origin main'
expect ask "reset hard" 'git reset --hard'
expect allow "ls" 'ls -la'
expect allow "an ordinary commit" 'git commit -m "feat: add thing"'

# The output shape the host expects: nested hookSpecificOutput, PreToolUse, a reason.
out="$(hook_out 'git push --force origin main')"
if [[ "$(jq -r '.hookSpecificOutput.hookEventName' <<<"$out")" == "PreToolUse" ]]; then ok; else bad "hookEventName missing"; fi
if [[ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$out")" == *push-force-protected* ]]; then ok; else bad "reason should name the rule"; fi
if [[ "$(jq -r 'has("decision")' <<<"$out")" == "false" ]]; then ok; else bad "must not use the deprecated top-level decision"; fi

# Marker: deny becomes ask and the reason shows the agent's stated reason.
out="$(hook_out 'git push --force origin main # GUARD-OK: maintainer asked after a leaked secret in history')"
if [[ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$out")" == "ask" ]]; then ok; else bad "marker should produce ask"; fi
if [[ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$out")" == *"leaked secret"* ]]; then ok; else bad "ask reason should show the stated reason"; fi

# --- fail open on the hook's own failures ---------------------------------------------------
out="$(printf 'not json' | /bin/bash "$HOOK")"
if [[ -z "$out" ]]; then ok; else bad "invalid JSON should allow"; fi
out="$(printf '{}' | /bin/bash "$HOOK")"
if [[ -z "$out" ]]; then ok; else bad "no command should allow"; fi
out="$(printf '' | /bin/bash "$HOOK")"
if [[ -z "$out" ]]; then ok; else bad "empty input should allow"; fi

# No jq on PATH: fail open (and health says so).
STUB="$WORK/stub"
mkdir -p "$STUB"
for t in bash cat awk grep sed tr head date mkdir dirname wc tail; do
  p="$(command -v "$t" || true)"
  [[ -n "$p" ]] && ln -s "$p" "$STUB/$t"
done
out="$(jq -n '{tool_name:"Bash",tool_input:{command:"rm -rf /"}}' | env -i PATH="$STUB" /bin/bash "$HOOK")"
if [[ -z "$out" ]]; then ok; else bad "without jq the hook should fail open"; fi
if env -i PATH="$STUB" HOME="$WORK" CHANGE_GUARDRAILS_STATE_DIR="$WORK/state2" /bin/bash "$PLUGIN_ROOT/scripts/change-guardrails.sh" health >"$WORK/health-nojq.txt" 2>&1; then
  bad "health should fail without jq"
else
  grep -q 'jq not found' "$WORK/health-nojq.txt" && ok || bad "health should say jq is missing"
fi

# A broken rules file: every command asks and says where.
printf 'garbage line\n' >"$CHANGE_GUARDRAILS_CONFIG_DIR/rules"
out="$(hook_out 'ls')"
if [[ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$out")" == "ask" ]]; then ok; else bad "broken rules should ask"; fi
if [[ "$(jq -r '.hookSpecificOutput.permissionDecisionReason' <<<"$out")" == *"rules:1:"* ]]; then ok; else bad "reason should name file and line"; fi
rm -f "$CHANGE_GUARDRAILS_CONFIG_DIR/rules"

# --- the audit log records decisions, never commands -------------------------------------------
rm -rf "$CHANGE_GUARDRAILS_STATE_DIR"
hook_out 'git push --force origin main # token=SUPERSECRETVALUE123' >/dev/null
hook_out 'git reset --hard' >/dev/null
hook_out 'ls' >/dev/null
LOG="$CHANGE_GUARDRAILS_STATE_DIR/audit.log"
if [[ -f "$LOG" && "$(wc -l <"$LOG" | tr -d ' ')" == "2" ]]; then ok; else bad "audit log should have exactly the 2 non-allow decisions"; fi
if grep -q 'SUPERSECRETVALUE123' "$LOG" 2>/dev/null; then bad "audit log must not contain command text"; else ok; fi
if grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z deny push-force-protected(,[a-z-]+)*$' "$LOG"; then ok; else bad "audit line format: $(head -1 "$LOG")"; fi

# An unwritable state folder must not break the decision.
printf 'x' >"$WORK/notadir"
out="$(jq -n '{tool_name:"Bash",tool_input:{command:"git push -f origin main"}}' | CHANGE_GUARDRAILS_STATE_DIR="$WORK/notadir/sub" /bin/bash "$HOOK")"
if [[ "$(jq -r '.hookSpecificOutput.permissionDecision' <<<"$out")" == "deny" ]]; then ok; else bad "unwritable audit folder must not change the decision"; fi

# --- the command -----------------------------------------------------------------------------------
if "$CLI" check 'ls' >/dev/null; then ok; else bad "check ls should exit 0"; fi
"$CLI" check 'git push --force origin main' >"$WORK/check.txt" && rc=0 || rc=$?
if [[ "$rc" -eq 3 ]]; then ok; else bad "check of a denied command should exit 3, got $rc"; fi
grep -q 'push-force-protected' "$WORK/check.txt" && grep -q 'Decision: deny' "$WORK/check.txt" && ok || bad "check should print rule and decision"
"$CLI" check 'echo "rm -rf /"' >"$WORK/check2.txt" && ok || bad "quoted mention should be allowed"
grep -q 'echo $' "$WORK/check2.txt" && ok || bad "check should print the normalised text it examined"
"$CLI" check >/dev/null 2>&1 && bad "check with no command should be a usage error" || { [[ $? -eq 2 ]] && ok || bad "check usage exit code should be 2"; }
"$CLI" bogus >/dev/null 2>&1 && bad "unknown command should fail" || { [[ $? -eq 2 ]] && ok || bad "unknown command exit code should be 2"; }
"$CLI" health >"$WORK/health.txt" && ok || { bad "health should pass in a clean environment"; cat "$WORK/health.txt"; }
grep -q 'Checked: ' "$WORK/health.txt" && ok || bad "health should print a count"
"$CLI" rules >"$WORK/rules.txt" && ok || bad "rules should exit 0"
grep -q 'push-force-protected' "$WORK/rules.txt" && ok || bad "rules should list push-force-protected"
printf 'disable@@git-reset-hard\n' >"$CHANGE_GUARDRAILS_CONFIG_DIR/rules"
"$CLI" rules >"$WORK/rules2.txt" || true
grep -q 'git-reset-hard.*disabled by the user file' "$WORK/rules2.txt" && ok || bad "rules should flag a disabled rule"
"$CLI" health >"$WORK/health3.txt" || true
grep -q 'rules disabled by the user file: git-reset-hard' "$WORK/health3.txt" && ok || bad "health should list disabled rules"
rm -f "$CHANGE_GUARDRAILS_CONFIG_DIR/rules"
"$CLI" log 5 >"$WORK/log.txt" || true
grep -q 'push-force-protected' "$WORK/log.txt" && ok || bad "log should show recent decisions"
"$CLI" log abc >/dev/null 2>&1 && bad "log with a non-number should be a usage error" || { [[ $? -eq 2 ]] && ok || bad "log usage exit code should be 2"; }

# Self-test inside health notices a disabled push rule.
printf 'disable@@push-force-protected\ndisable@@git-force-push\n' >"$CHANGE_GUARDRAILS_CONFIG_DIR/rules"
"$CLI" health >"$WORK/health2.txt" && bad "health should fail when the push rules are disabled" || { grep -q 'self-test' "$WORK/health2.txt" && ok || bad "health should explain the failed self-test"; }
rm -f "$CHANGE_GUARDRAILS_CONFIG_DIR/rules"

# --- the manifest ---------------------------------------------------------------------------------------
HOOKS="$PLUGIN_ROOT/hooks/hooks.json"
if jq -e . "$HOOKS" >/dev/null 2>&1; then ok; else bad "hooks.json must be valid JSON"; fi
if [[ "$(jq -r '.hooks.PreToolUse[0].matcher | type' "$HOOKS")" == "string" ]]; then ok; else bad "matcher must be a single string"; fi
if [[ "$(jq -r '.hooks.PreToolUse[0].matcher' "$HOOKS")" == "Bash" ]]; then ok; else bad "matcher should be Bash"; fi
if [[ "$(jq -r '.hooks.PreToolUse[0].hooks[0].command' "$HOOKS")" == *'${CLAUDE_PLUGIN_ROOT}/hooks/guard-bash.sh'* ]]; then ok; else bad "command should use CLAUDE_PLUGIN_ROOT"; fi
if [[ "$(jq -r '.hooks.PreToolUse[0].hooks[0].timeout' "$HOOKS")" == "10" ]]; then ok; else bad "timeout should be 10"; fi
if [[ "$(jq 'has("version")' "$PLUGIN_ROOT/plugin.json")" == "false" ]]; then ok; else bad "plugin.json must not carry a version"; fi

# --- speed: a hook that is slow gets timed out -----------------------------------------------------------
start=$SECONDS
for _ in 1 2 3 4 5; do hook_out 'git push --force origin main' >/dev/null; done
elapsed=$((SECONDS - start))
if [[ "$elapsed" -le 5 ]]; then ok; else bad "five hook runs took ${elapsed}s; budget is 1s each"; fi

echo "test-hook.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
