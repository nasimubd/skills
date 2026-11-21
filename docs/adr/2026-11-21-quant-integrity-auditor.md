# Share one quantitative audit skill across Codex and Claude Code

## Status

Current

## Context

Two host integrations can drift if they duplicate audit instructions or evidence logic. Trading-system findings also require a complete prior-issue baseline, reproducible evidence and controlled external writes.

## Decision

Keep the methodology, Node CLI, fixtures and tests under `skills/quantitative-integrity-audit`. Register it through relative symlinks in `.agents/skills`, the Claude plugin and the Codex plugin. The CLI inventories GitHub first, checks fingerprints and provenance, and requires a separate confirmed publication operation. The AI investigator performs source and financial analysis; deterministic tooling enforces data contracts.

## Consequences

Both hosts use identical instructions and evidence rules. Installers must preserve symlinks or generate a parity-checked package. Unstructured historical issues still need human root-cause review; automated fingerprints alone cannot establish uniqueness. A missing deployment remains unverified.
