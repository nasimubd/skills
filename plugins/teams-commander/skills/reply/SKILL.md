---
name: reply
description: Use when the user asks to read a Teams reply and draft an answer. Reads the chat read-only, then drafts with evidence for every fact. TRIGGERS - read the reply, answer her questions, reply in Teams
allowed-tools: Read, Bash, Grep, Glob
argument-hint: <contact> [what to focus on]
---

# Reply to a Teams message

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

### 1. Read the conversation (read-only)

Use the claude.ai Microsoft 365 connector's chat tools, loaded on demand:
`chat_message_search` (filter by sender and `afterDateTime`) to find the latest
messages from the contact, then `read_resource` on the message URI for the full text
and any image.

- Read only. The connector cannot send (`Missing scope 'ChatMessage.Send'`), and
  sending is the user's step anyway.
- **Skip any message that contains a credential** (password, login, token, key). Do
  not open, quote or store it; tell the user one was skipped.
- Note each question asked, word for word, with its message id and time.

### 2. Each question becomes claims

For every question in the incoming message, decide whether the answer is a fact you
can evidence, an opinion, or a question back. The incoming message itself is evidence
for "you asked X": record it with `--source-type teams-message --source "<chat> <message id> <time>"`.

### 3. Draft through the draft skill

Follow the `draft` skill from step 3 onward: record the claims, write the reply in the
same order as the questions, `verify`, then `show` the message and the evidence table.
Keep it short: one or two sentences per question.

### 4. Flag what you assumed

After the evidence table, list any answer that is your recommendation rather than a
checked fact, so the user can change it before sending.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Search returns a truncated message | Search snippets are cut short | `read_resource` on the message URI |
| Message is an image only | Screenshot sent in chat | `read_resource` returns it; describe what it shows as evidence |
| `403 Missing scope` on read | Connector consent lapsed | Ask the user to sign in again via `/mcp`; an admin may need to re-consent |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If the connector's tools drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
