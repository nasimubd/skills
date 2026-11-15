# Cloudflare Operator invariants

Use the Cloudflare REST API at https://api.cloudflare.com/client/v4. Prefer a zone-scoped token with Zone Read and DNS Read/Edit. Never use a global API key. Read and plan before mutation; require explicit confirmation for deletes, bulk changes, zone settings, and certificate changes. Redact Authorization headers and token values.

## Public repository privacy invariant

This repository is public. Never commit customer domain names, company names, personal names, account IDs, zone IDs, hostnames, asset identifiers, credentials, webhook URLs, email addresses, or deployment-specific terminology. Examples and tests must use neutral placeholders such as `example.invalid`, `zone.example`, and `account-id-placeholder`. Runtime identifiers come only from environment variables or local secret storage and must be redacted from logs and reports.

## Review-complete PR invariant

Every pull request for this plugin must include enough information for an independent reviewer to evaluate it without reading the conversation. The body must contain: problem and outcome, architecture, changed files, behavior and permission model, security/privacy implications, validation commands and results, highlights of concerns, items requiring attention, pending work, known limitations, rollback plan, and explicit post-merge setup steps. Future commits should use a conventional subject plus an explanatory body whenever the change is non-trivial.

## Mandatory approval guardrails

The agent must stop and request explicit user approval immediately before any operation in these classes:

- Delete, overwrite, replace, or purge any DNS record, zone, bucket, object, Worker, Pages project, rule, route, certificate, key, token, API credential, account member, or access policy.
- Any bulk or wildcard operation affecting more than one resource.
- Nameserver, registrar, DNSSEC, zone activation, SSL/TLS mode, certificate, proxy, cache purge, redirect, load-balancer, tunnel, WAF, firewall, Access, Worker route, Pages deployment, R2 bucket policy, lifecycle, CORS, public-access, or custom-domain changes.
- Sending, exposing, or making any storage object or service publicly accessible.
- Creating, rotating, revoking, or exporting credentials.
- Changes that can interrupt mail delivery, web traffic, authentication, storage access, or production routing.

Before asking, prepare a concrete change plan containing target resource, current state, exact proposed mutation, blast radius, dependencies, verification steps, rollback steps, and expected downtime. A vague instruction, prior approval for discovery, or approval of a plan does not authorize a later mutation. Approval must be explicit and operation-specific in the current interaction. Never interpret silence, elapsed time, or a pasted credential as approval.

Read-only discovery, diff generation, validation, and dry-run planning may proceed without approval. If an operation combines safe and destructive actions, split it and stop before the destructive portion.

## Secret handling

Never print, repeat, commit, place in `.env`, place in `project.jsonl`, include in task descriptions, include in PRs, or send to third parties any API token, access key, secret key, OAuth secret, refresh token, private key, signed URL, or credential-bearing endpoint. Resolve secrets only at execution time from the OS Keychain or an approved secret store. Redact values in exceptions, logs, diffs, screenshots, and summaries. If a secret appears in chat or output, do not quote it; store it securely if authorized and recommend rotation when exposure risk exists.
