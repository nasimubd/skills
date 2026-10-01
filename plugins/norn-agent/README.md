# Norn Agent

The Claude Code integration for [Norn](https://github.com/nasimubd/norn). Norn is the local-first runtime that decides whether a request should use a deterministic tool, a local decision model, an Argus-routed model, Agent-S, or human approval.

This plugin is intentionally thin. It installs and verifies the external runtime; it does not vendor model weights, provider credentials, or desktop automation source.

## Install

```text
/plugin marketplace add nasimubd/skills
/plugin install norn-agent@skills
```

Then invoke `/norn-agent:setup` and `/norn-agent:doctor`.
