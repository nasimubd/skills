# Plugin development

How to add and structure a plugin in this marketplace.

**Hub**: [Root CLAUDE.md](../CLAUDE.md) | **Sibling**: [docs/CLAUDE.md](../docs/CLAUDE.md)

The hub covers discovery, path resolution, versioning, gates and repository-wide
conventions. This spoke covers only what is local to building a plugin.

## Adding a plugin

```bash
mkdir -p plugins/<name>/skills
# then add an entry to .claude-plugin/marketplace.json
node scripts/validate-plugins.mjs
```

**Checklist:**

- [ ] Directory exists at `plugins/<name>/` — lowercase, kebab-case
- [ ] Entry added to `.claude-plugin/marketplace.json` with the current marketplace version
- [ ] `plugins/<name>/plugin.json` carries **no** `version` key
- [ ] `plugins/<name>/CLAUDE.md` written
- [ ] `node scripts/validate-plugins.mjs` passes
- [ ] `node scripts/check-version-equality.mjs` passes
- [ ] `node scripts/validate-skill-body.mjs` passes

When the first plugin lands, flip `plugins.minItems` in `scripts/marketplace.schema.json`
from `0` back to `1`. It is `0` only so the gates can pass on an empty marketplace.

## Structure

```
plugins/<name>/
├── plugin.json           # {name, description, author{name,url}} — NO version key
├── README.md             # user-facing, for someone browsing the repo
├── CLAUDE.md             # maintainer SSoT — invariants, decisions, "don't touch this"
├── skills/
│   └── <skill>/
│       ├── SKILL.md      # the only capability file; dir name IS the command name
│       └── references/   # loaded on demand; required once SKILL.md exceeds 200 lines
├── scripts/              # backing executables
├── hooks/hooks.json      # optional; the only place ${CLAUDE_PLUGIN_ROOT} is valid
└── lib/                  # optional plugin-scoped shared modules
```

**Why both `README.md` and `CLAUDE.md`.** The README is for a human browsing the
repository. The CLAUDE.md is for a future session that needs the load-bearing
invariants, the decisions already made, and the things that look wrong but are
deliberate — none of which belongs in user-facing copy.

**There is no `commands/` directory inside a plugin.** `skills/<name>/SKILL.md` is the
single capability file. A parallel `commands/` layer means maintaining two identical
files per skill, and the copies drift. Repository-level slash commands — the release
namespace — are a different thing and live in `.claude/commands/`.

**Cross-plugin code sharing is not a goal.** Per-plugin isolation is intentional. Only
byte-identical logic proven with `diff` is real duplication; shared *conventions* are
adopted, not extracted.

## The SKILL.md contract

Enforced by `scripts/validate-skill-body.mjs`. All of these are errors, not advice.

| Rule | Why |
|---|---|
| `name:` equals the directory name | The slash command resolves on the **directory**. A mismatch is invisible at runtime while the description keeps advertising the old name. |
| `description:` ≤ 200 characters | Descriptions are always in context, charged against a budget. |
| Over 200 lines requires `references/` | The body loads on every trigger; references load on demand. |
| Self-Evolving banner near the top | The skill is expected to be corrected in place when it turns out to be wrong. |
| `## Post-Execution Reflection` is the **last** section | Last on purpose — recency is what makes it get read. |

Frontmatter keys in use: `name`, `description`, `allowed-tools` (inline comma-separated,
never a YAML list), and optionally `argument-hint`, `model`, `disable-model-invocation`.

Write `description` as prose a human would read — "Use when the user wants to…" — rather
than a keyword list. If hard keyword hooks help discovery, append them as
`TRIGGERS - a, b, c`. **Use a hyphen, never a colon**: a colon inside an unquoted YAML
scalar breaks parsing.

### Body shape

````markdown
---
name: <matches the directory>
description: Use when ... TRIGGERS - keyword, keyword.
allowed-tools: Read, Bash
---

# Title

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

## Execution

```bash
ROOT="$(skills-plugin-root <plugin>)"
bash "$ROOT/scripts/thing.sh"
```

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If the underlying tool drifted, update this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
````

## Shell compatibility

Claude Code's Bash tool may run through zsh. Wrap bash-specific syntax:

```bash
/usr/bin/env bash << 'SCRIPT_EOF'
if [[ -f "$FILE" ]]; then echo "Found"; fi
SCRIPT_EOF
```

## Naming

Never shadow a Claude Code built-in slash command. And when a command name equals its
plugin name, the full `/<plugin>:<command>` form is mandatory — typing `/<plugin>` alone
is read as the plugin prefix, not the command.
