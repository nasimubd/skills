# Make read-only investigations and incident write-ups checkable

## Status

Current.

## Context and Problem Statement

Two kinds of work repeat and share a shape. At the start of a task, someone asks an agent to read a
ticket and everything around it, change nothing, and come back with a plan to approve. During an
incident, the order is to contain and fix first, then write down the root cause and one step to
prevent a repeat. In both, the agent reads content it did not write (a ticket, a chat thread, a log),
and in both the output is only useful if its claims can be checked and nothing was changed on the way.

Three failures matter: an instruction hidden in the content the agent reads steers it; a claim in the
write-up has no evidence behind it; and a "fix" is made without a way back.

## Decision Drivers

- The plugin must work for any tracker, chat tool and automation platform, so it cannot hard-code one
  service or ship credentials handling.
- A rule that matters is enforced in code where code can enforce it, and its limits are stated where
  it cannot.
- Anything saved to disk must not contain secrets, and a snapshot is only worth having if it can be
  verified later.
- The repository's convention for outward-facing text: every factual claim carries the evidence the
  reader can check (source, excerpt, time, how to reproduce).

## Considered Options

- **Two plugins, one per workflow.** Rejected: they share the scanning, redaction, evidence and
  snapshot code, and the same read-only, approval-first posture. One plugin avoids duplicating it.
- **Bundle the hook guard with them.** Rejected: the guard is its own plugin so a problem in a
  workflow cannot disable it and a false positive in it cannot break a workflow.
- **One adapter per tracker inside the plugin.** Rejected for the first version: each needs its own
  credentials and API surface, and the session already has read tools for the trackers a person uses
  (connectors, the `gh` command, web fetch, local files). A reference page says how to read each
  safely instead.
- **Skills (instructions) plus deterministic commands that check the output.** Chosen.

## Decision Outcome

A plugin, `investigation-tools` (category `devops`), with two skills and one command.

1. **`triage-brief`** reads a ticket or work item by whatever read-only means the session has, saves the
   raw text, scans it for instruction-like content, writes a brief, and **stops for approval**.
2. **`incident-rca`** snapshots what it is about to change, applies only a minimal containment that the
   user approved, never declares the incident closed itself, and writes a blameless root-cause note.
3. **Fetched content is data.** It is saved to a file, scanned (`untrusted`), and any instruction-like
   text is listed in the brief under "Untrusted content seen" instead of being followed. The scan is a
   heuristic and says so; it supports, and does not replace, the rule that content is never obeyed.
4. **Evidence is mandatory and checked.** Every bullet under "What is known" and every root-cause
   statement carries a `[source: …]` tag, and the root cause includes a verbatim excerpt. The lint
   fails a brief or note without them.
5. **The brief cannot claim to have acted.** The lint requires `Status: awaiting approval`, marks each
   plan step `[read]` or `[change]`, and rejects a plan step marked done. This makes a violation
   visible; it does not by itself stop a model from changing something, which is why the guard plugin
   is recommended alongside.
6. **The root-cause note is blameless and has one prevention step.** The lint rejects blame wording,
   requires exactly one prevention item, a `Contained:` line, a deferred-work section, and a rollback
   reference to a snapshot that exists and still verifies.
7. **Secrets never reach disk.** `scan` reports secret-like strings by line and kind, never by value;
   both lints fail on them; `redact` replaces them. Email addresses are reported as personal data, as a
   warning only.
8. **Snapshots are deterministic copies with a checksum manifest**, kept under the user's state folder
   with owner-only permissions. `verify` recomputes every checksum; `restore` copies into a new, empty
   folder and never overwrites the original, so putting a file back is a person's action.

### Consequences

- Good: a brief or note with an unevidenced claim, a blame sentence, an executed plan or a missing
  rollback fails before anyone relies on it.
- Good: the same commands run by hand, in tests and inside a session.
- Trade-off: the scan for instruction-like text and the blame and secret patterns are heuristics. They
  catch the common forms and miss novel ones; the documentation says so.
- Trade-off: the plugin cannot technically prevent a write by a model that ignores the instructions. It
  detects the claim and relies on the separate guard plugin for enforcement.
- Trade-off: no tracker adapters. Reading uses the tools already in the session; a new tracker needs no
  change here.
- Limit: a snapshot is only as complete as the paths given to it. The skill asks the user to confirm the
  list before any change.

## Provenance

The research brief proposed these plugins with bundled hooks and a fetch adapter per tracker. Checked
against the host's documentation, a `Stop` hook that exits 2 keeps the agent working rather than
pausing it, a worktree hook replaces worktree creation and is not a snapshot, and a hook attached to a
skill runs for the rest of the session rather than only during the skill. So the pause for approval is
an instruction plus a lint, the snapshot is the command above, and enforcement is left to the separate
guard plugin. The brief's environment-variable secret storage is not used: nothing here stores a
secret, and the repository's rule for plugins that do is the system keychain.
