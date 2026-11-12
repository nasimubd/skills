# skills

**A [Claude Code](https://claude.com/claude-code) plugin marketplace** — skills and
plugins you can install, and the tooling to build your own.

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

| Plugin | What it does | Category |
|---|---|---|
| [`automation-scaffold`](./plugins/automation-scaffold) | Scaffold a release-ready repository for a Power Platform, n8n, Make or Zapier automation from what runs in production: discovery with evidence, standard layout, git protocol, first release. | `devops` |
| [`change-guardrails`](./plugins/change-guardrails) | Deterministic guardrails for shell commands: stops or asks before force-pushes to protected branches, recursive deletes of system paths, disk wipes, destructive SQL and similar, with a written-reason escape and an audit log. | `enforcement` |
| [`click-path-guides`](./plugins/click-path-guides) | Write step-by-step UI click-path guides that are checked against the application's own definition: every bold control must exist in the source, menu paths follow one format, and position or colour wording is rejected. | `documentation` |
| [`custom-statusline`](./plugins/custom-statusline) | Multi-line Claude Code status line driven by the statusline JSON payload plus GitHub-derived repository signals. | `productivity` |
| [`investigation-tools`](./plugins/investigation-tools) | Read-only triage briefs and blameless incident notes whose claims carry evidence: scans fetched content for planted instructions, keeps secrets out of what is saved, and takes verifiable snapshots before any change. | `devops` |
| [`norn-agent`](./plugins/norn-agent) | Install and operate Norn, a local-first runtime for routing natural-language tasks across tools, models, desktop automation, and approval gates. | `productivity` |
| [`teams-commander`](./plugins/teams-commander) | Draft Microsoft Teams messages where every factual claim is backed by evidence you can see, then open the chat in the Teams app with the message on your clipboard. | `productivity` |
| [`typeless-migrate`](./plugins/typeless-migrate) | Safely archive Typeless history, recordings, settings, and dictionary-import data without copying account credentials. | `productivity` |

The repository also includes a Codex-compatible package under
[`codex-plugins/norn-agent`](./codex-plugins/norn-agent). Both integrations use
the same external [Norn runtime](https://github.com/nasimubd/norn).

## Installation

```
/plugin marketplace add nasimubd/skills
/plugin install <plugin>@skills
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
skills/                # platform-neutral Agent Skills (Claude Code and Codex)
.agents/skills/        # Codex registration: one symlink per skills/ entry
codex-plugins/         # Codex-compatible plugin packages
docs/                  # ADRs, design specs, release workflow
```

## Gates

```bash
node scripts/validate-plugins.mjs        # manifests, schema, paths, dependencies
node scripts/check-version-equality.mjs  # the version lockstep actually holds
node scripts/validate-skill-body.mjs     # SKILL.md structural contract
node scripts/validate-agent-skills.mjs   # shared skills: contract and .agents/skills registration
mise run release:preflight               # everything, plus tree and commit state
```

All gates run **locally**. There is no CI and no GitHub Actions workflow;
`release:preflight` is the single place every check is invoked. A check that does not
run there does not run.

Each gate prints how many things it examined rather than a bare pass — "0 discovered" and
"0 failed" are different facts, and a green tick cannot distinguish them.

## For plugin developers

Plugin READMEs are maintained as part of the plugin change. The README synchronization gate fails when a registered plugin lacks its own README, its marketplace description, its row in this Plugin table, or a root marketplace link, and when an unregistered plugin directory exists. Run it after every plugin addition, fix, or removal.

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
that references it silently receives an empty string. Ship the plugin's command in
`bin/<plugin>` instead: Claude Code puts an enabled plugin's `bin/` on the Bash PATH,
so skill bodies call it by name.

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
to run, commit conventions, and the PR/rebase-merge flow.

## Code of Conduct

This project follows the [Contributor Covenant](./CODE_OF_CONDUCT.md).

## Security

See [SECURITY.md](./SECURITY.md) to report a vulnerability privately.

## License

[MIT](./LICENSE)

| [`typeless-migrate`](./plugins/typeless-migrate) | Safely archive Typeless history, recordings, settings, and dictionary-import data without copying account credentials. |
