# Track open-source projects as reproducible, provenance-pinned spokes

## Status

Current

## Decision

Maintain a version-controlled open-source stack registry under `docs/open-source-stack/`. Every reviewed project gets a self-contained spoke with human documentation, structured metadata, append-only JSONL review events, and evidence. Reviews must record the upstream URL, retrieval time, immutable Git commit hash, ref, reviewer, tools, and evidence paths. Adopt SPDX or CycloneDX SBOMs, PURLs, VEX, and provenance attestations where available. Use ORT for license/policy analysis and Dependency-Track for SBOM vulnerability monitoring.

Backstage is deferred until the registry's scale or ownership needs justify a catalog UI. It complements the registry and evidence; it does not replace them. GUAC is deferred until cross-product provenance graphs are needed.

## Rationale and prior art

The requested hub-and-spoke layout matches this repository's progressive-disclosure architecture. The read-only review of [terrylica/cc-skills](https://github.com/terrylica/cc-skills) found useful patterns to borrow: ADRs, per-area `CLAUDE.md` spokes, append-only JSONL provenance, immutable commit references, explicit schemas, and evidence paths. Its session provenance schemas informed this registry, while raw session logs remain excluded because they can contain secrets.

This follows current ecosystem practice: SPDX and CycloneDX for SBOM interchange, PURL for identity, VEX for applicability, SLSA/in-toto and Sigstore for build provenance, OpenSSF Scorecard for upstream health, and OpenChain ISO/IEC 5230 for organizational license compliance.

## Consequences

A later reviewer can reproduce what was known at an earlier point. Generated SBOMs and automated scanners provide continuous evidence; the catalog records human intent and adoption context. The cost is a small amount of structured metadata per review and periodic refreshes when upstream changes.
