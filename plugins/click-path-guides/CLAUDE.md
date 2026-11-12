# click-path-guides — maintainer notes

**Hub**: [Root CLAUDE.md](../../CLAUDE.md) | **Sibling**: [plugins/CLAUDE.md](../CLAUDE.md)

Invariants and decisions that aren't obvious from reading the code. The decision record is
[docs/adr/2026-11-12-click-path-guides.md](../../docs/adr/2026-11-12-click-path-guides.md).

## The shape

One command (`bin/click-path-guides`, dispatching to `scripts/click-path-guides.sh`), two skills
(`guide`, `lint`), no hooks. `lib/labels.sh` extracts labels; `lib/lint.awk` checks a guide against
them. Tier 1 only: it reads a definition and writes a guide file the user names.

## Invariants (do not weaken)

- **A source of truth is mandatory.** No source, an image, a PDF, or a source with no labels is an
  error (exit 1), never a pass. An empty label set that "passed" would verify nothing.
- **Bold is reserved for interface elements** and must match a source label exactly (case-sensitive,
  after trimming whitespace and a trailing colon or ellipsis). `--allow` is the only way past it,
  and the skill requires the user's agreement and a "not verified" note.
- **The unfilled template must fail the lint.** A test checks it; it is why `<placeholders>` are a rule.
- **Never add a label to make the lint pass.** Both skills say so.
- **State what the lint does not prove** (visible label, navigable path) wherever it is described.
- **bash 3.2 and POSIX awk.** No associative arrays in shell, no `mapfile`; awk has no `gensub`.

## Things that look wrong but are deliberate

- **`FNR == NR` reads the label file first**, which breaks if it is empty. The command refuses an
  empty label set before calling awk; do not remove that guard.
- **Bold in headings is not judged**, and a bold callout ending in a colon at the start of a line
  (`**Note:**`) is skipped. Everything else bold must be a label.
- **`right-click` is allowed** but `on the right` is not: the first is an action, the second a position.
- **Without `--keys`, every JSON string counts as a label.** That is broad on purpose (it works on
  any file); `--keys` is how a user makes it precise.
- **The extraction strips Power Fx `="..."` wrappers**, so `Text: ="Submit"` yields `Submit`.
- **No third-party style text is copied.** A community style skill was considered and rejected
  because its repository has no licence.
