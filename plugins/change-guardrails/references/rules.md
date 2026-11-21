# Writing and tuning rules

The shipped rules are in `policy/default.rules`. Your own live in
`~/.config/change-guardrails/rules` (or `$XDG_CONFIG_HOME/change-guardrails/rules`); the
folder is never committed. The file is optional. Both files use the same format, and
`change-guardrails check` shows how a command is judged.

## Format

One rule per line, five fields separated by `@@`. Lines that are blank or start with `#`
are ignored.

```
decision@@scope@@id@@regex@@message
```

| Field | Values | Meaning |
|---|---|---|
| decision | `deny`, `ask` | `deny` stops the command. `ask` puts it to the user. |
| scope | `cmd`, `raw`, `sql` | `cmd`: the command with quoted text and heredoc bodies removed, which is what would run. `raw`: the text as written. `sql`: raw and case-insensitive. |
| id | lowercase letters, digits, hyphens | Unique. Shown in the reason and the audit log; used to disable a rule. |
| regex | POSIX extended | `{B}` means "start of a word": the start of the text, or after any character that is not a letter, digit, `_`, `.` or `-`. A path slash counts, so `/bin/rm` matches `rm`. |
| message | text, no `@@` | Shown to the user and the agent. |

Examples for your own file:

```
# Ask before any deploy script.
ask@@cmd@@deploy-script@@{B}\./deploy\.sh([[:space:]]|$)@@Runs the deploy script

# Turn off a default that does not fit your work.
disable@@git-clean-force
```

`disable` lines are only allowed in your file, never in the shipped one, and `health`
lists every rule you have disabled.

## What the scopes see

`cmd` text for `git commit -m "do not rm -rf / ever"` is `git commit -m`: the message is
data, so it cannot trigger a rule. The exceptions are deliberate:

- A quoted string with no whitespace is kept, so `rm -rf "$HOME"` still matches.
- A string handed to `sh -c`, `bash -c`, `zsh -c` or `eval` is code and is kept whole.
- `$( ... )` and backticks inside double quotes run, so they are kept.
- Heredoc bodies are removed. A multi-line script is judged line by line.

## Limits

This is pattern matching, not understanding. It cannot see through:

- a command assembled at run time (`cmd=r; ${cmd}m -rf /`);
- a script written to a file and run in a later call;
- a command sent to another machine (`ssh host 'rm -rf /'`), because the quoted text is data;
- a tool that is destructive by name alone and is not in the rules.

The defaults ask on the common opaque forms (a download or a decoded string piped into a
shell). Add a rule for anything your own stack makes dangerous. The guard is a safety net
under the host's permission prompts, not a replacement for them.

## Make a hook failure block

By default a hook that crashes or times out lets the command through, which is the host's
documented behaviour and this plugin's choice. This plugin does not set the host's
`onFailure: "block"` option (host version 2.1.295 or later), and it has not been tested
as an override on a plugin's hook. If you want that behaviour, define your own hook in your
settings that runs this plugin's `hooks/guard-bash.sh` with `onFailure` set, and accept that
every Bash call then stops whenever the hook breaks.
