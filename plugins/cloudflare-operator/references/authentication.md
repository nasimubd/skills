# Authentication decision

A scoped API token is cheapest for one Cloudflare account or a local Codex/Claude Code operator. OAuth 2.0 Authorization Code with PKCE is appropriate for a hosted multi-user plugin requiring delegated access; it adds client registration, redirect handling, consent, refresh, revocation, and secure token storage. Cloudflare does not support client-credentials OAuth for self-managed third-party clients.

Sources: https://developers.cloudflare.com/api/overview/
https://developers.cloudflare.com/fundamentals/api/get-started/create-token/
https://developers.cloudflare.com/fundamentals/oauth/create-an-oauth-client/
