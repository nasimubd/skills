# teams-commander — maintainer notes

**Hub**: [Root CLAUDE.md](../../CLAUDE.md) | **Sibling**: [plugins/CLAUDE.md](../CLAUDE.md)

Invariants and decisions that aren't obvious from reading the code.

## Decisions (2026-10-28, user-approved)

- A plugin, not an MCP server: MCP tool schemas cost context on every turn.
- Sending is **tier 1 only**: the chat opens in the Teams app, the message is on the
  clipboard, and the user pastes it and presses Enter. The claude.ai Microsoft 365
  connector cannot send (`Missing scope 'ChatMessage.Send'`, six attempts in October
  2026), and the Azure CLI Graph token has
  no `Chat.*` scopes. Graph and Power Automate sending stay documented, not built.
- Category `productivity`, the existing category for messaging plugins; no new
  category was added.
- Every factual claim needs evidence the user can see (the user's rule, quoted in
  `references/evidence.md`).

## One message command (2026-10-28, user decision)

`draft`, `reply` and `send` were merged into one skill, `message`, which picks the action
from the request; `setup` and `health` stay separate, as the repository convention requires
for service-backed plugins. The user found five commands too complex to use.

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

- **The link carries no `message=`; the clipboard is the only copy** (live tests,
  2026-10-28, `references/deep-link.md`). With the text in the link as well as on the
  clipboard the user got two copies; Teams also doubled link text on its own, ignored it
  when the chat had a saved draft, and dropped line breaks. Do not add `message=` back.
- **`msteams://teams.microsoft.com/...`, not `https://`.** Microsoft's "Configure deep
  links" page documents `msteams://` as opening the desktop client directly, skipping the
  browser's chooser page. It needs the desktop app, which `health` checks.
- **Trailing newlines are stripped from the clipboard** but kept in the stored message.
- **Stale after 6 hours** (`TEAMS_EVIDENCE_MAX_AGE_MIN=360`): long enough for one
  working session, short enough that "the run finished cleanly" is re-checked the next
  morning.
- **`refuse_secrets` rejects some harmless text** that looks like `token=abcdef`.
  False positives are cheap (rephrase the excerpt); a stored credential is not.

## Tests

`tests/test-teams.sh` (drafting CLI, `open`/`pbcopy` stubbed) and
`tests/test-evidence-gate.sh` (hook decisions). Both are auto-discovered by
`mise run test-marketplace-hook-regression-suite`.
