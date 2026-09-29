# Segment reference

What each of the 8 lines in `scripts/statusline.sh` shows, where its data
comes from, and what it needs to render.

## Session (line 1)

`session_id` (shortened to its first 8 characters) plus `session_name` if
the payload carries one. Straight off stdin — no network, no git.
