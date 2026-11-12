# Enforce production-safety rules with a deterministic hook plugin

## Status

Current. Design spec: [docs/design/2026-11-12-change-guardrails/spec.md](../design/2026-11-12-change-guardrails/spec.md).

## Context and Problem Statement

An agent session can run any shell command the user's permission mode allows. Instructions
in a prompt or a SKILL.md ("never force-push", "never delete outside the project") can be
skipped, forgotten after a compaction, or overridden by text the agent reads from a ticket,
a chat message or a web page. The repository's own convention is that rules that matter are
enforced in code (`teams-commander` is the existing example), but each plugin currently has
to write its own gate. The maintainer asked for a general plugin that protects production
and the working machine from the most damaging commands, usable by anyone, with no
organisation-specific content.

The design was checked against a written research brief on 2026-11-12. The brief was
verified against the host's documentation before use; the claims that did not survive are
listed under "Provenance" because they shaped the decisions below.

## Decision Drivers

- A wrong block interrupts real work, so false positives matter as much as misses.
- The host must keep working if the hook itself fails.
- The plugin has to run unchanged on macOS (bash 3.2) and Linux.
- Text the agent reads is untrusted, so an escape that the agent can type for itself is not
  an escape.
- Rules differ per person and per team; the defaults must be small and the extension point
  obvious.

## Considered Options

- **Instructions only (a SKILL.md or CLAUDE.md rule).** Rejected: an instruction can be
  skipped; a hook cannot.
- **A skill that asks the model to judge whether a command is safe.** Rejected: a model
  that is being manipulated cannot be trusted to police itself, and the answer would vary
  between runs.
- **Embed a general policy engine.** Rejected: it adds a binary dependency that breaks the
  bash 3.2 constraint, and the rule set is small enough that a line-based rules file is
  clearer to review.
- **A `PreToolUse` hook on Bash driven by a plain-text rules file.** Chosen.
- **Also guard Write and Edit (protected paths).** Deferred to a later version; the first
  release covers shell commands only.

## Decision Outcome

A plugin, `change-guardrails` (category `enforcement`), with one `PreToolUse` hook on
`Bash`.

1. **Two decisions only: `deny` and `ask`.** `defer` is honoured only in non-interactive
   mode with a single tool call, and interactive sessions ignore it, so it cannot be a
   guard. No match means no output, which leaves the host's normal permission flow alone.
2. **The escape marker turns a `deny` into an `ask`, never into an `allow`.** A command may
   carry `GUARD-OK: <reason of at least ten characters>`. The user then sees the reason and
   approves or refuses. A marker that the agent (or an injected instruction) could type to
   bypass the gate silently would defend nothing.
3. **Fail open on the hook's own failures** (unreadable input, `jq` missing, a crash):
   the host's default for a failing hook is to let the call proceed, and a guard that
   blocks all shell use when it breaks would be uninstalled within a day. `health` reports a
   missing `jq`.
4. **Fail closed when the policy itself is broken.** If the rules file (the shipped one or
   the user's) has a malformed line or an invalid regular expression, every Bash call asks,
   with the file and line in the reason. The alternative, silently ignoring a custom `deny`
   rule, is the dangerous case.
5. **Match what would run, not what is mentioned.** Quoted strings and heredoc bodies are
   blanked before the shell-command rules are applied, so a commit message that quotes a
   destructive command does not trigger it. A quoted argument without whitespace is kept
   (`rm -rf "$HOME"` must still match). SQL rules run on the raw text and only when a
   database client is on the line.
6. **Rules are data.** One rule per line in `policy/default.rules`; a user file under the
   configuration directory adds rules and can disable a default by id. `health` lists every
   disabled rule.
7. **An audit line per decision**, written under the state directory, holding the time, the
   decision and the rule ids, never the command text.
8. **Standalone plugin.** The guard is not bundled with any workflow plugin, so a problem in
   a workflow skill cannot disable it and a false positive in the guard cannot break a
   workflow skill.

### Consequences

- Good: the most damaging commands are stopped by code, not by wording.
- Good: a person can see exactly why a command was stopped (`check` prints the rule and the
  normalised text that was examined) and can tune the rules without editing the plugin.
- Trade-off: pattern matching cannot see through every obfuscation (a command assembled at
  run time, a script file written first and run second). The shipped rules ask on the common
  opaque forms (piping a download or a decoded string into a shell) and the limits are
  documented rather than hidden.
- Trade-off: a broken rules file makes every Bash call ask until it is fixed; that is
  deliberate (decision 4).
- Trade-off: the plugin does not make a hook failure block. The host has an `onFailure`
  option for that (host version 2.1.295 or later); using it as an override on a plugin's hook
  is untested, so the reference page only describes defining one's own hook.

## Provenance

The research brief's recommendations were adopted where they held and changed where they
did not:

| Claim in the brief | Finding | Effect |
|---|---|---|
| A `Stop` hook exiting 2 pauses the agent | The host documents it as preventing the agent from stopping | Not used for approval pauses |
| `WorktreeCreate` makes a rollback snapshot | It replaces how a git worktree is created | Not used |
| `defer` can block a call | Honoured only in non-interactive mode, single call | `deny` and `ask` only |
| Exit 2 on any hook error (fail closed) | The brief also says fail open; host default is fail open; `onFailure` exists | Decisions 3 and 4 |
| Escape by a bare flag such as `--I-KNOW-WHAT-I-AM-DOING` | The agent can type it | Decision 2 |
| Secrets from environment variables | Repository rule is the system keychain | Not applicable to this plugin; kept for the workflow plugins |
| A "2026" edition of a published LLM-risk list, with specific item numbers | The published list is the 2025 edition and the numbers differ | Not cited by number |
| An unlicensed community style skill is MIT | Its repository carries no licence | Not adopted |

Precedence among simultaneous hook decisions (deny, then defer, then ask, then allow) and the
nested `hookSpecificOutput` form were confirmed against the host's documentation.
