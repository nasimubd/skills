---
paths:
  - "src/Make/**"
  - "docs/**"
---

# Make.com and Zapier (on demand)

{{MAKE_LINE}}

## Make.com

- Scenarios are components (`make-<slug>`) with `src/Make/<slug>/blueprint.json`, exported
  read-only through the Make API (`mise run export -- <id>`; token from `MAKE_API_TOKEN` or the
  Keychain item named in `project.json`).
- Edit a copy named `[OPT] <name>`, never the production scenario. Turning a scenario on or off,
  running it, or replacing its blueprint needs explicit approval.

## Zapier

- Zapier offers no general API to export a Zap's definition, so Zaps are **documented, not
  versioned**: `docs/architecture.md` lists every Zapier hook found in a flow or workflow, with
  the evidence, and the Zap's steps are described by hand from the Zapier editor.
- Never paste a Zap's hook URL into a commit if it accepts unauthenticated requests; refer to
  it by its Zap name instead.
