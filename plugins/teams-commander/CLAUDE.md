# teams-commander — maintainer notes

**Hub**: [Root CLAUDE.md](../../CLAUDE.md) | **Sibling**: [plugins/CLAUDE.md](../CLAUDE.md)

Invariants and decisions that aren't obvious from reading the code.

## Decisions (2026-10-28, user-approved)

- A plugin, not an MCP server: MCP tool schemas cost context on every turn.
- Sending is **tier 1 only**: the deep link fills the compose box and the user presses
  Send. The claude.ai Microsoft 365 connector cannot send (`Missing scope
  'ChatMessage.Send'`, six attempts in October 2026), and the Azure CLI Graph token has
  no `Chat.*` scopes. Graph and Power Automate sending stay documented, not built.
- Category `productivity`, the existing category for messaging plugins; no new
  category was added.
- Every factual claim needs evidence the user can see (the user's rule, quoted in
  `references/evidence.md`).

## Reading is deferred (2026-10-28)

Reading stays on the claude.ai Microsoft 365 connector for now (user decision). A
direct Microsoft Graph reader (delegated `Chat.Read`, which Microsoft's permissions
reference lists as "AdminConsentRequired: No"; refresh token in the Keychain; compact
text output) was built and tested offline, then kept out of this release. Its first
live sign-in returned `AADSTS65004: User declined to consent to access the app`, so
whether the tenant allows self-consent is still unknown. Classify sign-in failures by
the AADSTS code, never by wording: a first version matched the word "consent" and
misreported that decline as "admin approval needed".

## The gate is in code, twice

1. `teams-commander` (`bin/`, dispatching to `scripts/teams.sh`) stores a SHA-256 of the message when `verify` passes. `link` and
   `open` refuse if the stored hash is missing, differs from the current message, or
   any fact has gone unverified or stale since. Status is **derived** every time from
   the evidence and the clock, never stored, so it cannot be set by hand.
2. `hooks/evidence-gate.sh` denies any Bash command that launches a Teams chat link
   (`open`, `osascript`, `xdg-open`, `webbrowser`) unless it carries
   `TEAMS-SEND-OK: <10+ char reason>`. The sanctioned path, `teams-commander open`, passes
   because the URL is built inside the script and never appears on the command line.
   The hook fails open on bad input so it can never block all Bash use.

Removing either one leaves the other bypassable: the hook alone does not check
evidence, and the script alone can be skipped by building the URL by hand.

## Things that look wrong but are deliberate

- **The message is always copied to the clipboard as well as put in the link.**
  Microsoft documents no length limit and no line-break behaviour for `message=`
  (see `references/deep-link.md`). The clipboard is the fallback, not a duplicate.
- **`https://teams.microsoft.com/...`, not `msteams:`.** The https form is the one
  Microsoft documents; the custom scheme is not on that page.
- **Trailing newlines are stripped from the link** but kept in the stored message.
- **Stale after 6 hours** (`TEAMS_EVIDENCE_MAX_AGE_MIN=360`): long enough for one
  working session, short enough that "the run finished cleanly" is re-checked the next
  morning.
- **`refuse_secrets` rejects some harmless text** that looks like `token=abcdef`.
  False positives are cheap (rephrase the excerpt); a stored credential is not.

## Tests

`tests/test-teams.sh` (drafting CLI, `open`/`pbcopy` stubbed) and
`tests/test-evidence-gate.sh` (hook decisions). Both are auto-discovered by
`mise run test-marketplace-hook-regression-suite`.
