# Open-source stack registry

This is the repository's hub for projects we review, adopt, or reject. Each project is a spoke directory under `docs/open-source-stack/projects/<slug>/`. The registry is deliberately version-controlled: a review is reproducible only when its upstream URL, immutable Git commit, retrieval time, tool versions, evidence, and decision are recorded together.

## Required provenance

Every spoke contains `project.yaml`, `README.md`, `reviews.jsonl`, and `evidence/`. The YAML records the canonical upstream URL, VCS and ref, resolved commit hash, retrieval timestamp, license, package identifiers (PURL where available), and review status. Each JSONL review event has a stable ID, reviewer, timestamp, reviewed commit, commands/tools, evidence paths, findings, and decision. Do not record secrets, private session transcripts, or credentials.

Telemetry means review metadata and hashes, not undisclosed runtime data collection. If the adopted software emits telemetry, document what it emits, where it goes, how it is disabled, and the privacy decision in the spoke.

## Standards and tools

Use SPDX or CycloneDX for SBOMs, PURL for component identity, VEX for vulnerability applicability, SLSA/in-toto or Sigstore evidence where available, and OpenSSF Scorecard for upstream health. ORT is the preferred FOSS license/policy analyzer; Dependency-Track is the preferred FOSS SBOM vulnerability monitor. GUAC becomes useful when the graph spans many products and attestations. Backstage is optional: introduce it when the registry has enough projects, owners, or consumers that Git navigation and generated indexes no longer provide adequate discovery. Backstage is a catalog UI, not a replacement for SBOM or provenance evidence.

## Lifecycle

`discovered → reviewed → approved → piloted → adopted → deprecated → archived`. A review must pin the exact commit examined. Later use starts a new review event and never silently changes the old one.

The initial rollout is file-first: add spokes and schema validation locally, generate SPDX/CycloneDX during builds, then integrate ORT and Dependency-Track. Add Backstage after measuring discovery friction and ownership scale.
