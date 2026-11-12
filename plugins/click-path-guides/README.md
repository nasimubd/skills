# click-path-guides

Write step-by-step UI click-path guides that are checked against the application's own definition: every bold control must exist in the source, menu paths follow one format, and position or colour wording is rejected.

Category: `documentation` · Keywords: documentation, how-to, UI, accessibility, low-code

## Why

An agent asked for click-by-click instructions will recall a menu or button from memory. The name
is slightly wrong, or the control does not exist in this version, and the reader follows a path
that is not there. A prompt that says "check the names first" can be skipped. This plugin makes
the check mechanical: the guide is linted against the definition file before you see it.

## Skills

| Command | What it does |
|---|---|
| `/click-path-guides:guide` | Reads the app or flow definition, writes the guide from a template, lints it against the definition, and reports what was and was not verified |
| `/click-path-guides:lint` | Checks an existing guide and reports each finding with its line |

## The command

```bash
click-path-guides labels app.json --keys label,title      # what the source calls things
click-path-guides lint guide.md --source app.json --keys label,title
click-path-guides template                                 # the guide template
```

Exit 0 means clean, 3 means findings, 1 means the source could not be read, 2 is a usage error.

## What the lint checks

- Every **bold** term is a label found in the source (exact, case-sensitive).
- Menu paths read **File** > **Open**: each item bold, a right angle bracket with spaces.
- No position, colour, shape or size wording ("on the left", "the green button").
- A Prerequisites section before step 1, steps numbered 1, 2, 3, no placeholders or filler.

[references/style.md](./references/style.md) lists every rule and where it can be wrong.

## What it does not prove

It proves a name **appears in the source**, not that it is a visible label, and not that the path
can be followed in the running application. Sources can be JSON, YAML (including Power Fx style)
or text. A screenshot or PDF is refused: hidden sub-menus get invented from images. Terms the
definition cannot hold (a host application's menus) need `--allow` and a "not verified" note.

## Install

```
/plugin marketplace add nasimubd/skills
/plugin install click-path-guides@skills
```

Requires `jq` for JSON sources. Works on macOS (bash 3.2) and Linux.
