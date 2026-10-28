---
name: send
description: Use when the user approves sending a verified Teams draft. Opens Teams with the message pre-filled and on the clipboard; the user presses Send. TRIGGERS - send it, send the message, open in Teams
allowed-tools: Bash
argument-hint: <draft-id> <contact>
---

# Send a verified draft (tier 1: deep link)

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Capability tiers

| Tier | Method | Who presses Send | Status |
|---|---|---|---|
| **1 (this skill)** | Teams chat deep link + clipboard copy | The user | Built |
| 2 | Microsoft Graph `POST /chats/{id}/messages` | Script | Not built: needs `ChatMessage.Send` consent |
| 3 | Power Automate "Post message in a chat" as the user | Flow | Not built |

## Execution

Run only after the user has explicitly said to send **this** draft to **this** contact.
An earlier approval does not carry over to a new or edited draft.

```bash
teams-commander open "<draft-id>" "<contact>" --dry-run   # shows the link, fills the clipboard
teams-commander open "<draft-id>" "<contact>"             # opens Teams
```

`open` refuses (exit 3) when the draft never passed `verify`, the message changed after
`verify`, or evidence went stale. Go back to the `draft` skill; do not work around it.
Opening a Teams link any other way is blocked by the plugin's `evidence-gate` hook.

Then tell the user:

- Teams is open with the message in the compose box, and the same text is on the
  clipboard;
- **check the compose box before pressing Send**: Microsoft documents no length
  limit or line-break handling for the pre-filled text, so if it looks cut or
  flattened, select all in the compose box and paste from the clipboard;
- attach any file named in the draft before sending.

Nothing is sent until the user presses Send. Never claim a message was sent.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Opens in the browser, not the app | `https` link handled by the browser | Click "Open Microsoft Teams" in the page, or set Teams to open links |
| New empty chat instead of the existing one | Email in contacts is not the person's UPN | Fix it with `contact add <alias> <upn>` |
| Pre-filled text cut or on one line | Link limits (undocumented) | Paste from the clipboard instead |
| `no contact` | Alias not set up | Run the `setup` skill |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If Teams changed how the link behaves, record
   it in `references/deep-link.md` with the date and what was observed.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
