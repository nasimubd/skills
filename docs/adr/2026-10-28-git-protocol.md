# Enforce the git protocol locally, and merge pull requests by rebase

## Status

Current. Supersedes the merge method ("squash-merge only") in
[2026-09-29-open-source-and-branch-protection.md](./2026-09-29-open-source-and-branch-protection.md);
the rest of that record stands.

## Context and Problem Statement

The convention for commits and pull requests in this repository was written down
(`CONTRIBUTING.md`, the PR template) but nothing checked it: there was no commitlint, no
commit-msg hook and no check for AI attribution. Meanwhile practice had moved on. Pull
requests #9 to #11 were rebased and merged so that each Conventional Commit reached `main`
as written, while the documents still said squash. The user asked, on 2026-10-28, for the
convention actually in use to be enforced in this repository.

## Decision Drivers

- There is no CI by design (2026-09-29 ADR), so enforcement has to run locally.
- Every commit type releases and feeds the changelog; a squash collapses several meaningful
  commits into one subject.
- AI attribution must never reach a commit or PR (user rule), whatever a tool's default is.
- The automation repositories scaffolded by `automation-scaffold` already use this protocol
  (commitlint, a commit-msg hook, `pr:check`, rebase and merge); one protocol is easier to
  follow than two.

## Considered Options

- **Documentation only.** Rejected: an instruction can be skipped; a hook cannot.
- **Local enforcement: commitlint, a commit-msg hook and `mise run pr:check`.** Chosen.
- **Also restrict GitHub to rebase merges** (ruleset `allowed_merge_methods`, disabling
  squash in the repository settings). Deferred by the user on 2026-10-28; the ruleset still
  allows merge, squash and rebase, so the merge method is enforced by convention and by the
  documented `gh pr merge --rebase` step.

## Decision Outcome

- `commitlint.config.cjs`: Conventional Commits, header at most 72 characters, scopes read
  from `plugins/`, `skills/` and `codex-plugins/` plus a short list of repo scopes, and a
  `no-ai-attribution` rule backed by `scripts/no-ai-attribution.cjs`.
- `.githooks/commit-msg` runs commitlint on every commit; `mise run hooks:install` installs
  the dev dependencies and sets `core.hooksPath`.
- `mise run pr:check -- "<title>" <body-file>` checks the branch name, every commit since
  `origin/main`, the PR title and the PR body.
- Pull requests are merged with rebase and merge.
- `.mise/tasks/tests/test-git-protocol.sh` covers all of it and runs in the regression suite.

### Consequences

- Good: a non-conventional message or an attribution line fails at `git commit`, before it
  can reach GitHub.
- Good: release commits (`chore(release): x.y.z [skip ci]`) pass the same rules.
- Trade-off: a fresh clone must run `mise run hooks:install` once; until then the hook
  refuses commits and says so, rather than silently letting them through.
- Trade-off: the merge method is not enforced by GitHub while the ruleset allows squash.
