# skills

A [Claude Code](https://claude.com/claude-code) plugin marketplace.

[![License](https://img.shields.io/badge/license-MIT-yellow.svg)](./LICENSE)

## Plugins

**None yet.** The scaffold is complete and every gate passes on an empty marketplace —
deliberately, so the first plugin lands against working machinery rather than alongside
it.

When plugins exist, `.claude-plugin/marketplace.json` is the source of truth for what
they are. Any list in this README is derived from it; if the two disagree, the manifest
is right and the README is stale.

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
.mise/tasks/           # runnable tasks; the release pipeline lives here
scripts/               # gates and release tooling
plugins/               # one directory per plugin
docs/                  # ADRs, design specs, release workflow
```

## Gates

```bash
node scripts/validate-plugins.mjs        # manifests, schema, paths, dependencies
node scripts/check-version-equality.mjs  # the version lockstep actually holds
node scripts/validate-skill-body.mjs     # SKILL.md structural contract
mise run release:preflight               # everything, plus tree and commit state
```

All gates run **locally**. There is no CI and no `.github/` directory; `release:preflight`
is the single place every check is invoked. A check that does not run there does not run.

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

1. Create a plugin under `plugins/<name>/`
2. Add its entry to `.claude-plugin/marketplace.json`
3. Run the gates above
4. Commit with [Conventional Commits](https://www.conventionalcommits.org/) — short
   subject, verbose body
5. Open a PR; it will be squash-merged, so the PR title becomes the commit subject

## License

[MIT](./LICENSE)
