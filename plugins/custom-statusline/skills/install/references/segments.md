# Segment reference

What each of the 8 lines in `scripts/statusline.sh` shows, where its data
comes from, and what it needs to render.

## Session (line 1)

`session_id` (shortened to its first 8 characters) plus `session_name` if
the payload carries one. Straight off stdin — no network, no git.

## Directory (line 1)

`workspace.current_dir` (falling back to `.cwd`), with `$HOME` collapsed to
`~` and the middle of a long path elided to
`CUSTOM_STATUSLINE_DIRECTORY_MAX_CHARS` (default 40) so the leaf directory
name and the tree root both stay visible.

## Git (line 2)

Branch name (or `detached:<sha>` when HEAD isn't on a branch), dirty-state
counts as `+staged ~modified ?untracked` (each shown only when non-zero),
and ahead/behind vs. the upstream as `⇡ahead ⇣behind`. Computed locally with
`git status --porcelain` and `git rev-list --left-right --count`, no
network. No `gh` scope required.

## Release (line 2)

Latest GitHub Release tag for `workspace.repo.{owner,name}`, via
`gh api repos/{owner}/{repo}/releases/latest`. Cached for
`CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS` (default 300s). Needs the `repo`
scope; a repo with no releases, or a `gh` call that fails for any reason,
just omits this piece.

## Deployment (line 4)

Two independent sources, rendered together when both exist, either alone
when only one does, and the whole segment omitted when neither does:

1. The GitHub Deployments API's latest deployment, as `environment:state`
   (e.g. `production:success`), via
   `gh api repos/{owner}/{repo}/deployments` + its `/statuses`.
2. The most recent Actions workflow run whose name matches `deploy*`
   (case-insensitive), as `name:conclusion`.

Both cached separately for `CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS`
(default 180s). Needs the `repo` scope for deployments and `workflow` (or
`repo`) for Actions runs.

## Package (line 4)

Also two independent sources, same render-what-exists rule:

1. GitHub Packages, as `name:versionCountv` — there's no
   per-repository packages endpoint, so this queries the owner's org
   packages first, falls back to iterating the user-scoped endpoint per
   package type, then filters for a package whose `repository.full_name`
   matches this repo. Needs `read:packages`; most repos (this one included)
   don't publish there, so this piece is commonly absent.
2. Release-vs-manifest drift, as `in-sync`, `ahead`, or `behind` — compares
   the latest release tag against whichever of `package.json`,
   `Cargo.toml`, `pyproject.toml`, or a bare `VERSION` file exists in the
   repo root, in that priority order.

Cached for `CUSTOM_STATUSLINE_PACKAGE_TTL_SECONDS` (default 600s).

## Context window (line 3)

`context_window.used_percentage` rendered as a block-character bar
(`CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH` characters wide, default 10) plus the
raw percentage. Claude Code computes this figure itself and hands it over
on stdin — no estimation, no network.

## Model (line 5)

`model.display_name` plus session duration (coarsest non-zero unit —
`1h23m`, `5m`, or `42s`), cost (`$X.XX`), and net lines changed
(`+added/-removed`, shown only when non-zero). All from `cost.*` on stdin.
No network.

## Cache TTLs at a glance

| Segment | Env var | Default |
|---|---|---|
| Release | `CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS` | 300s |
| Deployment | `CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS` | 180s |
| Package | `CUSTOM_STATUSLINE_PACKAGE_TTL_SECONDS` | 600s |

Cache files live under `CUSTOM_STATUSLINE_CACHE_DIR` (default
`~/.cache/custom-statusline`); delete that directory to force every
network-backed segment to re-fetch on the next render.
