# Cloudflare Operator

Production-oriented Cloudflare operations for Codex and Claude Code. It audits zones and DNS, plans changes before mutation, applies idempotent record updates, and never logs credentials.

The default authentication is a scoped API token. OAuth is supported as an integration architecture for multi-user applications; it is not required for a single-account local operator.

Safely inspect and manage Cloudflare zones and DNS through scoped API tokens, with optional OAuth for multi-user deployments.
