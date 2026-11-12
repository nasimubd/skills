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

## Commit identity

Every commit is authored and committed under an identity that was **set on purpose**: the
maintainer's GitHub login with its no-reply address (`<id>+<login>@users.noreply.github.com`),
or a contributor's own name and address. Never one that git guessed.

With nothing configured, git invents an identity from the operating-system account: the
account's full name (which can be an employer's name) and an address at the machine's host
name or IP. In a public repository that is a privacy leak, and it cannot be undone without
rewriting history. This applies to people and to AI tools alike; a tool that commits without
checking the identity first is the usual way it happens.

- `mise run hooks:install` sets `user.useConfigOnly=true`, so git refuses to commit without an
  explicit identity, and fills a missing one from the signed-in `gh` account.
- The commit-msg hook and `mise run pr:check` run `scripts/commit-identity.cjs`, which rejects
  an email at an IP address, a bare host name or a private network name (`.local`, `.lan`,
  `.home.arpa`, …) and an empty name. Decision record:
  [docs/adr/2026-11-12-commit-identity.md](../../docs/adr/2026-11-12-commit-identity.md).
- Before the first commit in a clone, `git var GIT_AUTHOR_IDENT` shows what will be used.
- GitHub's rebase-and-merge writes the **merging account's profile name** as committer;
  that is set in the GitHub profile, not in this repository.

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
