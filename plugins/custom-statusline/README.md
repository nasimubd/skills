# custom-statusline

A multi-line Claude Code status line built from the statusline JSON payload
and a handful of GitHub-derived repository signals.

## What it shows

| Line | Content | Source |
|---|---|---|
| 1 | Session id + directory | stdin payload |
| 2 | Git branch, dirty state, ahead/behind + latest release tag | local `git` + `gh api` |
| 3 | Context-window usage bar | stdin payload |
| 4 | Deployment status and/or package status (omitted if neither exists) | `gh api` |
| 5 | Model name, session duration/cost, lines changed | stdin payload |

Everything that Claude Code already hands the statusline script on stdin is
read from there directly — no estimation, no extra computation. Only the
release, deployment, and package signals touch the network, and all three
go through a shared TTL file cache so the statusline doesn't make a live
`gh api` call on every render.

## Configuration

| Variable | Default | Effect |
|---|---|---|
| `CUSTOM_STATUSLINE_CACHE_DIR` | `~/.cache/custom-statusline` | Where cached API responses live |
| `CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS` | `300` | Release-tag cache lifetime |
| `CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS` | `180` | Deployment/workflow-run cache lifetime |
| `CUSTOM_STATUSLINE_PACKAGE_TTL_SECONDS` | `600` | Package-lookup cache lifetime |
| `CUSTOM_STATUSLINE_DIRECTORY_MAX_CHARS` | `40` | Directory segment truncation width |
| `CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH` | `10` | Context-usage bar width in characters |

Network-touching segments never error and never hang: a missing scope, a
404, or no network at all just means that piece is omitted.

## Installing it

Run `/custom-statusline:install` in Claude Code, or directly:

```bash
bash plugins/custom-statusline/scripts/install.sh install
```

This backs up any existing `statusLine` configuration in
`~/.claude/settings.json` before pointing it at this plugin. See
`skills/install/SKILL.md` for the full walkthrough, including how to check
status, customize which segments render, and uninstall.
