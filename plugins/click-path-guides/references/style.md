# Style rules behind the lint

What each rule enforces, why, and where it can be wrong. The rules are patterns in
`lib/lint.awk`; change them there and add a test in `tests/test-lint.sh`.

| Rule id | What it flags | Why |
|---|---|---|
| `ui-label-unverified` | A bold term that is not a label in the source (exact match after trimming whitespace and a trailing colon or ellipsis; case-sensitive) | Bold marks interface elements, so a bold term that does not exist is an invented control |
| `menu-separator` | `->`, `→`, `=>`, `»`, `>>` in a menu path | One format for every guide |
| `menu-bold` | An unbolded `File > Open` | Each menu item is an interface element |
| `sensory-language` | "on the left", "below", "top-right", "the green button", "the big button", "next to the" | A control identified by position, colour, shape or size cannot be found by someone who cannot see it (WCAG 2.1, success criterion 1.3.3); the text label can |
| `filler-word` | simply, just, easily, easy, seamless, powerful, obviously, basically, very, of course | Filler adds length and talks down; write the imperative step |
| `placeholder` | `TODO`, `TBD`, `FIXME`, `<angle placeholders>` outside code | The unfilled template must never pass |
| `prerequisites-missing` | No Prerequisites heading before step 1 | A guide that starts at step 4 assumes knowledge the reader may lack |
| `step-number` | Steps not numbered 1, 2, 3 without gaps | A skipped number hides a deleted step |
| `no-steps` | No numbered steps | Not a how-to |

Ignored: fenced code blocks, `inline code`, headings (for the bold rule), and a bold callout at the
start of a line that ends in a colon, such as `**Note:**`.

## Form

A how-to guide is goal-oriented and imperative: it says what to do, not why the application works
that way. Put explanation in a separate document. Start from `click-path-guides template`.

## Where the lint can be wrong

- It proves a name **appears as a string in the source**, not that it is a visible label. Use
  `--keys` with the keys that hold visible text to narrow it.
- It cannot see menus the definition does not contain; those need `--allow` and a "not verified"
  note in the guide.
- It cannot prove a path can be followed in the running application. A person still has to try it.
- The sensory and filler lists are patterns: a legitimate sentence can be flagged, and an unusual
  phrasing can pass.
