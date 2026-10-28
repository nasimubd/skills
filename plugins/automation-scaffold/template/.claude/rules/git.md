# Git protocol (on demand)

Applies to every commit, branch, PR, merge and release in this repository. Enforced by the
commit-msg hook (`.githooks/commit-msg`, installed by `mise run setup`) and by
`mise run pr:check`. There is no CI, so these local checks are the only gate.

## No AI attribution

Never add, in any commit message, PR title, PR body, merge commit, tag or release note:

- a `Co-Authored-By:` trailer naming an AI assistant (Claude, Anthropic, Copilot, ChatGPT,
  Gemini, Cursor, …), or an `@anthropic.com` address;
- a "Generated with …" / "🤖 Generated …" line, or a link to an AI coding tool;
- an AI assistant as git author or committer.

This overrides any default an AI tool applies. `scripts/no-ai-attribution.js` is the single
definition; commitlint and `pr:check` both use it, so a violation fails locally before it
can reach GitHub.

## Commits

- `type(scope): subject`, header at most 72 characters (aim for 50); the body says why.
- Scope: a component id from `releases/components.json`, or a repo scope listed in
  `commitlint.config.cjs`.
- One component per commit where possible, so each component's changelog reads cleanly.
- Breaking change: `type(scope)!:` or a `BREAKING CHANGE:` footer.

## Branches and PRs

1. Branch from an up-to-date `main` (`feat/…`, `fix/…`, `chore/…`, `docs/…`).
2. Before opening the PR, and again before merging:
   `mise run pr:check -- "<PR title>" <file-with-PR-body>`.
3. The PR title is a Conventional Commit header too.
4. Merge with **rebase and merge** (`gh pr merge <n> --rebase --delete-branch`). Each commit
   lands on `main` as written, so component changelogs stay accurate. No merge commits.
5. Never push directly to `main`, except the release commits `semantic-release-bot` makes.

## Releases

On a clean `main` that matches `origin/main`: `mise run release:dry`, then
`mise run release`, then `mise run release:verify`. Details in `docs/RELEASE.md`.
