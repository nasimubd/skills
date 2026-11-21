# change-guardrails — maintainer notes

**Hub**: [Root CLAUDE.md](../../CLAUDE.md) | **Sibling**: [plugins/CLAUDE.md](../CLAUDE.md)

Invariants and decisions that aren't obvious from reading the code. The decision record is
[docs/adr/2026-11-12-change-guardrails.md](../../docs/adr/2026-11-12-change-guardrails.md) and the
build is in [docs/design/2026-11-12-change-guardrails/spec.md](../../docs/design/2026-11-12-change-guardrails/spec.md).

## The shape

One `PreToolUse` hook on `Bash` (`hooks/guard-bash.sh`) and one command (`bin/change-guardrails`).
Both call `lib/guard.sh`, so the command a person tests with `check` is judged by the same
code as a live call. Rules are data in `policy/default.rules`. Tier 1 only: the guard never
acts for the user, it only stops or asks.

## Invariants (do not weaken)

- **Two decisions only, `deny` and `ask`.** `defer` is ignored in interactive sessions.
- **The escape marker turns a `deny` into an `ask`, never an allow.** A marker the agent can
  type to pass silently would defend nothing; text it reads from a ticket can contain one.
- **Fail open on the hook's own failures** (bad input, no `jq`, crash). **Fail closed on a
  broken rules file** (every command asks). Do not "simplify" these into one rule: they are
  different failures with different dangers.
- **The audit log never contains the command text.** A test seeds a secret and checks it.
- **bash 3.2.** No associative arrays, no `mapfile`, no `${x,,}`, no `&` in a
  `${var//pat/rep}` replacement (bash 5.2 treats it as the match), and **no `[a-z]` ranges
  for validation**: on macOS the range is locale-dependent and let an uppercase id through.
  The tests run under `/bin/bash`.
- **Every default rule needs a positive and a negative test** in `tests/test-rules.sh`.

## Things that look wrong but are deliberate

- **`{B}` instead of `\b`.** BSD `grep -E` has no `\b`. `{B}` expands to
  `(^|[^[:alnum:]_.-])`, which also matches after a path slash (`/bin/rm`).
- **Several regexes use `([^;&|]*[[:space:]])?` instead of `[^;&|]*[[:space:]]`.** The second
  form needs two spaces where a command has one; three rules shipped with that bug and the
  tests caught it.
- **`git push -f origin main-fix` asks, it is not denied.** Only exact protected names deny.
- **`sql` rules need a database client on the line.** Without that, `echo "DROP TABLE"` or a
  grep through migrations would be stopped.
- **`bash -c` and `eval` strings are kept whole, other quoted strings are blanked.** The
  first are code, the second data. A message quoting a command must not trigger a rule.
- **The shipped rules cannot `disable` anything.** Only the user's file can, and `health`
  lists what it turned off.
- **A broken user file makes every command ask.** Annoying on purpose; see the ADR.

## Not covered

Write and Edit (protected paths) are deferred. Commands built at run time, scripts written
then run, and remote execution over `ssh` are invisible to pattern matching and listed in
`references/rules.md`. Do not claim more than that in the README.
