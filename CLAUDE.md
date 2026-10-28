# Skills marketplace

This repository contains reusable Claude Code plugins and skills. Keep provider-
specific runtime implementations in their own repositories; marketplace plugins
should provide the user-facing installation, setup, and invocation surface.

## Terminology

| Term | Definition |
|---|---|
| **Plugin** | A marketplace-installable container with a manifest and bundled skills. |
| **Skill** | A reusable capability described by a `SKILL.md` file. |
| **Norn** | The planned runtime repository and agent-execution layer for natural-language tasks; it routes each request between deterministic tools, local decision models, Argus-routed models, Agent-S, and human approval. Pronounced **/nɔːrn/** (“norn”). |
| **Argus** | The high-throughput model gateway and account/session proxy. |
| **Jev** | TypeSafe’s typed decision-model product; do not write “JEB” when referring to it. |
| **Agent-S** | The optional computer-use executor for tasks that require visual desktop interaction. |

Norn is the canonical name for the runtime project. Use `Norn runtime` when
clarity matters and `norn` for the executable or package name.

## Plugin and skill conventions

These rules apply to every new plugin and skill. They were adopted on 2026-10-28
from a read-only review of [terrylica/cc-skills](https://github.com/terrylica/cc-skills),
a 40-plugin marketplace this repository already mirrors in structure, so a new
plugin should not need that investigation again. Details that apply only while
building a plugin (the SKILL.md contract, body shape, shell compatibility) are in
[plugins/CLAUDE.md](./plugins/CLAUDE.md); this section is the part every change
must respect.

### Where things live

| Path | What it holds | Registered by |
|---|---|---|
| `plugins/<plugin>/` | Claude Code plugins | An entry in `.claude-plugin/marketplace.json` |
| `skills/<skill>/` | Platform-neutral Agent Skills (Claude Code and Codex) | A symlink `.agents/skills/<skill>` → `../../skills/<skill>` |
| `codex-plugins/<plugin>/` | Codex plugin packages | `.codex-plugin/plugin.json` inside the package |

A directory that is not registered does not exist for the host: Claude Code reports
"Plugin not found", and Codex never discovers the skill. Register in the same commit
that creates the directory. `validate-plugins.mjs` and `validate-agent-skills.mjs`
fail on an unregistered entry.

### Categories

Every marketplace entry has exactly one `category`, chosen from the closed enum in
`scripts/marketplace.schema.json`:

`development`, `productivity`, `quality`, `automation`, `ai`, `documentation`,
`devops`, `documents`, `enforcement`, `trading`, `utilities`.

**Do not add a category.** Pick the closest existing one and put finer labels
(for example `developer-productivity`) in `keywords`. Near-duplicate categories
split one shelf into two and make plugins harder to find. Messaging and
communication plugins (Teams, email, chat) go in `productivity`, as cc-skills
files Gmail, WhatsApp and Telegram.

### Naming

All names are lowercase kebab-case.

| Kind of plugin | Pattern | Example |
|---|---|---|
| Drives one external service (send, read, sync) | `<service>-commander` | `teams-commander` |
| A bundle of related tools for one area | `<area>-tools` | `quality-tools` |
| Anything else | A descriptive noun phrase | `custom-statusline` |

A skill's directory name is its command name (`/<plugin>:<skill>`). Never shadow a
built-in slash command.

### Anatomy of a plugin

```
plugins/<plugin>/
├── plugin.json        # name, description, author{name,url}; NO version key
├── README.md          # for users browsing the repository
├── CLAUDE.md          # for maintainers: invariants, decisions, "looks wrong but is deliberate"
├── bin/<plugin>       # the plugin's command, on the Bash PATH while enabled
├── skills/<skill>/SKILL.md
├── references/        # long material, loaded on demand
├── scripts/           # the executables the skills call
├── hooks/hooks.json   # optional enforcement (see below)
└── tests/test-*.sh    # auto-discovered by the regression suite
```

- **Service-backed plugins ship `setup` and `health` skills.** `setup` creates the
  local configuration; `health` checks every dependency and prints what it examined.
- **Machine-specific values are never committed.** Contacts, IDs, tenant values and
  paths live under `~/.config/<plugin>/` and state under `~/.local/state/<plugin>/`.
  Secrets come only from the macOS Keychain at run time.
- **Lowest-risk capability tier by default.** When a plugin can act on the outside
  world in more than one way, number the tiers. Tier 1 is the one where a person
  takes the final action (for example, a link that opens a pre-filled message the
  person sends). Build higher tiers only when asked; document them otherwise.
- **Rules that matter are enforced in code, not only in prose.** A SKILL.md
  instruction can be skipped; a script check or a `PreToolUse` hook cannot. Give
  every hook an explicit escape marker that needs a written reason (for example
  `TEAMS-SEND-OK: <reason>`), and make the hook fail open on its own errors.
- **Scripts follow the repository's language.** Bash with `set -euo pipefail` and
  `jq`; fixed exit codes (0 ok, 1 runtime error, 2 usage, 3 gate refused); every
  command prints what it examined.
- **A plugin's command goes in `bin/<plugin>`; skills call it by name.** Claude Code
  (v2.1.91+) puts every enabled plugin's `bin/` on the Bash tool's PATH, after the
  user's own entries, so a plugin cannot shadow a system command. The `bin/` file is
  a thin dispatcher into `scripts/`; make it executable and resolve symlinks. A
  newly installed plugin's `bin/` appears after `/reload-plugins` or a new session.
  `${CLAUDE_PLUGIN_ROOT}` is valid only inside manifests such as `hooks.json`, and
  `scripts/skills-plugin-root` remains only for older plugins that have no `bin/`.

### Same-commit rule

A new or renamed plugin updates, in the same commit:

1. `.claude-plugin/marketplace.json` (entry with the current marketplace version)
2. the plugin table in `README.md` (name, what it does, category)
3. the plugin list in `plugins/CLAUDE.md`
4. the plugin's own `README.md` and `CLAUDE.md`

A new platform-neutral skill adds its `.agents/skills/` symlink in the same commit.

### Gates

Run all of them before committing; `mise run release:preflight` runs them together.

```bash
node scripts/validate-plugins.mjs
node scripts/check-version-equality.mjs
node scripts/validate-skill-body.mjs
node scripts/validate-agent-skills.mjs
mise run test-marketplace-hook-regression-suite
```

### Messages and other outward-facing text

A plugin that drafts text for a person to send (chat messages, emails, comments)
must back every factual claim with evidence the user can see before sending: the
source, the exact excerpt, when it was captured, and how to reproduce it. A claim
without evidence is removed, turned into a question, or marked as opinion. The
evidence is shown to the user; it does not have to appear in the message.
`teams-commander` is the reference implementation.

No AI attribution in commits, pull requests or release notes.
