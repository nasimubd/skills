# Security Policy

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for a security vulnerability.

Preferred channel: use [GitHub's private vulnerability reporting](https://github.com/nasimubd/skills/security/advisories/new)
for this repository (Security tab → Report a vulnerability). This opens a
private advisory visible only to the maintainer until a fix is ready.

If that's unavailable to you for any reason, email **nasimubd21@gmail.com**
with:

- A description of the vulnerability and its potential impact
- Steps to reproduce, or a proof of concept
- Any plugin/skill affected, and the version

You should expect an initial response within a few days. This is a
personal, actively-maintained project without a dedicated security team, so
timelines are best-effort rather than contractual.

## Scope

This repository is a Claude Code plugin marketplace: shell/Node tooling that
runs locally in a contributor's own environment, and skill/plugin content
that Claude Code reads and executes on the user's behalf. Relevant reports
include (non-exhaustively):

- A skill or hook that could execute unintended commands, exfiltrate data,
  or escalate privileges beyond what its description states
- Credential or secret handling issues in `scripts/` or the release
  pipeline
- Supply-chain concerns in dependencies pinned by `bun.lock`

## Disclosure

Once a fix is released, the advisory is published and credited to the
reporter unless anonymity is requested.
