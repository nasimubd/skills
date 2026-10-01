# Skills marketplace

This repository contains reusable Claude Code plugins and skills. Keep provider-
specific runtime implementations in their own repositories; marketplace plugins
should provide the user-facing installation, setup, and invocation surface.

## Terminology

| Term | Definition |
|---|---|
| **Plugin** | A marketplace-installable container with a manifest and bundled skills. |
| **Skill** | A reusable capability described by a `SKILL.md` file. |
| **Norn** | The planned runtime repository and agent-execution layer for natural-language tasks; it routes each request between deterministic tools, local decision models, Argus-routed models, Agent-S, and human approval. Pronounced **/nɔːrn/** (“norn”). |
| **Argus** | The high-throughput model gateway and account/session proxy. |
| **Jev** | TypeSafe’s typed decision-model product; do not write “JEB” when referring to it. |
| **Agent-S** | The optional computer-use executor for tasks that require visual desktop interaction. |

Norn is the canonical name for the runtime project. Use `Norn runtime` when
clarity matters and `norn` for the executable or package name.
