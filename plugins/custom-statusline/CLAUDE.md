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

## The skill is named `install`, not `build`

`skills/build/` collides with the root `.gitignore`'s generic `build/` rule
(it ignores a directory named `build` at any depth, not just at the repo
root) — the directory silently refused to be tracked. `install` sidesteps
the collision and is also the more accurate verb per the hub CLAUDE.md's own
glossary: this skill acquires and wires up a configuration, it doesn't
construct anything.

## `latest_backup_path` uses a nullglob array, never `ls | head`

`ls -1t "$pattern" | head -1` looks equivalent but isn't under
`set -o pipefail`: when the glob matches nothing, `ls` exits non-zero (even
with stderr redirected away) while `head` still exits zero, and pipefail
makes the PIPELINE's status the rightmost non-zero code — `ls`'s failure,
not `head`'s success. Under `set -e` that silently kills `run_uninstall`
before it prints anything, with no error message, the moment there's no
backup to find. Caught by actually running uninstall with zero backups
present, not by reading the code. Fixed with `shopt -s nullglob` + an array,
which expands to zero elements on no match instead of failing.

## The release-segment test asserts a pattern, not a frozen tag

`test-segment-release.sh`'s "real repo" case calls `segment_release` against
this repo's own `owner/name` to prove the live fetch path works end to end.
Its expected value must be a semver pattern (`^v[0-9]+\.[0-9]+\.[0-9]+$`),
never a literal tag — this repo's own latest release changes every time a
release ships, so a literal breaks on the very next release. Caught when
`v1.1.0` broke a test written against `v1.0.0`.

## Backup happens before the fresh-install stub is written

`run_install` backs up `$SETTINGS_FILE` before deciding whether to create an
empty `{}` stub for a first-time install. Backing up after would back up the
stub it had just created and report it as a "previous config" that never
existed.

## Malformed existing `settings.json` self-heals rather than crashes

If `$SETTINGS_FILE` exists but isn't valid JSON, `run_install` backs it up
(preserving the original) and restarts the patch from `{}`, instead of
letting `jq`'s raw parse error propagate through `set -e`.
