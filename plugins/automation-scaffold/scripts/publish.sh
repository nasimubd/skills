#!/usr/bin/env bash
# publish.sh — the git protocol for a scaffolded repository, in three phases.
#
#   publish.sh repo    --repo <owner/name> --dir <path> [--description D] [--yes]
#       Use the GitHub repository if it exists (clone it into --dir when needed), otherwise
#       create it private and clone it. An empty repository gets one initial commit on main
#       (`chore(repo): initialize repository`) so a PR has a base.
#
#   publish.sh pr      --dir <path> [--yes]
#       Branch from origin/main, install dev dependencies, commit in convention order
#       (repo scaffold, one commit per component, docs), run `mise run pr:check` with the PR
#       title and body, push, open the PR, rebase-and-merge it, and sync main.
#
#   publish.sh about   --dir <path> [--yes | --check]
#       Set the GitHub repository's About from project.json `github`: the description when
#       GitHub's is empty (an existing one is kept and reported), and every listed topic
#       (topics are only added). The repository is project.json `github.repo` or the clone's
#       origin. Run by `pr` after the merge. `--check` changes nothing and exits 1 unless
#       the description is set and every listed topic is present.
#
#   publish.sh release --dir <path> [--yes]
#       On the synced main: `mise run release:dry`, `mise run release`, then verify: registry,
#       one v1.0.0 tag and GitHub Release per pinned component, production vs pins, and no AI
#       attribution anywhere in the history.
#
# Without --yes every phase prints what it would do and changes nothing.
# Commits are authored with config.author (setup skill); nothing carries AI attribution.
#
# EXIT CODES: 0 ok · 1 failure · 2 usage · 3 refused (precondition not met)

set -euo pipefail

readonly SELF="publish.sh"
readonly CONFIG="${AUTOMATION_SCAFFOLD_CONFIG_DIR:-$HOME/.config/automation-scaffold}/config.json"

die() { echo "$SELF: $1" >&2; exit "${2:-1}"; }
usage() { die "usage: $1" 2; }
say() { echo "• $*"; }

phase="${1:-}"; shift || true
repo="" dir="" description="" yes=false check=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) repo="$2"; shift 2 ;;
    --dir) dir="$2"; shift 2 ;;
    --description) description="$2"; shift 2 ;;
    --yes) yes=true; shift ;;
    --check) check=true; shift ;;
    *) usage "unknown option '$1'" ;;
  esac
done
[[ -n "$dir" ]] || usage "$SELF repo|pr|about|release --dir <path> ..."

[[ -f "$CONFIG" ]] || die "no config at $CONFIG (run the setup skill)" 3
author_name="$(jq -r '.author.name // empty' "$CONFIG")"
author_email="$(jq -r '.author.email // empty' "$CONFIG")"
[[ -n "$author_name" && -n "$author_email" ]] || die "config.author.name and .email are required (setup skill)" 3
# The env pins win over GIT_AUTHOR_*/GIT_COMMITTER_* inherited from the caller (semantic-release
# exports them), which would otherwise override user.name/user.email.
GIT=(env GIT_AUTHOR_NAME="$author_name" GIT_AUTHOR_EMAIL="$author_email"
  GIT_COMMITTER_NAME="$author_name" GIT_COMMITTER_EMAIL="$author_email"
  git -c "user.name=$author_name" -c "user.email=$author_email")

# Run a step, or only print it without --yes.
step() {
  if $yes; then "$@"; else printf '  would run: %s\n' "$*"; fi
}

assert_no_attribution() {
  local text="$1" where="$2"
  if ! node "$dir/scripts/no-ai-attribution.js" <<<"$text"; then die "AI attribution found in $where" 3; fi
}

phase_repo() {
  [[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || usage "--repo owner/name"
  if gh repo view "$repo" --json name >/dev/null 2>&1; then
    say "GitHub repository $repo exists; it will be used as is."
    if [[ -d "$dir/.git" ]]; then
      local origin
      origin="$(git -C "$dir" remote get-url origin 2>/dev/null || true)"
      [[ "$origin" == *"$repo"* || "$origin" == *"${repo}.git"* ]] || die "$dir is a git repo whose origin ($origin) is not $repo" 3
    elif [[ -e "$dir" && -n "$(ls -A "$dir" 2>/dev/null)" ]]; then
      die "$dir exists and is not a clone of $repo; choose an empty --dir" 3
    else
      step gh repo clone "$repo" "$dir"
    fi
  else
    say "GitHub repository $repo does not exist; it will be created private."
    [[ ! -e "$dir" || -z "$(ls -A "$dir" 2>/dev/null)" ]] || die "$dir is not empty; choose an empty --dir for a new repository" 3
    step gh repo create "$repo" --private ${description:+--description "$description"}
    step gh repo clone "$repo" "$dir"
  fi
  $yes || return 0
  if ! git -C "$dir" rev-parse --verify -q origin/main >/dev/null && [[ -z "$(git -C "$dir" log --oneline -1 2>/dev/null)" ]]; then
    # An empty commit: a PR needs a base, and any file committed here (a stub README) would
    # be kept by the scaffold, which never overwrites, instead of the real one.
    say "Empty repository: creating an empty initial commit on main."
    git -C "$dir" checkout -q -B main
    "${GIT[@]}" -C "$dir" commit -q --allow-empty -m "chore(repo): initialize repository"
    git -C "$dir" push -q -u origin main
  fi
  say "Repository ready: $dir ($(git -C "$dir" remote get-url origin))"
}

# Paths of every registered component, one per line.
component_paths() { jq -r '.components[].path' "$dir/releases/components.json"; }

phase_pr() {
  [[ -f "$dir/releases/components.json" ]] || die "$dir is not scaffolded yet (run scaffold.js first)" 3
  local name branch title body
  name="$(jq -r '.name' "$dir/project.json")"
  branch="chore/scaffold-$(date -u +%Y%m%d%H%M)"
  title="chore(repo): scaffold ${name} with release convention"
  body="$(mktemp)"
  {
    echo "## Summary"
    echo
    echo "Scaffolds this repository with the automation release convention:"
    echo
    echo "- per-component releases (semantic-release-monorepo), production pins, \`mise\` tasks"
    echo "- Conventional Commits enforced by commitlint and a commit-msg hook; rebase-and-merge PRs"
    echo "- no AI attribution, enforced by the hook and \`mise run pr:check\`"
    echo "- \`docs/architecture.md\`: every discovered link with its evidence"
    echo
    echo "## Components"
    echo
    jq -r '.components[] | "- `\(.id)`: \(.displayName) (`\(.path)`)"' "$dir/releases/components.json"
    echo
    echo "Each component's source was exported read-only from production and pinned; its first"
    echo "release (v1.0.0) is cut after this PR is merged."
  } >"$body"

  say "PR title: $title"
  $yes || { say "PR body:"; sed 's/^/    /' "$body"; }

  step git -C "$dir" fetch -q origin
  step git -C "$dir" checkout -q -B "$branch" origin/main
  step bash -c "cd '$dir' && npm install --no-audit --no-fund --loglevel=error"
  step git -C "$dir" config core.hooksPath .githooks

  if $yes; then
    # 1. Everything that is not a component folder or a generated document.
    local exclude=(':!docs/architecture.md' ':!docs/environment.md' ':!docs/decisions.md')
    while IFS= read -r p; do exclude+=(":!$p"); done < <(component_paths)
    git -C "$dir" add -A -- . "${exclude[@]}"
    "${GIT[@]}" -C "$dir" commit -q -m "chore(repo): scaffold repository and release convention" \
      -m "Per-component releases with production pins, Conventional Commits checked by commitlint and a commit-msg hook, rebase-and-merge PRs, and no AI attribution. See docs/RELEASE.md and .claude/rules/git.md."
    # 2. One commit per component.
    while IFS=$'\t' read -r id p dn; do
      git -C "$dir" add -A -- "$p"
      if ! git -C "$dir" diff --cached --quiet; then
        # commitlint caps the header at 72 characters; a long name moves to the body.
        local subject="feat($id): add $dn from production"
        (( ${#subject} <= 72 )) || subject="feat($id): add from production"
        (( ${#subject} <= 72 )) || die "component id $id is too long for a 72-character commit header" 3
        "${GIT[@]}" -C "$dir" commit -q -m "$subject" \
          -m "Adds $dn. Source exported read-only from production and pinned in release.lock.json."
      fi
    done < <(jq -r '.components[] | "\(.id)\t\(.path)\t\(.displayName)"' "$dir/releases/components.json")
    # 3. Generated documentation.
    git -C "$dir" add -A -- docs
    git -C "$dir" diff --cached --quiet || "${GIT[@]}" -C "$dir" commit -q -m "docs: document architecture, environment and decisions" \
      -m "Architecture links come from the read-only discovery, each with its evidence."
    [[ -z "$(git -C "$dir" status --porcelain)" ]] || die "uncommitted files remain after the scaffold commits: $(git -C "$dir" status --porcelain | head -5)"

    assert_no_attribution "$(git -C "$dir" log --format=%B origin/main..HEAD)" "branch commits"
    assert_no_attribution "$title"$'\n'"$(cat "$body")" "PR title or body"
    (cd "$dir" && mise trust -q mise.toml && mise run pr:check -- "$title" "$body")
    git -C "$dir" push -q -u origin "$branch"
    local url number
    url="$(cd "$dir" && gh pr create --base main --head "$branch" --title "$title" --body-file "$body")"
    number="${url##*/}"
    say "Opened PR #$number: $url"
    (cd "$dir" && gh pr merge "$number" --rebase --delete-branch >/dev/null)
    git -C "$dir" checkout -q main
    git -C "$dir" pull -q --ff-only origin main
    [[ "$(cd "$dir" && gh pr view "$number" --json state -q .state)" == "MERGED" ]] || die "PR #$number did not merge"
    say "PR #$number rebased and merged; main is at $(git -C "$dir" log --oneline -1)"
    phase_about
  else
    say "would commit: chore(repo) scaffold · one feat(<id>) per component · docs"
    say "would run: mise run pr:check -- \"$title\" <body>, push $branch, gh pr create, gh pr merge --rebase --delete-branch"
    say "would then set the repository's About (publish about): description and topics from project.json"
  fi
  rm -f "$body"
}

# owner/name of the repository: the one recorded at scaffold time, else the clone's origin.
repo_of_dir() {
  local r
  r="$(jq -r '.github.repo // empty' "$dir/project.json")"
  [[ -n "$r" ]] || r="$(cd "$dir" && gh repo view --json nameWithOwner -q .nameWithOwner)"
  printf '%s' "$r"
}

phase_about() {
  [[ -f "$dir/project.json" ]] || die "$dir is not scaffolded yet (run scaffold.js first)" 3
  local r want current topics missing=()
  r="$(repo_of_dir)"
  [[ -n "$r" ]] || die "cannot tell which GitHub repository $dir belongs to" 3
  if $check; then
    if verify_about; then say "About of $r: description and every topic set"; return 0; fi
    say "About of $r: description empty or a topic missing"; return 1
  fi
  want="$(jq -r '.github.description // empty' "$dir/project.json")"
  current="$(gh repo view "$r" --json description -q '.description // ""')"
  topics="$(gh repo view "$r" --json repositoryTopics -q '[.repositoryTopics[]?.name] | join(" ")')"
  while IFS= read -r t; do [[ -n "$t" && " $topics " != *" $t "* ]] && missing+=("$t"); done \
    < <(jq -r '.github.topics[]? // empty' "$dir/project.json")
  local args=()
  if [[ -z "$current" && -n "$want" ]]; then args+=(--description "$want"); say "description: $want"
  elif [[ -n "$current" && "$current" != "$want" ]]; then say "description kept (already set on GitHub): $current"
  fi
  local t
  for t in ${missing[@]+"${missing[@]}"}; do args+=(--add-topic "$t"); done
  (( ${#missing[@]} )) && say "topics to add: ${missing[*]}"
  if (( ${#args[@]} )); then step gh repo edit "$r" ${args[@]+"${args[@]}"}; else say "About of $r already up to date"; fi
}

# The About is set: a description, and every topic project.json lists.
verify_about() {
  local r
  r="$(repo_of_dir)"
  gh repo view "$r" --json description,repositoryTopics | jq -e --slurpfile p "$dir/project.json" \
    '(.description // "") != "" and (([$p[0].github.topics[]?] - [.repositoryTopics[]?.name]) | length == 0)' >/dev/null
}

phase_release() {
  [[ -f "$dir/releases/components.json" ]] || die "$dir is not scaffolded" 3
  if ! $yes; then
    say "would run on main: mise run release:dry, mise run release, then verify tags, releases, pins and history"
    return 0
  fi
  git -C "$dir" fetch -q origin
  [[ "$(git -C "$dir" rev-parse --abbrev-ref HEAD)" == "main" ]] || die "release runs from main" 3
  [[ "$(git -C "$dir" rev-parse HEAD)" == "$(git -C "$dir" rev-parse origin/main)" ]] || die "main is not in sync with origin/main" 3
  (cd "$dir" && mise trust -q mise.toml && mise run release:dry && mise run release)
  git -C "$dir" pull -q --ff-only origin main
  git -C "$dir" fetch -q --tags origin

  echo "== verification"
  local fails=0 checked=0
  (cd "$dir" && node scripts/check-components.js) || fails=$((fails + 1))
  while IFS=$'\t' read -r id p; do
    checked=$((checked + 1))
    if [[ ! -f "$dir/$p/release.lock.json" ]]; then echo "  - $id: no pin, so not released (expected)"; continue; fi
    local tag
    tag="$(git -C "$dir" tag -l "${id}-v*" --sort=-v:refname | head -1)"
    if [[ -z "$tag" ]]; then echo "  ✗ $id: no release tag"; fails=$((fails + 1)); continue; fi
    if (cd "$dir" && gh release view "$tag" --json tagName >/dev/null 2>&1); then echo "  ✓ $id: $tag with GitHub Release"; else echo "  ✗ $id: $tag has no GitHub Release"; fails=$((fails + 1)); fi
  done < <(jq -r '.components[] | "\(.id)\t\(.path)"' "$dir/releases/components.json")
  if verify_about; then echo "  ✓ repository About has a description and every topic"; else echo "  ✗ repository About is missing its description or a topic (publish about)"; fails=$((fails + 1)); fi
  if (cd "$dir" && node scripts/release-pin.js verify); then echo "  ✓ production matches every pin"; else echo "  ✗ production differs from a pin"; fails=$((fails + 1)); fi
  if node "$dir/scripts/no-ai-attribution.js" <<<"$(git -C "$dir" log --format='%an <%ae>%n%cn <%ce>%n%B' origin/main)"; then echo "  ✓ no AI attribution in history"; else fails=$((fails + 1)); fi
  echo "Components checked: $checked · problems: $fails"
  [[ "$fails" -eq 0 ]]
}

case "$phase" in
  repo) phase_repo ;;
  pr) phase_pr ;;
  release) phase_release ;;
  about) phase_about ;;
  *) usage "$SELF repo|pr|about|release --dir <path> [--repo owner/name] [--yes]" ;;
esac
