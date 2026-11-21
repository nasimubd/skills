# Verify click-path guides against the application's own definition

## Status

Current.

## Context and Problem Statement

People ask an agent to write step-by-step instructions for a low-code application or a flow:
"open the app, go to this screen, select that button". The failure is specific and costly: the
agent recalls a menu or a button from memory, the name is slightly wrong or does not exist in
this version, and the reader loses time following a path that is not there. Instructions that
read well but cannot be followed are worse than none.

A prompt that says "check the names first" can be skipped. The repository's convention is that
rules that matter are enforced in code, so the question is what can be checked deterministically.

## Decision Drivers

- Every interface element named in a guide must come from the application's definition, not memory.
- The check has to run anywhere the repository runs: macOS bash 3.2 and Linux, no extra runtime.
- Guides must be usable by people who cannot rely on sight, so position, colour and size cannot
  identify a control.
- A false claim of verification is worse than no check, so the limits have to be stated.

## Considered Options

- **Instructions only.** Rejected: skippable, and the failure is silent.
- **Have a model review the finished guide.** Rejected: it is the same probabilistic process that
  produced the error, and its verdict would vary between runs.
- **Drive the live application and record the clicks.** Rejected for the first version: it needs
  credentials and a display, and it cannot run in a repository's tests.
- **A deterministic linter that checks the guide against the definition file.** Chosen.

## Decision Outcome

A plugin, `click-path-guides` (category `documentation`), with two skills and one command.

1. **A source of truth is mandatory.** The `guide` skill refuses to write a path without a
   definition, export or schema to read. A screenshot alone is rejected: sub-menus that are not
   visible get invented.
2. **Labels are extracted from the source** (JSON, YAML or text), optionally restricted to named
   keys, and written out so the agent works from that list.
3. **Bold is reserved for interface elements.** Every bolded term in a guide must exactly match a
   label from the source (after trimming whitespace and a trailing colon or ellipsis). A term that
   does not match fails the lint, unless the user explicitly allows it, in which case the guide
   must say it was not verified.
4. **Menu paths are written `**File** > **Open**`**, each item bold, separated by a right angle
   bracket with spaces. Arrows and unbolded paths fail.
5. **No sensory or positional identification.** Phrases such as "the green button", "on the left"
   or "below" fail, following the intent of the accessibility criterion on sensory
   characteristics (WCAG 2.1, 1.3.3). Controls are identified by their text labels.
6. **Structure:** a prerequisites section before the first step, numbered consecutive steps, no
   leftover placeholders, no filler words. The form is a how-to: goal-oriented and imperative,
   without explanation of why the application works as it does.
7. **The linter checks that a name appears in the source, not that the path is navigable.** It
   cannot tell a visible label from an internal string that happens to match, and it cannot see
   menus the file does not contain. Restricting extraction to label keys narrows the first
   limit; the guide's "not verified" list covers the second. The README says so.

### Consequences

- Good: a guide naming a control that is not in the definition fails before the reader sees it.
- Good: the same command works in tests, in a session and by hand.
- Trade-off: a definition that does not hold the visible text (a compiled export, for example)
  cannot verify anything; the plugin then says "no labels found" rather than passing.
- Trade-off: the filler-word and sensory lists are patterns, so a legitimate sentence can be
  flagged and a novel phrasing can pass. The lists are short and documented so they can be tuned.
- Limit: verifying that a path can be followed in a running application needs a live check by a
  person; this plugin does not replace it.

## Provenance

The research brief proposed this plugin with the same checks, and also proposed adapting a
community style skill's prompts. That skill's repository carries no licence, so none of its text
is used. The style rules here are written from the published guidance on formatting interface
elements and menu cascades, and the accessibility criterion above.
