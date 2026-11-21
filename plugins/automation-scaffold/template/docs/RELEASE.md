# Releases and rollback

Every Power App, Power Automate flow, n8n workflow and Make scenario in this repository is a
**component** with its own version, tag, changelog and GitHub Release. Commits follow
Conventional Commits; semantic-release, run locally as `semantic-release-bot`, cuts one
release per component.

A release is a record in git. **It never deploys anything.** Changing production is a
separate step that needs approval each time (`CLAUDE.md`).

## Setup

```bash
mise install          # node and jq
mise run setup        # npm ci + commit-msg hook (core.hooksPath .githooks)
```

## Commits

`type(scope): subject`, 72 characters at most. The body explains why.

| Type | Release |
|---|---|
| `feat` | minor |
| `fix`, `perf`, `docs`, `chore`, `style`, `refactor`, `test`, `build`, `ci`, `revert` | patch |
| `type(scope)!:` or a `BREAKING CHANGE:` / `BREAKING:` footer | major |

- **Scope**: a component id (`app-…`, `flow-…`, `n8n-…`, `make-…`) or a repo scope from
  `commitlint.config.cjs`.
- **The folder decides what releases, not the scope.** A commit counts toward a component's
  next release when it changes a file under that component's `path`.
- **No AI attribution** in any commit, PR or release (`.claude/rules/git.md`). The hook and
  `pr:check` reject it.
- Every change goes through a PR: `mise run pr:check -- "<title>" <body-file>`, then **rebase
  and merge**.

## Components

`releases/components.json` lists every component: id, kind, platform name, folder and
production IDs. No secrets.

| Kind | Id prefix | Tag | Source in git | Platform IDs |
|---|---|---|---|---|
| Canvas app | `app-` | `app-<slug>-vX.Y.Z` | `src/Src/*.pa.yaml` | `environmentId`, `appId` |
| Cloud flow | `flow-` | `flow-<slug>-vX.Y.Z` | `definition.json`, `manifest.json` | `environmentId`, `flowId` |
| n8n workflow | `n8n-` | `n8n-<slug>-vX.Y.Z` | `workflow.json` | `instance`, `workflowId` |
| Make scenario | `make-` | `make-<slug>-vX.Y.Z` | `blueprint.json` | `zone`, `scenarioId` |

Adding a component, in the commit that first adds its source:

1. Add the entry to `releases/components.json`.
2. Add `<path>/package.json`: `name` = the id, `private: true`, and `release.extends` =
   `["semantic-release-monorepo", "<relative path>/release.base.cjs"]`.
3. `mise run export -- <id>` and `mise run release:pin <id>`.
4. `mise run components:check`.

Its first release is `v1.0.0`.

## Production pins

`<path>/release.lock.json` records which version is live, and a digest computed the same way
from git and from production, so equal digests mean the same app, flow, workflow or scenario.

```bash
mise run release:pin <id>     # pin what is live now
mise run release:verify       # compare production with every pin; exit 1 on drift
```

`verify` prints `ok`, `ok (re-saved, same content)` or `DRIFT` per component. On drift, find
out who changed what before anything else.

## Cutting a release

On a clean `main` that matches `origin/main`, after merging:

```bash
mise run release:dry      # preview
mise run release          # tags, CHANGELOG commits, GitHub Releases
mise run release:verify   # production still matches every pin
```

For each component, `scripts/release.sh`:

1. **Gate**: skips the component unless its committed source matches its pin, so a tag
   always names what is live.
2. Runs semantic-release in the component folder; only commits that touched it count.
3. Commits `CHANGELOG.md` as `chore(release): <id>-vX.Y.Z [skip ci]` and creates the tag and
   GitHub Release, with `release.lock.json` attached.

The everyday loop: change the source in a PR → deploy (approved) → `mise run release:pin
<id>` → commit the pin in the same PR → `pr:check` → rebase and merge → `mise run release`.

## Rollback

Every rollback changes production and needs approval; record it in `docs/decisions.md`.

1. Pick the tag: `git tag -l '<id>-v*' --sort=-v:refname`.
2. Read that tag's `release.lock.json` (`live.version` to restore, `digest` to reach).
3. Restore through the platform's own history where it exists (Power Apps versions, solution
   flow version history, n8n workflow history, Make scenario versions); otherwise re-apply the
   source from the tag.
4. `mise run release:pin <id>`; the digest must equal the tag's. Commit it as
   `revert(<id>): roll back to <tag>`.
