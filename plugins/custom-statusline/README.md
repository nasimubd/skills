# custom-statusline

Multi-line Claude Code status line driven by the statusline JSON payload plus GitHub-derived repository signals.

A cross-platform custom status line: Claude Code renders the reference template from its JSON payload, while Codex uses its native TUI footer
and a handful of GitHub-derived repository signals, paired with a
platform-neutral Agent Skill and native Codex footer adapter.

## What it shows

```
M:0 D:0 S:0 U:0 ↑:0 ↓:0 ≡:0 ⚠:0 | v1.5.0 tag 13h ago
claude-sonnet-5-5 · high · thinking:true
ctx ▕██████·······|≈≈≈≈≈≈≈▏ 30% · 60k/200k · ~71k until compact
Wed 11 Nov 2026 18:05 UTC | 13:05 EST
~/repo | https://github.com/owner/repo [public]
~/.claude/projects JSONL ID: 8bb6c049-5a75-40b9-b6f3-b72d77879486
```

| Line | Content | Source |
|---|---|---|
| 1 | Git indicators (modified, deleted, staged, untracked, ahead, behind, stashes, conflicts), then the latest release and its age | local `git`, `gh api` |
| 2 | Model id, reasoning effort, thinking | stdin payload |
| 3 | Context bar that marks where automatic compaction fires, with the room left | stdin payload (trigger estimated) |
| 4 | UTC date and time, then local time | system clock |
| 5 | Directory, repository URL (the branch when off main), public or private | payload, `git`, `gh api` |
| 6 | Transcript folder and session id, ready to paste into a prompt | stdin payload |

A line with nothing to show is left out, never replaced by an error. Anything Claude
Code already hands the script on stdin is read from there. Only the release and the
visibility badge touch the network, through a shared TTL cache, so the line does not call
`gh api` on every render. Two more network-backed lines, deployment and package status,
are off by default; see `CUSTOM_STATUSLINE_EXTRAS`.

The compaction trigger on line 3 is an **estimate**: Claude Code publishes no threshold,
so it is rebuilt from the public settings, and every figure derived from it carries a `~`.
See [the segment reference](./skills/install/references/segments.md).

## Configuration

| Variable | Default | Effect |
|---|---|---|
| `NO_COLOR` | unset | Any value turns colour off |
| `CUSTOM_STATUSLINE_EXTRAS` | empty | `deployment`, `package` or both, comma separated: extra network-backed lines |
| `CUSTOM_STATUSLINE_CLOCK_TZ` | system zone | IANA zone for the second time on line 4 |
| `CUSTOM_STATUSLINE_CACHE_DIR` | `~/.cache/custom-statusline` | Where cached API responses live |
| `CUSTOM_STATUSLINE_RELEASE_TTL_SECONDS` | `300` | Release cache lifetime |
| `CUSTOM_STATUSLINE_VISIBILITY_TTL_SECONDS` | `3600` | Public/private badge cache lifetime |
| `CUSTOM_STATUSLINE_DEPLOYMENT_TTL_SECONDS` | `180` | Deployment/workflow-run cache lifetime |
| `CUSTOM_STATUSLINE_PACKAGE_TTL_SECONDS` | `600` | Package-lookup cache lifetime |
| `CUSTOM_STATUSLINE_DIRECTORY_MAX_CHARS` | `40` | Directory truncation width |
| `CUSTOM_STATUSLINE_CONTEXT_BAR_WIDTH` | `20` | Context bar width in cells |
| `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` | unset | Read, not set: your Claude Code compaction setting, used for the estimate |
| `CLAUDE_CODE_AUTO_COMPACT_WINDOW` | unset | Read, not set: your Claude Code window cap, used for the estimate |

Network-backed segments never error and never hang: a missing scope, a 404, no `gh`, or no
network just means that piece is left out. The status line only redraws when Claude Code
does; to keep the clock current while a session is idle, add `"refreshInterval": 60` to the
`statusLine` setting after installing.

## Installing it

Run `/custom-statusline:install` in Claude Code, or directly:

```bash
bash plugins/custom-statusline/scripts/install.sh install
```

This backs up any existing `statusLine` configuration in
`~/.claude/settings.json` before pointing it at this plugin. See
`skills/install/SKILL.md` for the full walkthrough, including how to check
status, customize which segments render, and uninstall.

Codex uses its native TUI footer rather than Claude Code's command-backed `statusLine`; it supports the closest equivalent built-in items (directory, branch, model, and context). The shared skill is available at `../../skills/custom-statusline/`
and is linked into `.agents/skills/` for repository-local Codex discovery.
