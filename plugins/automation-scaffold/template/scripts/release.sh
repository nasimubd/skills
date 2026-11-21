#!/usr/bin/env bash
# Release every component in releases/components.json, one at a time (docs/RELEASE.md).
# Each run sees only the commits that touched that component's folder and pushes its own
# release commit and tag before the next starts.
#
# A component is released only when its pin (release.lock.json) matches its committed
# source, so a tag always names what is live. Changes merged but not yet deployed and
# re-pinned are skipped and released together once they are.
#
#   mise run release:dry   preview; no tags, commits or pushes
#   mise run release       cut the releases: tags, CHANGELOG commits, GitHub Releases
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SR="$ROOT/node_modules/.bin/semantic-release"
[[ -x "$SR" ]] || { echo "error: semantic-release not installed; run mise run setup" >&2; exit 127; }

# The token comes from the gh login and is never stored.
if [[ -z "${GITHUB_TOKEN:-}" ]]; then GITHUB_TOKEN="$(gh auth token)"; export GITHUB_TOKEN; fi

# A real release pushes to main, so it runs only from a clean main that matches origin/main.
if [[ " $* " != *" --dry-run "* ]]; then
  git -C "$ROOT" fetch -q origin
  [[ "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)" == "main" ]] || { echo "error: release from main" >&2; exit 1; }
  [[ -z "$(git -C "$ROOT" status --porcelain)" ]] || { echo "error: working tree not clean" >&2; exit 1; }
  [[ "$(git -C "$ROOT" rev-parse HEAD)" == "$(git -C "$ROOT" rev-parse origin/main)" ]] \
    || { echo "error: main is not in sync with origin/main" >&2; exit 1; }
fi

node "$ROOT/scripts/check-components.js"

count=0
released_or_checked=0
while IFS=$'\t' read -r id path; do
  [[ -z "$id" ]] && continue
  count=$((count + 1))
  echo "== $id ($path)"
  if ! node "$ROOT/scripts/release-pin.js" check "$id"; then
    echo "skipped: $id is not released until its pin matches its source"
    continue
  fi
  (cd "$ROOT/$path" && "$SR" "$@")
  released_or_checked=$((released_or_checked + 1))
done < <(jq -r '.components[] | "\(.id)\t\(.path)"' "$ROOT/releases/components.json")

echo "Components: $count · run through semantic-release: $released_or_checked · skipped: $((count - released_or_checked))"
