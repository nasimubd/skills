# Contributing

Thanks for considering a contribution to this marketplace.

## Before you start

Search [existing issues](https://github.com/nasimubd/skills/issues) and open
one before starting non-trivial work, so effort doesn't collide with
something already in progress or already decided against.

## Adding or changing a plugin

1. Create or edit a plugin under `plugins/<name>/`. See
   [plugins/CLAUDE.md](./plugins/CLAUDE.md) for the required structure,
   manifest shape, and the `SKILL.md` contract.
2. Add or update its entry in `.claude-plugin/marketplace.json` — the single
   source of truth for what plugins exist.
3. Run the gates before opening a PR:

   ```bash
   node scripts/validate-plugins.mjs        # manifests, schema, paths, dependencies
   node scripts/check-version-equality.mjs  # the version lockstep actually holds
   node scripts/validate-skill-body.mjs     # SKILL.md structural contract
   mise run test-marketplace-hook-regression-suite
   ```

   All four run locally — there is no CI. A PR that doesn't pass these
   won't be merged.
4. Commit using [Conventional Commits](https://www.conventionalcommits.org/):
   a short imperative subject (≤50 characters preferred, 72 hard cap) and,
   for anything non-trivial, a body explaining *why*, not just what changed.
5. Open a PR. It will be **squash-merged** — the PR title becomes the final
   commit subject, so write it as a proper Conventional Commit subject line,
   not a description of the PR process.

## Documentation changes

Root-level and hub `CLAUDE.md` files are updated **in the same commit** as
the change they describe — a stale doc is treated as a defect, not a
follow-up. See [docs/CLAUDE.md](./docs/CLAUDE.md) for ADR and design-spec
conventions if your change involves a decision worth recording.

## Commit and PR expectations

- No AI attribution in any commit message, commit trailer, or PR body — this
  applies to every contributor, not just the maintainer.
- No machine-specific literals (absolute paths, hostnames, usernames,
  credentials) in tracked source. This is a public repository; anything
  committed here is published.
- Every commit type releases (see [Versioning](./README.md#versioning)) — a
  `docs` or `chore` commit still bumps a version, so keep commits scoped and
  meaningful rather than padding history.

## Reporting a bug or requesting a feature

Use the issue templates. For a security vulnerability, see
[SECURITY.md](./SECURITY.md) instead of opening a public issue.

## Code of Conduct

This project follows the [Code of Conduct](./CODE_OF_CONDUCT.md).
Participation implies agreement to it.
