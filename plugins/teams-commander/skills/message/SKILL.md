---
name: message
description: Use when the user asks to draft, reply to or send a Teams message. Every fact is evidenced; send opens the chat in the Teams app. TRIGGERS - draft a message, reply in Teams, send it
allowed-tools: Read, Bash, Grep, Glob
argument-hint: <contact> <what to say> | reply <contact> | send [<draft-id>]
---

# Teams message: draft, reply, send

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

One command for the whole message. Decide from the user's words what they want:

| The user asks to… | Do |
|---|---|
| draft, write or improve a message for someone | **Draft** (steps 1-5) |
| answer, reply to, or read what someone wrote | **Reply** (step 0, then 1-5) |
| send it, send the message | **Send** (step 6) |

"Draft and send" in one request means: draft, show it, and send only after the user has
seen the message and its evidence and said to send.

The user sends this message under their own name. A claim that turns out to be untrue
costs them credibility with the recipient, so **nothing goes into the message that you
have not checked in this session.** Recalled memory, earlier chat turns and your own
summaries are leads, not evidence: re-check them at the source.

Every step uses the plugin's `teams-commander` command, on the Bash PATH while the
plugin is enabled.

## Execution

### 0. Reply only: read the conversation (read-only)

Use the claude.ai Microsoft 365 connector's chat tools, loaded on demand:
`chat_message_search` (filter by sender and `afterDateTime`) for the contact's latest
messages, then `read_resource` on the message URI for the full text and any image.

- Read only. The connector cannot send (`Missing scope 'ChatMessage.Send'`).
- **Skip any message that contains a credential** (password, login, token, key). Do not
  open, quote or store it; tell the user one was skipped.
- Note each question asked, word for word, with its message id and time. Each becomes
  claims below; the incoming message is evidence for "you asked X"
  (`--source-type teams-message --source "<chat> <message id> <time>"`). Answer in the
  same order as the questions, one or two sentences each.

### 1. Work out the ask

The recipient (an alias from `teams-commander contact list`), the purpose (review
request, go-live approval, decisions, access request, end-of-day report, reply,
follow-up) and the one thing the recipient must do. Pick the matching template in
[references/templates.md](../../references/templates.md). If the purpose or the recipient
is unclear, ask before drafting.

### 2. Gather evidence first, then write

Collect evidence read-only for every fact you expect to state: run the command, read the
file, open the execution, read the Teams message. Prefer sources a reviewer can re-run.
What counts is in [references/evidence.md](../../references/evidence.md).

### 3. Record the draft and its claims

```bash
ID="$(teams-commander new)"
teams-commander claim "$ID" --kind fact --text "12:00 UTC run processed 17,291 matters" \
  --source-type n8n-execution --source "execution 7203" \
  --excerpt "matters: 17291, pages: 88, status: success" \
  --reproduce "n8n: get execution 7203"
teams-commander claim "$ID" --kind question --text "OK to close the task?"
teams-commander claim "$ID" --kind opinion --text "Keep Beta separate"
```

- `fact` needs `--source-type`, `--source` and a word-for-word `--excerpt`; without them
  it is **unverified** and blocks sending.
- `opinion` is a recommendation; word it as one ("I'd suggest…").
- `question` is anything you ask rather than assert.
- Could not verify something? Do not guess: drop the claim or make it a question.

### 4. Write the message in Teams style

Follow [references/style.md](../../references/style.md): one-line greeting, a few plain
bullets, the ask; no subject line, no "Re:", no sign-off, no `>` quote bar. Detail goes
in a document the user attaches; name the file and its path.

```bash
teams-commander message "$ID" - <<'EOF'
Hi Jona, ...
EOF
```

### 5. Verify and show the user

```bash
teams-commander verify "$ID"   # exit 3 = refused; fix and re-run
teams-commander show "$ID"
```

Show, in this order: the message as plain text; the evidence table from `show`; the file
to attach, if any; anything left out and why; for a reply, each answer that is your
recommendation rather than a checked fact. Never present a draft `verify` refused. Keep
the draft id in your reply so the user can say "send it".

### 6. Send

Only when the user has said to send **this** draft to **this** contact. An approval does
not carry over to a new or edited draft. "Send it" with no id means the draft just shown.

```bash
teams-commander open "<draft-id>" "<contact>"
```

`open` copies the message to the clipboard once and opens the chat in the **Teams
desktop app** (`msteams://`, no browser). The link carries no text: in live tests Teams
doubled pre-filled text, ignored it when the chat had a saved draft, and dropped line
breaks ([references/deep-link.md](../../references/deep-link.md)). Then tell the user:

- the chat is open and the message is on the clipboard;
- click the compose box and press **⌘V once** (⌘A first if an old draft is there), check
  it, attach any file named in the draft, then press **Enter**.

`open` refuses (exit 3) a draft that never passed `verify`, changed after it, or whose
evidence went stale: go back to step 3, do not work around it. Opening a Teams link any
other way is blocked by the `evidence-gate` hook. Nothing is sent until the user presses
Enter; never claim a message was sent.

| Tier | Method | Who presses Send | Status |
|---|---|---|---|
| **1 (this skill)** | Chat opened in the app + clipboard | The user | Built |
| 2 | Microsoft Graph `POST /chats/{id}/messages` | Script | Not built: needs `ChatMessage.Send` consent |
| 3 | Power Automate "Post message in a chat" as the user | Flow | Not built |

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `verify` exits 3 "unverified" | A fact has no source or excerpt | Gather the evidence, or drop/rephrase the claim |
| `verify` exits 3 "stale" | Evidence older than `TEAMS_EVIDENCE_MAX_AGE_MIN` (6 h) | Re-check at the source, then `refresh` with the new excerpt |
| `claim` exits 2 "credential" | The excerpt looks like a token or password | Quote the fact around it; never store credentials |
| Two copies after pasting | An old draft was in the compose box | ⌘A, then ⌘V |
| New empty chat instead of the existing one | Contact email is not the person's UPN | `contact add <alias> <upn>` (setup skill) |
| Nothing opens | Teams desktop app missing | Run the `health` skill |
| Search returns a truncated message | Search snippets are cut short | `read_resource` on the message URI |
| `403 Missing scope` on read | Connector consent lapsed | Ask the user to sign in again via `/mcp` |
| `teams-commander: command not found` | Plugin not enabled, or installed mid-session | Enable it, then `/reload-plugins`; until then `bash <repo>/plugins/teams-commander/bin/teams-commander` |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If Teams or the connector drifted, update this
   file, and record Teams link behaviour in `references/deep-link.md` with the date.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.
4. **Did the user correct the style or a fact?** Record the style rule in
   `references/style.md`; a fact correction means the evidence step missed something.

Only update if the issue is real and reproducible — not speculative.
