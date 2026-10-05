# Open-source review playbook

This is the operating contract for reviewing an open-source skill, project, or implementation. The machine-readable source is [`review-playbook.yaml`](./review-playbook.yaml). The templates live in [`references/open-source-stack/`](../../references/open-source-stack/).

A review starts in read-only mode. It becomes an adoption proposal only after the evidence and decision are recorded. Every review is pinned to the exact upstream Git commit examined, so a later reviewer can distinguish what was known then from what changed later.

## The nine required steps

1. **Create a project spoke.** Create `docs/open-source-stack/projects/<project-slug>/` with `project.yaml`, `README.md`, `reviews.jsonl`, and dated evidence.
2. **Inspect upstream read-only.** Record the canonical URL, ref, resolved commit hash, retrieval time, version, license, package identity, maintainers, and build requirements.
3. **Assess the project.** Record purpose, capabilities, internal use cases, architecture, integration points, security, license obligations, dependencies, maintenance, documentation, tests, telemetry, and alternatives.
4. **Capture evidence.** Record commands, tool versions, source links, scan outputs, and findings. Never commit credentials, secrets, or raw private transcripts.
5. **Append a review event.** Add a stable, append-only JSONL event containing reviewer, timestamp, reviewed commit, tools, commands, evidence, findings, and decision.
6. **Classify the lifecycle.** Use `discovered`, `reviewed`, `approved`, `piloted`, `adopted`, `deprecated`, or `archived`.
7. **Apply standards.** Use SPDX or CycloneDX, PURLs, VEX, and available SLSA, in-toto, Sigstore, and OpenSSF Scorecard evidence. Use ORT, Dependency-Track, and GUAC when their scope is justified.
8. **Make adoption reproducible.** If adopted, turn the capability into a skill with pinned inputs, setup, configuration, usage, outputs, telemetry policy, provenance, validation, and rollback.
9. **Decide on Backstage.** Introduce it only when catalog scale, ownership complexity, discovery friction, or cross-team consumption justify a UI. It complements the Git registry and evidence; it does not replace them.

A review is complete only when the commit resolves, JSONL parses, evidence paths exist, the lifecycle decision is explicit, and the repository contains no secrets.
