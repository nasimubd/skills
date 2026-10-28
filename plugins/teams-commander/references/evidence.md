# Evidence rules

A drafted message is only as trustworthy as its least-checked sentence. The user
(2026-10-28): "it must be factual, not any hallucinated made-up message. Everything
has to be supported by evidence. Not necessarily the evidence will be included in the
message, but it should be shown to me that everything is verified."

## What counts as evidence

Evidence is something you observed **in this session**, at a source the user or the
recipient could check again.

| `--source-type` | `--source` | `--excerpt` | `--reproduce` |
|---|---|---|---|
| `command` | the command run | the output lines that prove the claim | the same command |
| `file` | `path:line` (and commit if committed) | the quoted lines | `sed -n 'A,Bp' path` |
| `git` | commit hash or tag | subject line / diff stat | `git show --stat <hash>` |
| `n8n-execution` | workflow id + execution id | status and the counted values | how to open it |
| `power-automate-run` | flow id + run id | action status / output | how to open it |
| `teams-message` | chat, message id, time (UTC) | the sentence quoted | the chat and time |
| `asana-task` | task gid | the field or comment quoted | the task URL |
| `web` | the URL | the quoted passage | the URL and the date read |
| `user` | "user, <time>" | the user's words | ask the user |

## What does not count

- Memory (MemPalace, memory files), earlier turns in this chat, summaries, plans:
  these are **leads**. Re-check the underlying source and cite that.
- Your own inference. If a sentence goes beyond what the excerpt shows ("so it will
  also work for X"), it is an opinion: record it as `--kind opinion` and word it so.
- A number you rounded or recomputed. Quote the source value; if you computed
  something, the command that computed it is the evidence.

## Kinds

- **fact**: needs source type, source and excerpt, or it is *unverified* and blocks
  sending. Evidence older than `TEAMS_EVIDENCE_MAX_AGE_MIN` (default 360 minutes) is
  *stale* and blocks sending until refreshed.
- **opinion**: allowed without evidence, worded as a recommendation in the message.
- **question**: allowed without evidence.

## Hygiene

- Never record a credential. `teams.sh` refuses excerpts shaped like tokens or
  passwords; quote the fact around it instead.
- Keep client-confidential detail out of excerpts unless the message itself needs it.
- Drafts and ledgers stay on this machine in `~/.local/state/teams-commander/` and are
  never committed.
