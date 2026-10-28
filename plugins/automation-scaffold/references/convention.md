# The convention a scaffolded repository follows

Every repository `automation-scaffold` creates follows the same layout, version control and
git protocol. They were modelled on the user's private reference automation repository (reviewed
read-only on 2026-10-28) and written here from its documented behaviour; no code was copied
from that private repository.

## Layout

| Path | Contents |
|---|---|
| `src/CanvasApps/<App>/src/Src/*.pa.yaml` | Canvas app source from the live (published) version |
| `src/Flows/<slug>/` | `definition.json` (secrets redacted), `manifest.json` |
| `workflows/<slug>/workflow.json` | n8n export: published version, no `pinData`, secrets redacted |
| `src/Make/<slug>/blueprint.json` | Make scenario blueprint |
| `<component>/package.json`, `release.lock.json`, `CHANGELOG.md` | Release config, production pin, changelog |
| `releases/components.json` (+ schema) | The registry: id, kind, name, folder, production IDs |
| `project.json` | Environment IDs, URLs and Keychain item names (no secrets) |
| `docs/` | `architecture.md` (links with evidence), `environment.md`, `decisions.md`, `RELEASE.md` |
| `scripts/` | `export.js`, `release-pin.js`, `release.sh`, `check-components.js`, `pr-check.sh`, `no-ai-attribution.js`, `lib/platform.js` |
| `CLAUDE.md`, `.claude/rules/` | Core rules; `git.md`, `power-platform.md`, `n8n-workflows.md`, `make-zapier.md` |
| `mise.toml`, `package.json`, `commitlint.config.cjs`, `release.base.cjs`, `.githooks/` | Tooling |

## Version control

- One component per production artifact, each with its own semver, tag `<id>-vX.Y.Z`,
  `CHANGELOG.md` and GitHub Release (semantic-release-monorepo; release commits by
  `semantic-release-bot` as `chore(release): <tag> [skip ci]`).
- Every commit type releases: breaking = major, `feat` = minor, everything else = patch.
- A **production pin** (`release.lock.json`) per component records the live version and a
  digest computed identically from git and from production. A release is cut only when the
  committed source matches the pin, so a tag always names what is live.
- A release never deploys.

## Git protocol

1. Conventional Commits, header ≤ 72 characters, scope = component id or repo scope
   (commitlint with a generated `scope-enum`), checked by the commit-msg hook.
2. One component per commit where possible.
3. Every change through a PR, checked with `mise run pr:check -- "<title>" <body>` (registry,
   branch commits, title, body).
4. **Rebase and merge** (`gh pr merge --rebase --delete-branch`); no merge commits.
5. Releases from a clean `main` that matches `origin/main`: `release:dry`, `release`,
   `release:verify`.
6. **No AI attribution** in commits, PR titles and bodies, merges or releases. One
   definition (`scripts/no-ai-attribution.js`) is used by commitlint and `pr:check`.
7. Commits are authored by the configured author; the GitHub account acting is the one
   signed in to `gh`.

## The scaffold's own commits

On branch `chore/scaffold-<timestamp>`, in this order:

1. `chore(repo): scaffold repository and release convention`: everything except component
   folders and generated docs
2. `feat(<id>): add <name> from production`: one per component (source, package.json, pin)
3. `docs: document architecture, environment and decisions`

PR title: `chore(repo): scaffold <name> with release convention`. After the rebase merge,
`mise run release` gives every pinned component `v1.0.0`.
