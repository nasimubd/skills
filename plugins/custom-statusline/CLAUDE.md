# custom-statusline — maintainer notes

Invariants and decisions that aren't obvious from reading the code.

## Data source discipline

Every segment that CAN be answered from Claude Code's own stdin payload is —
session id, directory, model, effort, thinking and context-window usage are
all read straight off `stdin`, never recomputed. The one estimated value is
the compaction trigger (see below). Only the release, the visibility badge and
the optional deployment and package lines touch the network, and all of them
go through the TTL cache.

## The entrypoint assembles tested segments; it holds no logic of its own

`scripts/statusline.sh` sources `lib/runtime.sh` and the `lib/segment-*.sh` files and
prints one line per segment. A rewrite once replaced it with a standalone script that
sourced nothing: the nine segment libraries and their tests kept passing while no longer
being what ran, and the docs kept describing a design the entrypoint had abandoned. The
integration test now runs the real entrypoint and asserts every line, so that drift
fails a test instead of passing silently. New behaviour goes in a segment with a test,
not into the entrypoint.

## The compaction trigger is an estimate, in one function

Claude Code publishes no autocompact threshold. `context_compact_threshold` rebuilds it
from the public settings and from behaviour reported by others: the window minus a
20,000-token output reserve, firing 13,000 tokens before that (window - 33,000), moved
earlier but never later by `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`, with the window first capped
by `CLAUDE_CODE_AUTO_COMPACT_WINDOW`. None of it is documented, and users have reported
the override not firing at the configured value, so every figure derived from it carries a
`~`. Do not present it as fact, and when Claude Code's behaviour is better known, change
that one function and its test.

## Things left out on purpose

- **No cost, duration or lines-changed on the model line.** The line the user wanted
  carries id, effort and thinking only; `cost` and `cost.total_duration_ms` are in the
  payload if they are wanted back.
- **No terminal-recording line.** The reference line showed an iTerm session id for a
  recording folder; that is one person's tool, not something a public plugin ships.
- **The branch name appears only inside the URL** (`/tree/<branch>`, GitHub, and only off
  `main` and `master`). That is the reference line's behaviour. A repository with no remote
  therefore shows no branch.

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

## `gh` needs its PATH found for it — `jq`/`git` don't

Claude Code spawns the `statusLine` command with a minimal PATH, not the
interactive shell's. `jq` and `git` survive this because macOS ships them
system-wide (`/usr/bin`); `gh` does not — it lives only wherever Homebrew (or
Linuxbrew) put it. Without the PATH-hardening block at the top of
`lib/runtime.sh` (sourced by every segment), every segment that calls `gh` (release,
visibility, deployment, package) degrades to silently empty in the real, live environment even
though it works perfectly when tested from an interactive shell — which is
exactly why this shipped once already: it was tested, and worked, under a
normal shell's PATH. Reproduced by running the entrypoint under
`env -i HOME="$HOME" PATH="/usr/bin:/bin" ...`, not by reasoning about it.

This fix shipped once and was lost: the commit that rewrote `statusline.sh` for the
Codex footer replaced the whole file and dropped the PATH block, and the test that
guarded it kept passing because the release tag now comes from git, not `gh`. The
integration test therefore asserts the **visibility badge** (a segment that needs `gh`)
under `PATH=/usr/bin:/bin`, using a stub `gh` under a scratch `$HOME/.local/bin` so it
needs no network, no real `gh` and no Homebrew path. Disabling the PATH block makes two
assertions fail; that was checked by hand.

## macOS has no `timeout`

`probe_direct <seconds> <cmd>` (in `lib/runtime.sh`) runs through `with_timeout`, which uses `timeout`,
then `gtimeout`, then a background watchdog. The first version called `timeout`
directly; on macOS that is "command not found", so the visibility badge never
appeared even from an interactive shell with `gh` on the PATH, and the same mistake in
another status line surfaced as `gh exit 127`. Do not call `timeout` directly anywhere in
this plugin.

## Everything runs on bash 3.2

Claude Code starts the command with a minimal PATH, so `#!/usr/bin/env bash` can resolve to
macOS's stock bash 3.2. No associative arrays, no `mapfile`, no `${var,,}`. The integration
test runs the entrypoint under `/bin/bash` to keep that true. One 3.2 quirk bit a test: a
comma inside braces in a quoted `$(...)` is mangled, so build JSON payloads with `printf`.

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
