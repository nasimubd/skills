# {{PROJECT_TITLE}}

{{BADGES}}
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-FE5196?logo=conventionalcommits&logoColor=white)](https://www.conventionalcommits.org/en/v1.0.0/)
[![semantic-release](https://img.shields.io/badge/semantic--release-per%20component-E10079?logo=semanticrelease&logoColor=white)](docs/RELEASE.md)

{{DESCRIPTION}}

This repository is the source of record for the automation: every app, flow and workflow
below is exported from production, versioned on its own, and pinned to what is live.

## How it fits together

{{ARCHITECTURE_MERMAID}}

The evidence for every link is in [docs/architecture.md](docs/architecture.md).

## Components

{{COMPONENTS_TABLE}}

## Repository layout

| Path | Contents |
|---|---|
| `src/CanvasApps/<App>/` | Canvas app source (`.pa.yaml`), release pin, changelog |
| `src/Flows/<slug>/` | Power Automate flow: `definition.json`, `manifest.json`, release pin |
| `workflows/<slug>/` | n8n workflow export (`workflow.json`, secrets and test data removed) |
| `src/Make/<slug>/` | Make.com scenario blueprint |
| `releases/components.json` | Every released component and its production IDs |
| `project.json` | Environment IDs and URLs for the scripts (no secrets) |
| `docs/` | Architecture (with evidence), environment, decisions, release and rollback guide |
| `scripts/` | Export, pin, verify, release and checks |
| `.claude/` | Working rules for the AI assistant used on this project |

## Working on it

```bash
mise install && mise run setup            # once
mise run export -- <id>                   # pull a component's production source (read-only)
mise run pr:check -- "<PR title>" body.md # before opening or merging a PR
mise run release                          # from a clean main, after merging
```

Commits follow Conventional Commits, PRs are rebased and merged, and nothing carries AI
attribution. See [docs/RELEASE.md](docs/RELEASE.md) and [.claude/rules/git.md](.claude/rules/git.md).
