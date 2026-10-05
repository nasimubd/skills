# skills

**Platform-agnostic agent skills with Claude Code and Codex adapters** — reusable
skills, plugins, and the tooling to build and verify your own.

[![License: MIT](https://img.shields.io/badge/license-MIT-yellow.svg)](./LICENSE)
[![Latest release](https://img.shields.io/github/v/release/nasimubd/skills)](https://github.com/nasimubd/skills/releases)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://conventionalcommits.org)

## Table of contents

- [Plugins](#plugins)
- [Installation](#installation)
- [Repository structure](#repository-structure)
- [Gates](#gates)
- [For plugin developers](#for-plugin-developers)
- [Versioning](#versioning)
- [Contributing](#contributing)
- [Code of Conduct](#code-of-conduct)
- [Security](#security)
- [License](#license)

## Plugins

`.claude-plugin/marketplace.json` is the source of truth for what plugins exist. Any
list here is derived from it; if the two disagree, the manifest is right and this README
is stale.

| Plugin | What it does |
|---|---|
| [`custom-statusline`](./plugins/custom-statusline) | Cross-platform custom status line: a Claude Code renderer that follows the reference template and a native Codex TUI footer adapter. |

## Installation

```
/plugin marketplace add nasimubd/skills
/plugin install <plugin>@skills
```

Codex discovers the shared skill through `.agents/skills/`. To configure its
native footer directly:

```bash
bash skills/custom-statusline/scripts/configure-codex-statusline.sh install
```

## Repository structure

```
.claude-plugin/
  marketplace.json     # SSoT — the registry of every plugin
  plugin.json          # this marketplace, installable as a plugin itself
  plugins -> ../plugins
.claude/commands/      # repository-level slash commands (the release namespace)
.github/               # issue/PR templates
.mise/tasks/           # runnable tasks; the release pipeline lives here
scripts/               # gates and release tooling
plugins/               # one directory per plugin
skills/                # canonical Agent Skills shared by supported hosts
.agents/skills/        # Codex repository-discovery links to skills/
docs/                  # ADRs, design specs, release workflow
```

## Gates

```bash
node scripts/validate-plugins.mjs        # manifests, schema, paths, dependencies
node scripts/check-version-equality.mjs  # the version lockstep actually holds
node scripts/validate-skill-body.mjs     # SKILL.md structural contract
node scripts/validate-agent-skills.mjs   # portable Agent Skills contract
mise run release:preflight               # everything, plus tree and commit state
```

All gates run **locally**. There is no CI and no GitHub Actions workflow;
`release:preflight` is the single place every check is invoked. A check that does not
run there does not run.

Each gate prints how many things it examined rather than a bare pass — "0 discovered" and
"0 failed" are different facts, and a green tick cannot distinguish them.

## For plugin developers

See [plugins/CLAUDE.md](./plugins/CLAUDE.md) for the full contract. The traps worth
knowing before you write anything:

**Source paths take no trailing slash.**

```json
"source": "./plugins/thing"     // correct
"source": "./plugins/thing/"    // "Source path does not exist"
```

**`author` is an object, never a string.**

```json
"author": { "name": "you", "url": "https://github.com/you" }   // correct
"author": "you"                                                 // validation error
```

**No custom fields in a manifest.** The schema sets `additionalProperties: false` at
both levels, so an unrecognised key is an error rather than a shrug. That is the point —
a typo'd key that is silently ignored is a setting you believe you configured and did
not.

**A slash command resolves on the skill's directory name**, not on the `name:` field in
its frontmatter. When the two disagree nothing breaks loudly: the command still works,
while the description and its trigger keywords go on advertising an identity the skill
no longer has. `validate-skill-body.mjs` treats a mismatch as an error.

**`${CLAUDE_PLUGIN_ROOT}` is valid only in manifests** — `hooks.json`, `.mcp.json`,
`.lsp.json`. It is not a shell variable, it never reaches the Bash tool, and a `SKILL.md`
that references it silently receives an empty string. Use `skills-plugin-root <plugin>`
in skill bodies.

## Versioning

One semver number, carried by the marketplace root, the marketplace manifest,
`package.json`, and every registered plugin entry. `scripts/sync-versions.mjs` stamps
them at release time; `scripts/check-version-equality.mjs` asserts they agree.

A per-plugin `plugin.json` must not carry a `version` key — nothing bumps it, so it can
only ever be correct by accident.

The git tag is `v<version>`. Release notes are generated from commits; the Releases page
is the changelog.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for the full process — plugin structure, gates
to run, commit conventions, and the PR/squash-merge flow.

## Code of Conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md).

## Security

See [SECURITY.md](./SECURITY.md) to report a vulnerability privately.

## License

[MIT](./LICENSE)
