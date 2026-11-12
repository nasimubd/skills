#!/usr/bin/env bash
# test-git-protocol.sh — the repository's git protocol (.claude/rules/git.md): commitlint
# rules, the AI-attribution check, the commit-msg hook and `mise run pr:check`. Offline:
# pr:check runs in a throwaway clone whose origin is this repository.
#
# Needs the dev dependencies (`mise run hooks:install`); without them it fails, because a
# protocol that cannot run is not enforced.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
CL="$ROOT/node_modules/.bin/commitlint"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0 FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }
accepts() { if printf '%s\n' "$2" | (cd "$ROOT" && "$CL") >/dev/null 2>&1; then ok; else bad "should accept: $1"; fi; }
rejects() { if printf '%s\n' "$2" | (cd "$ROOT" && "$CL") >/dev/null 2>&1; then bad "should reject: $1"; else ok; fi; }

if [[ ! -x "$CL" ]]; then
  echo "  ✗ commitlint not installed (mise run hooks:install)"
  echo "test-git-protocol.sh: 0 passed, 1 failed"
  exit 1
fi

# ---- commitlint ----
accepts "a plugin scope" "fix(teams-commander): open chats in the Teams app"
accepts "a platform-neutral skill scope" "docs(logo-design-agency): fix a link"
accepts "a repo scope" "chore(deps): add commitlint"
accepts "no scope" "docs: record the git protocol"
accepts "the release commit" "chore(release): 1.4.0 [skip ci]"
accepts "a breaking change" "feat(automation-scaffold)!: rename the publish phases"
rejects "an unknown scope" "fix(not-a-plugin): something"
rejects "a non-conventional header" "Update the README"
rejects "an unknown type" "update(repo): something"
rejects "a header over 72 characters" "fix(automation-scaffold): $(printf 'x%.0s' {1..60})"
rejects "a Co-Authored-By AI trailer" $'fix(repo): something\n\nCo-Authored-By: Claude <noreply@anthropic.com>'
rejects "a Generated-with line" $'fix(repo): something\n\nGenerated with Claude Code'
accepts "a body that mentions .claude/rules" $'docs(repo): link the rules\n\nSee .claude/rules/git.md.'

# ---- attribution check on a PR body ----
printf 'Summary\n\n🤖 Generated with [Claude Code](https://claude.com/claude-code)\n' >"$WORK/body-bad"
printf 'Summary\n\nTests pass.\n' >"$WORK/body-ok"
node "$ROOT/scripts/no-ai-attribution.cjs" <"$WORK/body-bad" 2>/dev/null && bad "PR body with attribution should fail" || ok
node "$ROOT/scripts/no-ai-attribution.cjs" <"$WORK/body-ok" && ok || bad "a clean PR body should pass"

# ---- commit-msg hook ----
printf 'Update stuff\n' >"$WORK/msg-bad"
printf 'fix(repo): enforce the protocol\n' >"$WORK/msg-ok"
GOOD_ID=(env GIT_AUTHOR_NAME=Test GIT_AUTHOR_EMAIL=test@example.com GIT_COMMITTER_NAME=Test GIT_COMMITTER_EMAIL=test@example.com)
(cd "$ROOT" && "${GOOD_ID[@]}" .githooks/commit-msg "$WORK/msg-bad") >/dev/null 2>&1 && bad "hook should reject a bad message" || ok
(cd "$ROOT" && "${GOOD_ID[@]}" .githooks/commit-msg "$WORK/msg-ok") >/dev/null 2>&1 && ok || bad "hook should accept a good message"

# ---- commit identity (scripts/commit-identity.cjs) ----
id_ok() { if printf '%s\n' "$2" | node "$ROOT/scripts/commit-identity.cjs" --stdin >/dev/null 2>&1; then ok; else bad "identity should be accepted: $1"; fi; }
id_bad() { if printf '%s\n' "$2" | node "$ROOT/scripts/commit-identity.cjs" --stdin >/dev/null 2>&1; then bad "identity should be rejected: $1"; else ok; fi; }
id_ok "a GitHub no-reply address" "someone <1234+someone@users.noreply.github.com>"
id_ok "an ordinary address" "Test Person <test@example.com>"
id_ok "the release bot" "semantic-release-bot <semantic-release-bot@users.noreply.github.com>"
id_ok "GitHub's web committer" "GitHub <noreply@github.com>"
id_ok "a name with a pipe is the person's choice" "A | B <a@example.com>"
id_bad "an IPv4 address (the original leak)" "Go2 <Go2@192.168.1.108>"
id_bad "a bracketed IP" "X <x@[10.0.0.1]>"
id_bad "an IPv6 address" "X <x@fe80::1>"
id_bad "a .local host name" "X <x@Someones-MacBook-Pro.local>"
id_bad "a .lan host name" "X <x@router.lan>"
id_bad "a .home.arpa host name" "X <x@nas.home.arpa>"
id_bad "a bare host name" "X <x@somehost>"
id_bad "localhost" "X <x@localhost>"
id_bad "an empty name" " <x@example.com>"
id_bad "not an email" "X <not-an-email>"
id_bad "no angle brackets" "just a name"
printf 'A <a@example.com>\nB <b@192.168.0.1>\n' | node "$ROOT/scripts/commit-identity.cjs" --stdin >"$WORK/id.out" 2>&1 && bad "one bad line among good ones should fail" || { grep -q '192.168.0.1' "$WORK/id.out" && ok || bad "the message should name the bad identity"; }
grep -q 'users.noreply.github.com' "$WORK/id.out" && ok || bad "the message should say how to fix it"

# The hook refuses a machine-derived identity before reading the message.
BAD_ID=(env GIT_AUTHOR_NAME=Go2 GIT_AUTHOR_EMAIL=Go2@192.168.1.5 GIT_COMMITTER_NAME=Go2 GIT_COMMITTER_EMAIL=Go2@192.168.1.5)
(cd "$ROOT" && "${BAD_ID[@]}" .githooks/commit-msg "$WORK/msg-ok") >/dev/null 2>&1 && bad "hook should reject a machine-derived identity" || ok

# The root cause: with no identity configured, git must refuse to guess one.
NOID="$WORK/noid"
git init -q "$NOID"
git -C "$NOID" config user.useConfigOnly true
if (cd "$NOID" && HOME="$WORK/empty-home" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null git commit -q --allow-empty -m "chore(repo): guess me" >/dev/null 2>&1); then
  bad "useConfigOnly should make git refuse to commit without an identity"
else
  ok
fi
[[ -z "$(git -C "$NOID" rev-list --all 2>/dev/null)" ]] && ok || bad "no commit should have been created without an identity"

# ---- pr:check in a throwaway clone ----
C="$WORK/clone"
git clone -q --no-hardlinks "$ROOT" "$C"
ln -s "$ROOT/node_modules" "$C/node_modules"
# The clone gets this working tree's protocol files, so the test covers uncommitted changes.
for f in commitlint.config.cjs scripts/no-ai-attribution.cjs scripts/commit-identity.cjs .mise/tasks/pr/check; do mkdir -p "$C/$(dirname "$f")"; cp "$ROOT/$f" "$C/$f"; done
G=(git -C "$C" -c user.name=Test -c user.email=test@example.com -c core.hooksPath=/dev/null)
"${G[@]}" add -A && "${G[@]}" commit -q -m "chore(repo): bring the protocol files into the test clone"
# The clone is its own origin, so `pr:check`'s `git fetch origin main` works offline.
# checkout -B, not branch -f: the clone is on whatever branch this repository is on, often
# main itself, and git refuses to force-move the branch that is checked out.
git -C "$C" checkout -q -B main
git -C "$C" update-ref refs/remotes/origin/main HEAD
git -C "$C" config remote.origin.url "$C"
prcheck() { (cd "$C" && MISE_PROJECT_ROOT="$C" bash .mise/tasks/pr/check "$@") >"$WORK/pr.out" 2>&1; }

git -C "$C" checkout -q -b fix/protocol-test
echo x >"$C/x.txt" && "${G[@]}" add x.txt && "${G[@]}" commit -q -m "fix(repo): a conventional commit"
prcheck "fix(repo): a conventional title" "$WORK/body-ok" && ok || { bad "pr:check should pass a clean branch"; cat "$WORK/pr.out"; }
prcheck "Fix stuff" "$WORK/body-ok" && bad "pr:check should reject a non-conventional title" || ok
prcheck "fix(repo): a conventional title" "$WORK/body-bad" && bad "pr:check should reject attribution in the body" || ok
prcheck && bad "pr:check should require the PR title" || ok

# A commit authored from a machine-derived identity fails pr:check, then is dropped again.
git -C "$C" -c user.name=Go2 -c user.email=Go2@192.168.1.5 -c core.hooksPath=/dev/null commit -q --allow-empty -m "fix(repo): from a guessed identity"
prcheck "fix(repo): a conventional title" "$WORK/body-ok" && bad "pr:check should reject a machine-derived identity" || { grep -q '192.168.1.5' "$WORK/pr.out" && ok || bad "pr:check should name the bad identity"; }
git -C "$C" reset -q --hard HEAD~1
prcheck "fix(repo): a conventional title" "$WORK/body-ok" && ok || { bad "pr:check should pass again once the bad commit is gone"; cat "$WORK/pr.out"; }

"${G[@]}" commit -q --allow-empty -m $'fix(repo): another\n\nCo-Authored-By: Claude <noreply@anthropic.com>'
prcheck "fix(repo): a conventional title" "$WORK/body-ok" && bad "pr:check should reject attribution in a commit" || ok

git -C "$C" checkout -q -b wip-branch
prcheck "fix(repo): a conventional title" && bad "pr:check should reject a branch not named <type>/<slug>" || ok

echo "test-git-protocol.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
