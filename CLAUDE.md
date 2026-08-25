# skills — repository hub

A [Claude Code](https://claude.com/claude-code) plugin marketplace. One home for every
plugin its maintainer builds, distributed through a single manifest and gated by a
single command.

**Architecture**: hub-and-spoke with progressive disclosure.

This file is the **hub**: what the repository is, how it is versioned, what the gates
are, and the conventions that bind every plugin. Each area carries its own **spoke**.
Read this first, then the spoke for whatever you are touching.

**Progressive disclosure rule.** Each layer adds what the shallower layer did not
cover. Repository-wide facts live here and are linked to, never restated. Facts local
to one plugin live in that plugin's spoke and nowhere else. Duplication between hub
and spoke is a defect — when they drift, and they will, there is no way to tell which
copy is current.

**Same-commit rule.** These files are updated in the same commit as the change they
describe. A stale doc is a defect, not a chore.

## Navigation

| Layer | File | Covers |
|---|---|---|
| Hub | `CLAUDE.md` (this file) | Repository-wide conventions, gates, versioning |
| Spoke | [plugins/CLAUDE.md](./plugins/CLAUDE.md) | How to add and structure a plugin |
| Spoke | [docs/CLAUDE.md](./docs/CLAUDE.md) | Documentation standards, ADR conventions |
| Deep | `plugins/<name>/CLAUDE.md` | Per-plugin invariants — the maintainer's SSoT |

There are currently **no plugins**. The scaffold is complete and every gate passes on
an empty marketplace; that is deliberate, so the first plugin lands against working
machinery rather than alongside it.

## Plugin discovery

**SSoT**: `.claude-plugin/marketplace.json`

A plugin directory that exists without a marketplace entry produces "Plugin not found".
Nothing else in the repository is authoritative about which plugins exist.

```bash
node scripts/validate-plugins.mjs
```

`.claude-plugin/plugins` is a tracked symlink to `../plugins`, so a `source` of
`./plugins/<name>` resolves whether it is read from the repository root or from inside
`.claude-plugin/`.

## Path resolution — never `${CLAUDE_PLUGIN_ROOT}` in a SKILL.md

`CLAUDE_PLUGIN_ROOT` is **not** a shell variable. Claude Code substitutes the literal
`${CLAUDE_PLUGIN_ROOT}` inside plugin *manifests* — `hooks/hooks.json`, `.mcp.json`,
`.lsp.json` — and injects it into hook and MCP *subprocess* environments. It never
reaches the Bash tool, and a `SKILL.md` body is served to the model verbatim. A skill
that references it gets an empty string, and the failure is silent.

```bash
SCRIPT="$(skills-plugin-root <plugin>)/skills/<skill>/run.sh"   # in a SKILL.md
"command": "bun ${CLAUDE_PLUGIN_ROOT}/hooks/handler.ts"         # in hooks.json — correct
```

`scripts/skills-plugin-root` reads `~/.claude/plugins/installed_plugins.json`, so it
returns the version Claude Code actually loaded. Never glob the version cache — it
retains orphaned versions.

## Versioning

**One number.** The marketplace root version, the marketplace-as-a-plugin manifest, and
`package.json` all carry the same semver value, and every registered plugin entry
carries it too. `scripts/sync-versions.mjs` stamps all of them at release time and
asserts the replacement counts.

A per-plugin `plugins/<name>/plugin.json` **must not carry a `version` key**. Nothing
bumps it, so it can only be right by coincidence. The marketplace entry is the single
source of truth. `scripts/check-version-equality.mjs` enforces both halves of this.

The git tag is `v<version>`.

## Gates

```bash
node scripts/validate-plugins.mjs        # manifests, schema, paths, deps, skills
node scripts/check-version-equality.mjs  # the version lockstep actually holds
node scripts/validate-skill-body.mjs     # SKILL.md structural contract
mise run release:preflight               # all of the above, plus tree and commit state
```

**Local-first CI.** There is no `.github/` directory and no GitHub Actions. Every gate
runs locally, and `release:preflight` is the one place they are all invoked. If a check
does not run in preflight, it does not run.

Three properties every gate here holds to, because their absence is what makes a green
build lie:

- **Missing evidence is a failure.** A check whose output artifact is absent has not
  passed; it has failed to run.
- **Counts, not ticks.** Every gate prints how many things it examined. "0 discovered"
  and "0 failed" are different facts and must be distinguishable.
- **Gating versus informational is explicit**, in the output and in the exit path.

Retired checks are tombstoned with a date and a reason, never deleted — a numbering gap
with no explanation reads as an oversight.

## Conventions

- **Commits** are [Conventional Commits](https://www.conventionalcommits.org/): subject
  ≤50 chars hard-preferred, ≤72 hard cap; body wrapped at 72. Short subject, verbose
  body.
- **Every commit type releases.** A consumer pinned to a version needs a new version
  even for a docs-only fix, so `docs`, `chore`, `refactor` and the rest all bump patch.
- **PRs are squash-merged.** The PR title becomes the commit subject and follows the
  same grammar.
- **Release notes are generated from commits.** The Releases page is the changelog.
  A hand-maintained parallel file drifts; a generated one cannot.
- **No AI attribution** in any commit message, PR body, release note, issue, or code
  comment. No `Co-Authored-By` trailers, no generated-with footers.
- **No machine-specific literals in tracked source.** Hostnames, usernames, absolute
  paths, credentials and chat identifiers are resolved at run time. This repository is
  intended to become public: a literal committed here is a literal published.
- **Skill directories are named for what they do**, never for their position in a
  sequence. A number tells a reader when something runs, not what it is, and goes stale
  the moment a step is inserted.

### Link conventions

| Target | Format | Example |
|---|---|---|
| Skill-internal | Relative | `[Guide](./references/guide.md)` |
| Repository docs | Repo-root | `[ADR](/docs/adr/2026-01-01-slug.md)` |
| External | Full URL | `[Docs](https://example.com)` |

Skill files are installed into `~/.claude/`. Relative paths survive that move; repo-root
paths do not, which is why only `/docs/adr/` and `/docs/design/` may be referenced that
way from a skill.

## Terminology

| Term | Definition |
|---|---|
| **Plugin** | Marketplace-installable container with a manifest and bundled skills |
| **Skill** | A capability with `SKILL.md` frontmatter; becomes `/<plugin>:<skill>` |
| **Command** | A slash command. Inside a plugin these come from skills; at repository level, from `.claude/commands/` wrappers over mise tasks |
| **Reference** | Supporting documentation under `references/`; loaded on demand, not executable |

Verb distinctions that matter in task and skill names: **install** acquires, **setup**
verifies after installation, **init** scaffolds once, **configure** adjusts settings.
