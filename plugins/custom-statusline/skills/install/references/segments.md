# Segment reference

What each line of `scripts/statusline.sh` shows, where its data comes from, and what
it needs to render. A line with nothing to show is left out, never replaced by an
error message.

| Line | Segment | Source | Network |
|---|---|---|---|
| 1 | Git indicators, then release | `git`, `gh` | release only, cached |
| 2 | Model | stdin payload | no |
| 3 | Context window | stdin payload | no |
| 4 | Clock | system clock | no |
| 5 | Directory and remote | payload, `git`, `gh` | visibility only, cached |
| 6 | Session | stdin payload | no |
| extra | Deployment, package | `gh` | yes, cached, off by default |

## Git (line 1)

`M:0 D:0 S:0 U:0 ↑:0 ↓:0 ≡:0 ⚠:0`

| Indicator | Counts |
|---|---|
| `M` | files modified in the working tree |
| `D` | files deleted in the working tree |
| `S` | files staged for commit |
| `U` | untracked files |
| `↑` `↓` | commits ahead of and behind the upstream (shown only when there is an upstream) |
| `≡` | stashes |
| `⚠` | files in a merge conflict |

Zero is dim; anything else is coloured. Computed locally with `git status --porcelain`,
no network. Prints nothing outside a git repository.

## Release (line 1, after the git indicators)

`v1.5.0 tag 13h ago`: the latest GitHub release for `workspace.repo.{owner,name}` and
the time since it was published, through `gh api repos/{owner}/{repo}/releases/latest`,
cached for `CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS` (default 300 s). The age is
recomputed on every render from the cached publish time. With no GitHub answer (no `gh`,
offline, no release) the newest **local** tag stands in, chosen by version order.

## Model (line 2)

`claude-sonnet-5-5 · high · thinking:true`: `model.id` (the display name when there is
no id), `effort.level` and `thinking.enabled`. A field the payload does not carry is left
out.

## Context window (line 3)

`ctx ▕██████·······|≈≈≈≈≈≈≈▏ 30% · 60k/200k · ~71k until compact`

The bar is 20 cells for the whole window (`CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH`). Cells
left of `|` are the room before automatic compaction; cells right of it are the region
past the trigger. Usage (`used_percentage`, `total_input_tokens`, `context_window_size`)
comes from the payload. Colour: dim far from the trigger, yellow within 15 points of it,
red once past it (`past compact`).

**The trigger position is an estimate.** Claude Code publishes no threshold, so it is
rebuilt in `context_compact_threshold`: the window minus 33,000 tokens by default;
`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` can move it earlier but never later;
`CLAUDE_CODE_AUTO_COMPACT_WINDOW` caps the window first. That is why the readout says
`~`. If the readout and the real compaction disagree, change that one function.

## Clock (line 4)

`Wed 11 Nov 2026 18:05 UTC | 13:05 EST`: UTC, then the system zone, or the zone in
`CUSTOM_STATUSLINE_CLOCK_TZ` (an IANA name such as `Asia/Kuala_Lumpur`). The second part
is dropped on a UTC machine. It redraws only when Claude Code does; to keep the minute
current while idle, add `"refreshInterval": 60` to the `statusLine` setting.

## Directory and remote (line 5)

`~/repo | https://github.com/owner/repo [public]`: `workspace.current_dir` with `$HOME`
shown as `~` (a long path loses its middle,
`CUSTOM_STATUSLINE_DIRECTORY_MAX_CHARS`, default 40), then the repository URL from the
payload or the `origin` remote, then `[public]` or `[private]` from
`gh api repos/{owner}/{repo}`, cached for `CUSTOM_STATUSLINE_VISIBILITY_TTL_SECONDS`
(default 3600 s). On a branch other than `main` or `master` the GitHub URL ends in
`/tree/<branch>`, which is how the branch name is shown. Without `gh` the badge is left
out. Outside a repository only the directory is shown.

## Session (line 6)

`~/.claude/projects JSONL ID: <session id>`: the folder holding the session transcript
(two levels above `transcript_path`, so a relocated config directory is shown as is) and
the id, ready to paste into a prompt.

## Deployment and package (extra lines)

Off by default. Turn on with `CUSTOM_STATUSLINE_EXTRAS=deployment,package` (either or
both). Each renders only when there is real data.

**Deployment**: the latest GitHub Deployments entry as `environment:state`
(`production:success`) and the latest Actions run whose name matches `deploy*` as
`name:conclusion`; cached for `CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS` (180 s). Needs the
`repo` scope.

**Package**: GitHub Packages as `name:versionCountv` (org packages first, then the user
endpoint per package type; needs `read:packages`) and release-vs-manifest drift as
`in-sync`, `ahead` or `behind`, comparing the latest release with `package.json`,
`Cargo.toml`, `pyproject.toml` or `VERSION`; cached for
`CUSTOM_STATUSLINE_PACKAGE_TTL_SECONDS` (600 s).

## Cache TTLs at a glance

| Segment | Env var | Default |
|---|---|---|
| Release | `CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS` | 300 s |
| Visibility | `CUSTOM_STATUSLINE_VISIBILITY_TTL_SECONDS` | 3600 s |
| Deployment | `CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS` | 180 s |
| Package | `CUSTOM_STATUSLINE_PACKAGE_TTL_SECONDS` | 600 s |

Cache files live under `CUSTOM_STATUSLINE_CACHE_DIR` (default
`~/.cache/custom-statusline`); delete that directory to force every network-backed
segment to re-fetch on the next render.
