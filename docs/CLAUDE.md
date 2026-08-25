# Documentation standards

**Hub**: [Root CLAUDE.md](../CLAUDE.md) | **Sibling**: [plugins/CLAUDE.md](../plugins/CLAUDE.md)

The hub covers link conventions and the same-commit rule. This spoke covers only the
document types kept here and how they are named.

## What lives here

| Path | Contents |
|---|---|
| `docs/adr/` | Architecture Decision Records |
| `docs/design/` | Design specs, one per ADR that needs one |
| `docs/RELEASE.md` | The release workflow, end to end |

## ADRs

**Naming**: `YYYY-MM-DD-slug.md` — date-prefixed, no sequential numbers.

Sequential numbers force a lookup to answer "which one is newer" and collide the moment
two land in parallel. A date sorts correctly, needs no registry, and tells you the one
thing you actually want to know when you find one.

**Format**: [MADR 4.0](https://github.com/adr/madr).

**Status is a field, not a filename.** A superseded ADR keeps its name and gains a
status line pointing at what replaced it. Renaming or deleting it destroys the record of
why the decision was once correct — which is the reason the file exists.

## Design specs

`docs/design/YYYY-MM-DD-slug/spec.md`, sharing the slug with its ADR.

Not every ADR needs one. An ADR records *what was decided and why*; a design spec
records *how it is built*. When the how is obvious from the what, skip it — an empty
spec is worse than no spec, because it implies detail exists somewhere.

## Recording decisions

**A decision that lives only in chat is not recorded.** Chat is not the authoritative
record and cannot be searched by someone who was not there.

Every decision with history behind it gets an ADR carrying:

- what was decided, and what was rejected
- the provenance — what prior decision this supersedes, if any
- status: current, superseded, or unresolved
- enough of the reasoning that a reader can tell whether the reasoning still holds

The last point is the one usually skipped and the one that matters. A decision recorded
without its reasoning cannot be revisited when the world changes; it can only be
obeyed or violated.

## Writing

- Prose over bullet fragments when the reader needs the *why*. Tables when they need to
  look something up.
- State the failure mode, not just the rule. "Use a hyphen" is forgettable; "a colon
  breaks YAML parsing" is not.
- No AI attribution anywhere, per the hub.
- No machine-specific literals and no third-party names — this repository is intended to
  become public. Refer to roles: the maintainer, upstream, the operator.
