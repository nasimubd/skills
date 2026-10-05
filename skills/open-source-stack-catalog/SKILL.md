---
name: open-source-stack-catalog
description: Use when reviewing, adopting, or documenting an open-source project. Create a provenance-pinned hub-and-spoke record with Git hashes, evidence, telemetry, and reproducible skill guidance.
allowed-tools: Read, Write, Bash, WebFetch
---

# Open-source stack catalog

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong or a workaround was needed, fix this file immediately.

## Execution

1. Read `docs/open-source-stack/README.md` and copy `references/open-source-stack/project.yaml` into `docs/open-source-stack/projects/<slug>/`.
2. Resolve and record the immutable upstream Git commit, ref, canonical URL, retrieval time, license, PURL, and review tools. Never treat a branch name or tag alone as reproducible.
3. Write a spoke `README.md` explaining capabilities, internal use cases, limits, security, telemetry, and adoption decision.
4. Append one event to `reviews.jsonl` using `references/open-source-stack/review-event.example.json`. Store commands, tool versions, findings, and evidence paths. Keep raw transcripts and secrets out of the repository.
5. If adopting software, produce an SPDX or CycloneDX SBOM and record its path. Check upstream health with OpenSSF Scorecard where practical; use ORT for license policy and Dependency-Track for continuous SBOM monitoring.
6. Recommend Backstage only when project count, ownership, or discovery friction makes the Git catalog insufficient. Backstage does not replace the spoke, SBOM, or provenance record.

## Required review output

A review is incomplete until the spoke contains the pinned commit, timestamp, decision, evidence, and documented telemetry policy. A later review creates a new JSONL event and never edits history to make an old review appear current.

## Post-Execution Reflection

After this skill completes, verify that the commit hash resolves, JSONL parses, evidence paths exist, and no credentials or raw private transcripts were recorded.
