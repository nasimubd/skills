# investigation-tools

Read-only triage briefs and blameless incident notes whose claims carry evidence: scans fetched content for planted instructions, keeps secrets out of what is saved, and takes verifiable snapshots before any change.

Category: `devops` · Keywords: triage, incident, root cause, evidence, snapshot, read-only

## Why

Two kinds of work repeat. At the start of a task you want an agent to read a ticket and everything
around it, change nothing, and come back with a plan to approve. During an incident you want it
contained first and explained afterwards. In both the agent reads text it did not write, and the
output is only useful if every claim can be checked and nothing was changed on the way.

## Skills

| Command | What it does |
|---|---|
| `/investigation-tools:triage-brief` | Reads a ticket or request read-only, screens it for planted instructions and secrets, writes an evidence-tagged brief, and stops for your approval |
| `/investigation-tools:incident-rca` | Snapshots what it will change, applies only an approved minimal containment, never declares the incident closed itself, and writes a blameless root-cause note |

## The command

```bash
investigation-tools scan <file>            # secret-like strings, by line and kind, never the value
investigation-tools redact <file>          # the file with secrets and emails replaced
investigation-tools untrusted <file>       # instruction-like text in fetched content
investigation-tools brief template | lint <file>
investigation-tools rca template   | lint <file>
investigation-tools snapshot create <label> <path...> | verify <dir> | list | restore <dir> <new-dir>
```

Exit 0 is clean, 3 means findings or a failed check, 1 a runtime error, 2 a usage error.

## What the checks enforce

| Document | Fails when |
|---|---|
| Brief | a fact has no `[source: …]`; a plan step is not marked `[read]` or `[change]`, or is marked done; it does not say `Status: awaiting approval`; a section or header is missing; a secret or placeholder is present |
| Root-cause note | a root-cause statement has no source or no verbatim excerpt; blame wording appears; there is not exactly one prevention step; no `Contained:` line; the rollback snapshot is missing or no longer verifies; a secret or placeholder is present |

Snapshots are plain copies with a SHA-256 manifest, stored under `~/.local/state/investigation-tools`
with owner-only permissions. `verify` catches a changed, missing or added file. `restore` copies into
a new, empty folder and never overwrites the original: putting a file back is your action.

## What this does not do

- **It cannot stop a model from changing something.** The skills say "read-only" and the lint
  rejects a brief that claims to have acted, but enforcement is the job of `change-guardrails`, which
  is a separate plugin. Enable both for work against production.
- **The scans are heuristics.** The instruction-like text scan, the secret patterns and the blame
  patterns catch common forms and miss novel ones. A clean scan does not prove content is safe.
- **There are no tracker adapters.** Reading uses the tools the session already has;
  [references/adapters.md](./references/adapters.md) says how to read each kind of source safely.
- **A snapshot is only as complete as the paths you give it.** The skill confirms the list first.

## Install

```
/plugin marketplace add nasimubd/skills
/plugin install investigation-tools@skills
```

Works on macOS (bash 3.2) and Linux; no dependencies beyond a POSIX shell, awk and a SHA-256 tool.
