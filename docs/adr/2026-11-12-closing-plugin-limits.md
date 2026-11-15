# Close the stated limits of the guard, guide and investigation plugins

## Status

**Proposed.** Nothing in this record is built. It is open for the maintainer's decision on the
questions listed under "Open decisions". Evidence:
[docs/design/2026-11-12-closing-plugin-limits/research.md](../design/2026-11-12-closing-plugin-limits/research.md).

Extends [2026-11-12-investigation-tools.md](./2026-11-12-investigation-tools.md) and
[2026-11-12-click-path-guides.md](./2026-11-12-click-path-guides.md); their decisions stand until a
later record supersedes them.

## Context and Problem Statement

The three plugins released in 1.7.0 and 1.8.0 each state a limit in their README:

1. The scans for planted instructions, secrets and blame wording are heuristics, and a passing guide
   lint shows names exist in the source, not that a path works in the running application.
2. `investigation-tools` cannot stop a write; only `change-guardrails` can.
3. The trials behind the release were smoke tests.

A stated limit is honest, but a limit that can be closed should be. This record says which can be,
which cannot, and how, using only what was checked (see the research record for the evidence labels).

## Decision Drivers

- Rules that matter are enforced in code, not in prose (repository convention).
- A claim of safety must not exceed what was verified; a limit that cannot be closed is stated, not hidden.
- The plugins must keep working for anyone on macOS (bash 3.2) and Linux, with no required dependency
  beyond a POSIX shell, awk and an optional JSON tool.
- Evaluation consumes a metered credential, so its scale and whose credential is used is the
  maintainer's decision, not something to adopt silently.

## Considered Options

**Limit 2, enforce read-only inside the plugin**

- **Keep instructions plus a lint and rely on the guard plugin.** Rejected as the only mechanism: it
  leaves the plugin unable to stop anything itself.
- **A hook in the plugin that denies writes while a read-only skill is active.** Rejected: a skill's own
  hook lasts the rest of the session, a plugin agent's hooks are ignored, and a plugin hook is
  session-wide, so a state flag would be needed and a stale flag would block legitimate work.
- **Narrow the shell for a reader with a command pattern.** Rejected: tested and shown not to restrict
  the shell (experiment 2).
- **A forked, tool-restricted agent shipped by the plugin.** Chosen: tested and shown to hold even when
  the parent session is granted write and shell tools (experiment 1).

**Limit 3, evaluation**

- **More hand-run live sessions.** Rejected: more of the same evidence.
- **A third-party evaluation framework.** Rejected for now: heavier setup and a second runner, when the
  host ships its own.
- **The host's own `claude plugin eval` with deterministic graders, several runs per case and a
  stated confidence bound.** Chosen: run end to end on one case during this research (experiment 4).

**Limit 1, heuristics**

- **Embed a secret scanner or an injection classifier.** Rejected: licences (one leading scanner is
  AGPL-3.0), a model or binary dependency, and published evidence that detectors are bypassed by
  adaptive attackers.
- **Keep the pattern scans as tripwires, add architectural controls, offer optional adapters, state the
  residual risk.** Chosen.

## Decision Outcome (proposed)

1. **`triage-brief` reads through a forked reader agent.** The skill declares `context: fork` and
   `agent: investigation-tools:triage-reader`. The agent has `Read`, `Grep`, `Glob` (and `WebFetch`
   if wanted) and explicitly denies `Write`, `Edit`, `NotebookEdit` and `Bash`. It returns the brief as
   text; the main thread writes the file and runs the lints. The guard plugin's hook still covers it
   (experiment 3b). This also removes the raw-fetch scratch file that held a secret in the first trials.
2. **Reading a connector needs the user's own allow-list.** Plugin agents cannot ship MCP servers and
   connector tool names are the user's; a reader that must use one is documented as a user-written agent
   with exact tool names. The plugin ships the file-and-web reader only.
3. **`incident-rca` splits the same way.** Diagnosis runs in the reader; any change stays in the main
   thread, one approved step at a time, with a verified snapshot first.
4. **Untrusted text is datamarked** with a per-run random boundary token and the reader is told that
   anything inside the boundary is data. This is a mitigation, not a guarantee.
5. **Every plugin gets an `evals/` suite** run with the host's tool: deterministic graders first (the
   brief or guide file is checked by pattern, the process by tool-use graders), an LLM grader only
   where unavoidable and validated by hand, `allowed_tools` under `execution:` and a shell grant that
   suits chained commands, a "the skill's text reached the session" check instead of "the skill tool was
   called", and a negative case per plugin (an invented control, a planted instruction, a request to
   write). Release gate: 10 runs per case, every case at 10 of 10 (95% lower bound about 72%), with the
   bound printed in the README. One failure triggers a 20-run rerun before anything is changed.
6. **The first evaluation's finding is fixed first.** In 1 of 3 runs the session skipped the guide
   lint. The skill is restructured so the lint is the last explicit step with its exit code reported, and
   the suite measures the rate again.
7. **Live-source tests use mocks and a public read-only source.** Per-change runs use the host's mocked
   servers; a manual job reads a public issue tracker within its unauthenticated rate limit. No write
   path is tested against a live system without a dedicated test workspace.
8. **Optional adapters, never defaults:** if a secret scanner (gitleaks, betterleaks, detect-secrets) is
   on the path, `scan` also runs it and says so; the guide lint documents a browser check
   (Playwright accessibility assertions) for the part it cannot prove. Neither is a dependency.
9. **Residual risk is written in each README in the same words:** novel injections and adaptive attacks
   remain possible; secrets without a recognisable shape pass; blame cannot be settled by a word list;
   a name in the source is not a working path; and the read-only guarantee holds only for the forked
   step, not for the main thread. Reports say "resisted N static and M adaptive attempts", never "secure".

### Consequences

- Good: limit 2 is closed for the reading step by construction, and the guard plugin remains the second layer.
- Good: limit 3 gets repeatable, multi-run evidence with a stated bound instead of a handful of sessions.
- Good: no new required dependency; the scanners are optional.
- Trade-off: the reader cannot run the plugin's scanners (no shell, and a shell cannot be narrowed),
  so the scans run on the text it returns.
- Trade-off: the enforcement exists only when the skill runs forked; the main thread and any other
  skill are unchanged, and the plugin still cannot set permissions or make a hook fail closed.
- Trade-off: evaluation costs metered credit and its HTML report is published to the vendor's site by
  default; runs use the no-publish option and a cost ceiling.
- Limit that stays: limit 1 is reduced, not closed. Detection is bypassed by adaptive attackers in
  published work, and a string match cannot prove a working path.

## Open decisions (for the maintainer)

1. Build order. Recommended: the forked reader and the lint-reliability fix first, then the suites, then
   the optional adapters and wording.
2. Evaluation credential and scale: whose metered credential runs the suites, and whether the full
   release gate (about 0.15 to 0.3 per run in API-price terms, 10 runs per case) or a 5-run smoke test
   is used per change.
3. Whether the live-source job is wanted at all, and against which public source.

## Provenance

The helpers' reports were checked against primary pages and experiments; claims that were not
re-read are labelled "Reported" in the research record and are not relied on above.
