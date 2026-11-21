# quant-integrity-auditor

Issue-first quantitative trading integrity auditor with reproducible evidence and guarded GitHub reporting.

From a checkout, run `node scripts/package-quant-integrity.mjs <package-directory>` at the repository root, then start Claude Code with `claude --plugin-dir <package-directory>/claude/quant-integrity-auditor` in the target repository. Invoke `/quant-integrity-auditor:quantitative-integrity-audit`. The source plugin links to the canonical `skills/quantitative-integrity-audit` implementation; the generated package materializes it with SHA-256 parity checks. The audit starts with all GitHub issues, then examines the five trading stages and available read-only deployment evidence. Publishing findings is a separate explicitly confirmed operation.

Marketplace registration exists for discovery, but standalone installation must use the generated package until the marketplace packaging path is verified to materialize linked skills. See the canonical skill README for findings JSON, tests, and limitations.
