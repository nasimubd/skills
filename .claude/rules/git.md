# Git protocol (on demand)

Applies to every commit, branch, PR, merge and release in this repository. Enforced locally
by the commit-msg hook (`.githooks/commit-msg`, installed by `mise run hooks:install`) and by
`mise run pr:check`; on GitHub, the "Protect main" ruleset requires a PR and linear history.
There is no CI, so the local checks are the gate. Decision record:
[docs/adr/2026-10-28-git-protocol.md](../../docs/adr/2026-10-28-git-protocol.md).

## No AI attribution

Never add, in any commit message, PR title, PR body, merge, tag or release note:

- a `Co-Authored-By:` trailer naming an AI assistant (Claude, Anthropic, Copilot, ChatGPT,
  Gemini, Cursor, …), or an `@anthropic.com` address;
- a "Generated with …" / "🤖 Generated …" line, or a link to an AI coding tool;
- an AI assistant as git author or committer.

This overrides any default an AI tool applies. `scripts/no-ai-attribution.cjs` is the single
definition; commitlint and `pr:check` both use it.

## Commits

- `type(scope): subject`, header at most 72 characters (aim for 50); the body says why.
- Scope, when given: a plugin (`plugins/<name>`), a platform-neutral skill (`skills/<name>`),
  a Codex plugin (`codex-plugins/<name>`), or a repo scope listed in `commitlint.config.cjs`.
  Scopes are read from the directories, so a new plugin's scope works once it exists.
- One plugin per commit where possible; the same-commit rule in the root `CLAUDE.md` still
  applies (a new plugin and its registrations land together).
- Breaking change: `type(scope)!:` or a `BREAKING CHANGE:` footer.
- Every commit type releases (`release.config.cjs`), so keep commits scoped and meaningful.

## Branches and PRs

1. One-time per clone: `mise run hooks:install`.
2. Branch from an up-to-date `main`: `<type>/<kebab-slug>` (`feat/…`, `fix/…`, `chore/…`,
   `docs/…`). One concern per branch and PR.
3. Before opening the PR, and again before merging:
   `mise run pr:check -- "<PR title>" <file-with-PR-body>`, plus the gates in the root
   `CLAUDE.md`.
4. The PR title is a Conventional Commit header too. The body says what changed, why, the
   evidence (tests, live checks) and what is not covered.
5. Merge with **rebase and merge** (`gh pr merge <n> --rebase --delete-branch`): each commit
   lands on `main` as written, so the changelog and history stay accurate. No squash, no
   merge commits.
6. Never push directly to `main`, except the release commits the release pipeline makes.

## Releases

`mise run release:full` on a clean `main` that matches `origin/main` (see `.mise/tasks/release`).
