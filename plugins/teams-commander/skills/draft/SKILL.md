---
name: draft
description: Use when the user asks to draft, write or improve a Teams message for a named person. Every fact is backed by evidence shown to the user. TRIGGERS - draft a message, message for Jona, Teams message
allowed-tools: Read, Bash, Grep, Glob
argument-hint: <contact> <what the message is for>
---

# Draft an evidence-backed Teams message

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

The user will send this message under their own name. A claim that turns out to be
untrue costs them credibility with the recipient, so **nothing goes into the message
that you have not checked in this session.** Recalled memory, earlier chat turns and
your own summaries are leads, not evidence: re-check them at the source.

## Execution

Every step uses the plugin's `teams-commander` command, which Claude Code puts on
the Bash PATH while the plugin is enabled.

### 1. Work out the ask

Identify the recipient (a contact alias from `teams-commander contact list`), the purpose
(review request, go-live approval, decisions, access request, end-of-day report,
reply, follow-up) and the one thing the recipient must do. Pick the matching template
in [references/templates.md](../../references/templates.md). If the purpose or the
recipient is unclear, ask the user before drafting.

### 2. Gather evidence first, then write

Collect evidence read-only for every fact you expect to state: run the command, read
the file, open the execution, read the Teams message. Prefer sources a reviewer can
re-run. The rules for what counts are in
[references/evidence.md](../../references/evidence.md).

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

- `fact` needs `--source-type`, `--source` and a word-for-word `--excerpt`; without
  them it is recorded as **unverified** and blocks sending.
- `opinion` is a recommendation; the message must word it as one ("I'd suggest…").
- `question` is anything you are asking rather than asserting.
- If you could not verify something, do not guess: drop the claim, or turn it into a
  question for the recipient.

### 4. Write the message in Teams style

Follow [references/style.md](../../references/style.md): one-line greeting, a few
plain bullets, the ask; no subject line, no "Re:", no sign-off, no `>` quote bar.
Detail goes in a document the user attaches; name the file and its path.

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

Show the user, in this order:

1. the message, as plain text ready to paste;
2. the evidence table from `show` (claim, status, source, excerpt, captured, reproduce);
3. which file to attach, if any;
4. anything you deliberately left out, and why.

Never present a draft that `verify` refused. Copy to the clipboard only when the user
asks (`pbcopy < ~/.local/state/teams-commander/drafts/$ID/message.txt`; the send
skill does this too).

### 6. Hand off

Sending is a separate step that needs the user's explicit go-ahead: the `send` skill.
Keep the draft id in your reply so the user can say "send it".

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `verify` exits 3 with "unverified" | A fact has no source or excerpt | Gather the evidence, or drop/rephrase the claim |
| `verify` exits 3 with "stale" | Evidence is older than `TEAMS_EVIDENCE_MAX_AGE_MIN` (6 h) | Re-check at the source, then `refresh` with the new excerpt |
| `claim` exits 2 "credential" | The excerpt looks like a token or password | Quote the fact around it; never store credentials |
| `teams-commander: command not found` | Plugin not enabled, or installed mid-session | Enable the plugin, then `/reload-plugins` or start a new session; until then run `bash <repo>/plugins/teams-commander/bin/teams-commander` |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If the underlying tool drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.
4. **Did the user correct the style or a fact?** Record the style rule in
   `references/style.md`; a fact correction means the evidence step missed something.

Only update if the issue is real and reproducible — not speculative.
