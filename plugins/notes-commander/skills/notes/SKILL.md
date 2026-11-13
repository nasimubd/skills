---
name: notes
description: Use when the user wants to find, open, read, create or add to an Apple Note, or asks whether a note exists. Reads freely, writes only after confirmation. TRIGGERS - find my note, open note, new note
allowed-tools: Bash
argument-hint: [what to find or write]
---

# Apple Notes

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

Reads need no approval. Start with `find`: it searches Notes and open Reminders, prints
what it examined, and when nothing matches it lists the folders and lists that do exist,
so tell the user exactly that ("no note called X; you have these folders").

```bash
notes-commander find "invoice"            # titles; add --body to search the text too
notes-commander folders
notes-commander list --folder "Work"
notes-commander show "Meeting plan"       # prints the note's text
notes-commander open "Meeting plan"       # brings it up in the Notes app
```

A title that matches several notes is refused, not guessed: show the user the ids and
reuse one with `--id`.

### Writing

Every write needs the user's approval each time. Run it **without** `--confirm` first: it
prints `WOULD: ...` and exits 3 without changing anything. Show that line, and add
`--confirm` only after the user says yes.

```bash
notes-commander create --title "Leads - Nov" --folder "Work" --text "first line"
notes-commander append "Leads - Nov" --text "Acme, acme.example, warm"
```

### Organizing

Organize in this order, and never by guessing from titles alone: read `list`, read the
bodies you need with `show`, write a plan, then apply it.

```bash
notes-commander scan                                    # credential-looking notes (read-only)
notes-commander folder create "Power Platform"          # idempotent; WOULD: first, then --confirm
notes-commander move "Meeting plan" --to "AegisLaw Work"
notes-commander organize plan.json --create-folders     # plan: [{"id": "...", "to": "Folder"}]
notes-commander journal                                 # every move batch
notes-commander undo --batch <id>                       # put a batch back
```

`organize` previews the whole plan first, stops before any change if a note or folder is
missing, verifies each move after it happens, and journals each one so `undo` works even
after a partial failure. Always run it without `--confirm` first and show the user the table.

### Credentials in notes

`list`, `find` and `show` never print a credential-looking title or text, and `scan` prints
only the rule that matched. Tell the user a flagged note is a lead, not a verdict, and give
the order that current guidance sets (OWASP Secrets Management; NIST SP 800-63B): **revoke or
rotate the credential at its source first**, then remove it from Notes, then keep the new one
in a password manager. Do not move, copy or quote the value. `show --reveal` exists only for
when the user explicitly asks to see it, and is audited.

There is no delete, on purpose. If the user wants one, tell them to delete it in Notes.
Do not script Notes with `osascript` yourself: a hook blocks it.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| Exit 3 | Write without `--confirm` | Show the `WOULD:` line, get approval, re-run with `--confirm` |
| `no Notes folder named X` | The folder does not exist | Run `notes-commander folders`; folders are never created implicitly |
| Hangs or `not allowed` | Automation permission missing | Run the `health` skill; allow the terminal under Privacy & Security > Automation |
| `moved ... but it is in 'X'` | The move did not land | Nothing was journaled; re-run `list` and retry |
| `another notes-commander write is running` | A second write started | Wait; a lock from a dead process is cleared automatically |
| Search is slow | `--body` over a very large library | Search titles first |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If the CLI drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
