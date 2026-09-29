# custom-statusline — maintainer notes

Invariants and decisions that aren't obvious from reading the code.

## Data source discipline

Every segment that CAN be answered from Claude Code's own stdin payload is —
session id, directory, model, cost/duration, and context-window usage are
all read straight off `stdin`, never estimated or recomputed. Only three
segments touch the network at all: release, deployment, package.

## `exit 0` is load-bearing

`scripts/statusline.sh` ends with an explicit `exit 0`. Without it, the
script's exit status is whatever the last `[[ -n "$LINE" ]] && printf ...`
happened to evaluate to — 1 whenever the final segment is empty, which is
the common case. A statusline command's own exit status must never depend
on which segment happened to render last.

## Malformed stdin is normalized once, at the top

`statusline.sh` validates the payload with `jq -e . >/dev/null` before
passing it to any segment. Skipping this means a malformed payload produces
a `jq: parse error` from every segment that reads it — one script-wide
check replaces N per-segment failures.

## GitHub Packages has no per-repository endpoint

There is no `GET /repos/{owner}/{repo}/packages`. Packages are scoped to an
org or a user account, and the user-scoped endpoint additionally requires an
explicit `package_type` query parameter — omitting it is a 422, not an empty
result. `fetch_owner_packages` tries the org endpoint first (a 404 there
just means the owner is a personal account), then loops over the known
package types against the user endpoint.

## Empty-array vs. absent-field in the GitHub API

`sort_by(.id) | last` on an empty JSON array (`[]`) is `null`, not an error —
and `null.id` is also `null`. A naive check for "was `.id` present" passes
even when the underlying list was empty, and the id `null` gets interpolated
into a follow-up request path as the literal string `"null"`. Every fetch
function that does this pattern (`segment-deployment.sh`,
`segment-package.sh`) checks `if . == null then empty else ... end`
explicitly rather than relying on field absence.

## No skills yet

This PR intentionally ships zero skills. The `build` skill that installs
this statusline (patches `settings.json`, backs up the previous config) is a
separate, stacked PR — this one is the engine only.
