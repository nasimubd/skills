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
