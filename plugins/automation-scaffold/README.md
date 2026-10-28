# automation-scaffold

Scaffold a repository for a Power Platform, n8n, Make.com or Zapier automation, starting from
what is running in production, and take it to its first release under one convention.

Category: `devops`

## What one scaffold run does

1. **Discovers**, read-only, everything related to the app, flow or workflow you name:
   the SharePoint lists it uses, the flows on those lists and those it calls, the n8n, Make
   and Zapier webhooks they call. Every link cites where it was found.
2. **Uses or creates** the GitHub repository (the name you give, or the most fitting one).
3. **Scaffolds** the standard layout, exports each app, flow, workflow and scenario from
   production (secrets redacted, test data stripped) and pins what is live.
4. **Follows the git protocol**: Conventional Commits, a PR checked by `mise run pr:check`,
   **rebase and merge**, no AI attribution anywhere.
5. **Releases** `v1.0.0` of every component with `mise run release`, and verifies tags,
   GitHub Releases, production against the pins, and the history.

## Skills

| Command | What it does |
|---|---|
| `/automation-scaffold:scaffold` | The whole run above, after one approval of the plan |
| `/automation-scaffold:setup` | GitHub owner, commit author, environment, n8n and Make settings (no secrets) |
| `/automation-scaffold:health` | Checks tools, sign-ins and access, one line each |

Inside a scaffolded repository everything else is a standard `mise run …` task: `export`,
`release:pin`, `release:verify`, `pr:check`, `release:dry`, `release`.

## Install

```
/plugin marketplace add nasimubd/skills
/plugin install automation-scaffold@skills
```

Then `/automation-scaffold:setup` and `/automation-scaffold:health`.

## Requirements

`git`, `gh` (signed in), Node.js 22+, `npm`, `mise`, `jq`, `unzip`; `az` for Power Platform;
an n8n API key and/or Make API token in the macOS Keychain for those platforms.

See [references/convention.md](./references/convention.md) for the exact layout and protocol,
and [references/platform-apis.md](./references/platform-apis.md) for the API calls used.
