## What this changes

## Checklist

- [ ] `node scripts/validate-plugins.mjs` passes
- [ ] `node scripts/check-version-equality.mjs` passes
- [ ] `node scripts/validate-skill-body.mjs` passes
- [ ] `mise run test-marketplace-hook-regression-suite` passes
- [ ] `mise run pr:check -- "<title>" <body-file>` passes (branch name, commits, title, body)
- [ ] Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
- [ ] No AI attribution in any commit message or this PR description
- [ ] No machine-specific literals (absolute paths, hostnames, credentials) added
- [ ] Relevant `CLAUDE.md` updated in the same commit, if this changes an invariant

## Notes for the reviewer

This PR will be **rebased and merged** — every commit lands on `main` as
written, so each commit must be a proper Conventional Commit on its own
(see `.claude/rules/git.md`).
