# change-guardrails: design

How the plugin in [the ADR](../../adr/2026-11-12-change-guardrails.md) is built. The ADR says
what was decided and why; this says how.

## Flow

```
PreToolUse (Bash) ──> hooks/guard-bash.sh ──> lib/guard.sh
                          │                      ├─ load policy (default.rules + user rules)
   stdin: hook JSON       │                      ├─ normalise the command (normalize.awk)
   stdout: decision JSON  │                      ├─ match every rule, strongest decision wins
                          │                      └─ apply the escape marker (deny → ask)
                          └─> audit line (time, decision, rule ids)
```

No match prints nothing and exits 0. A match prints
`{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny|ask","permissionDecisionReason":"…"}}`
and exits 0. The hook never exits 2: the decision JSON is the whole contract, and the host
ignores output on exit 2.

## Normalising the command

`lib/normalize.awk` reduces the command to what would run, in one pass with quote state
carried across lines:

| Input | Treatment |
|---|---|
| Single- or double-quoted string with whitespace | Removed (data) |
| Quoted string without whitespace | Kept (`rm -rf "$HOME"`) |
| String after `sh -c`, `bash -c`, `zsh -c`, `eval` | Kept whole (code) |
| `$( … )` and backticks inside double quotes | Kept (they run) |
| Heredoc body | Removed; the `<<` and tag stay |
| Newline | Becomes ` ; ` so each line is a command |

`raw` and `sql` scopes see the original text with newlines joined by ` ; `.

## Rule evaluation

All rules are evaluated, not the first match, so `check` shows everything that applies and
the audit line names every rule. `deny` beats `ask` beats nothing. A rule listed in the
user's `disable@@` lines is skipped. The marker pattern is
`GUARD-OK:[[:space:]]*[^<[:space:]][^[:cntrl:]]{9,}` (a reason of at least ten characters
that does not start with `<`, which rejects the placeholder `<reason>`); it applies only to a
final `deny`.

## Policy loading and validation

A line is checked for five fields, a known decision and scope, an id of lowercase letters,
digits and hyphens (written as an explicit character list, not a range), a non-empty regex
and message, a regex that compiles (`grep -E` exiting 2), and a unique id. Any problem is
recorded as `file:line: what`; any recorded problem makes the policy broken. A broken policy
turns every decision into `ask` with the problems in the reason.

## The command

`bin/change-guardrails` dispatches to `scripts/change-guardrails.sh`:

| Command | Output | Exit |
|---|---|---|
| `check <command…>` | the normalised text, matched rules, the decision | 0 allow, 3 ask or deny, 2 usage |
| `rules` | every rule with its decision, scope, message, and disabled state | 0, or 3 with problems |
| `health` | one line per check and `Checked: N · failed: M`, including a live self-test | 0 only if all pass |
| `log [N]` | the last N audit lines | 0, 2 on a bad count |

## Files

| Path | Role |
|---|---|
| `hooks/hooks.json`, `hooks/guard-bash.sh` | The hook registration and its entry point |
| `lib/guard.sh`, `lib/normalize.awk` | Policy loading, normalising, evaluation, audit |
| `policy/default.rules` | The shipped rules |
| `scripts/change-guardrails.sh`, `bin/change-guardrails` | The command |
| `skills/check`, `skills/health` | The two skills |
| `references/rules.md` | Rule format, scopes, limits |
| `tests/test-rules.sh`, `tests/test-hook.sh` | Rule and normaliser tests; hook, command and manifest tests |

## Not built yet

Write and Edit guarding (protected paths such as shell start-up files and the hook's own
folder), a rules-pack mechanism, and a stricter mode where a hook failure blocks.
