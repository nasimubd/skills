#!/usr/bin/env bash
# Run before opening or merging a PR (there is no CI): the component registry, every commit
# on the branch, the PR title, and the PR body when given.
#
#   mise run pr:check -- "<PR title>" [<file with the PR body>]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CL="$ROOT/node_modules/.bin/commitlint"
[[ -x "$CL" ]] || { echo "error: commitlint not installed; run mise run setup" >&2; exit 127; }

node "$ROOT/scripts/check-components.js"
git -C "$ROOT" fetch -q origin
"$CL" --from origin/main --to HEAD --verbose

if [[ -n "${1:-}" ]]; then printf '%s\n' "$1" | "$CL" --verbose; else echo "note: pass the PR title to check it too"; fi

# No AI attribution anywhere in the PR (CLAUDE.md, .claude/rules/git.md).
if [[ -n "${2:-}" ]]; then
  if node "$ROOT/scripts/no-ai-attribution.js" <"$2"; then
    echo "✓ PR body carries no AI attribution"
  else
    exit 1
  fi
fi
