# change-guardrails

Deterministic guardrails for shell commands: stops or asks before force-pushes to protected branches, recursive deletes of system paths, disk wipes, destructive SQL and similar, with a written-reason escape and an audit log.

Category: `enforcement` · Keywords: guardrails, safety, hooks, production, policy

## Why

An instruction like "never force-push to main" can be skipped, forgotten after a
compaction, or overridden by text the agent read in a ticket or a web page. A hook cannot.
This plugin judges every Bash command with a small rules file, in code, before it runs.

## What it does

| Decision | Meaning | Examples in the default rules |
|---|---|---|
| `deny` | The command is stopped | `rm -rf /`, `rm -rf ~`, force-push or delete of `main`/`master`, `mkfs`, `dd` to a device, `DROP DATABASE` |
| `ask` | You are asked to approve | any other force-push, `git reset --hard`, `git clean -fd`, `curl … \| sh`, uploads with `curl`, `npm publish`, `terraform destroy`, `kubectl delete`, cloud deletes, `DROP TABLE` |
| (no match) | Nothing happens; your normal permission flow applies | everything else |

Run `change-guardrails rules` for the full list.

**The escape.** A command that carries `# GUARD-OK: <reason of at least ten characters>`
turns a `deny` into an `ask`: you see the reason and approve or refuse. It never turns a
stop into a silent allow, because the agent (or text it read) could type the marker itself.

**What it sees.** Quoted text and heredoc bodies are removed first, so a commit message
that mentions `rm -rf /` does not trigger a rule, while `bash -c "rm -rf /"` still does.
See [references/rules.md](./references/rules.md) for the format, how to add or disable
rules, and the limits: this is pattern matching, so a command assembled at run time or
sent to another machine is not seen.

## Skills

| Command | What it does |
|---|---|
| `/change-guardrails:check` | Judge a command without running it, list the rules, show recent decisions |
| `/change-guardrails:health` | Check `jq`, both rules files, a live self-test and the audit folder |

## Your own rules

Optional file: `~/.config/change-guardrails/rules` (never committed). Add rules or turn a
default off with `disable@@<rule-id>`. A malformed line makes **every** command ask until it
is fixed, and says which line, because silently ignoring a custom `deny` is the dangerous
failure. `health` lists everything you have disabled.

## Failure behaviour

| Situation | Result |
|---|---|
| The hook cannot read its input, `jq` is missing, or it crashes | Fail open: the command runs. `health` reports a missing `jq`. |
| A rules file is broken | Every command asks, naming the file and line |
| The audit folder cannot be written | The decision still applies; only the log is lost |

## Audit log

`~/.local/state/change-guardrails/audit.log`: one line per `deny` or `ask` with the time,
the decision and the rule ids. **Never the command text**, which can hold secrets.

## Install

```
/plugin marketplace add nasimubd/skills
/plugin install change-guardrails@skills
```

Requires `jq`. Works on macOS (bash 3.2) and Linux.
