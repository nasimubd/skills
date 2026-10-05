# Codex status-line adapter

Codex stores its native footer configuration under `tui.status_line` in
`~/.codex/config.toml`. The supported UI flow is `/statusline`, which lets a
user toggle and reorder items interactively.

The repository installer uses these native identifiers:

```toml
[tui]
status_line = [
  "current-dir",
  "git-branch",
  "model-with-reasoning",
  "context-used",
]
```

Codex's available item set can change. If Codex reports an ignored item, run
`/statusline` in Codex and use the picker to select the current names, then
update the adapter and its tests based on that observed behavior.

The native footer cannot execute the Claude renderer or show arbitrary GitHub URL, release, stash, and visibility segments. The adapter selects the closest supported built-in items and preserves their order.
