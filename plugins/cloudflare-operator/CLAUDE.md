# Cloudflare Operator invariants

Use the Cloudflare REST API at https://api.cloudflare.com/client/v4. Prefer a zone-scoped token with Zone Read and DNS Read/Edit. Never use a global API key. Read and plan before mutation; require explicit confirmation for deletes, bulk changes, zone settings, and certificate changes. Redact Authorization headers and token values.

## Public repository privacy invariant

This repository is public. Never commit customer domain names, company names, personal names, account IDs, zone IDs, hostnames, asset identifiers, credentials, webhook URLs, email addresses, or deployment-specific terminology. Examples and tests must use neutral placeholders such as `example.invalid`, `zone.example`, and `account-id-placeholder`. Runtime identifiers come only from environment variables or local secret storage and must be redacted from logs and reports.

## Review-complete PR invariant

Every pull request for this plugin must include enough information for an independent reviewer to evaluate it without reading the conversation. The body must contain: problem and outcome, architecture, changed files, behavior and permission model, security/privacy implications, validation commands and results, highlights of concerns, items requiring attention, pending work, known limitations, rollback plan, and explicit post-merge setup steps. Future commits should use a conventional subject plus an explanatory body whenever the change is non-trivial.
