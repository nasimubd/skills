# Open-source this marketplace, and protect `main` on the terms a solo maintainer can actually sustain

## Status

Current

## Context and Problem Statement

This marketplace is going from private to public. Two things need
deciding: what "protect the main branch" should actually mean for a
solo-maintained, locally-gated (no CI) repository, and in what order the
open-sourcing steps can even run, given a platform constraint discovered
only by trying.

## Decision Drivers

- The maintainer is currently solo; requiring a second reviewer's approval
  to merge is not sustainable and has no safety benefit yet.
- The release pipeline (`mise run release:full`) pushes the release commit
  and tag directly to `main`, outside of any PR, as the maintainer's own
  identity. Any protection scheme that blocks this breaks releasing.
- This repository's own documented convention is "local-first CI — every
  gate runs locally, there is no `.github/` Actions" (root `CLAUDE.md`,
  `## Gates`). Branch protection should not silently reverse that.
- GitHub branch protection and rulesets are **not available on a private
  repository without a paid plan** — confirmed empirically:
  `gh api repos/nasimubd/skills/branches/main/protection` returned
  `403 Upgrade to GitHub Pro or make this repository public`, and
  `gh api user` showed no active paid plan.

## Considered Options

- **A. Protect `main` first, then open-source.** Impossible on the current
  plan while private — ruled out by the platform, not by preference.
- **B. Open-source first, protect immediately after.** Works, and the
  exposure window (public-but-unprotected) can be minimized to the time it
  takes to run one `gh api` call, since everything else is prepared in
  advance.
- **Require 1 approving review.** GitHub does not allow a PR author to
  approve their own PR, so this would force the maintainer onto a bypass
  list to merge their own work — more setup for no present safety benefit
  with zero other maintainers.
- **Require 0 approving reviews, but still require a PR.** Blocks force
  pushes, deletion, and non-linear history from anyone (including the
  maintainer, for ordinary work) without requiring a reviewer that doesn't
  exist yet.
- **Add a minimal GitHub Actions workflow just to get a required status
  check.** Rejected — contradicts the repository's own local-first-CI
  doctrine. A required check should reflect a real decision to run CI
  remotely, not be added as a side effect of configuring branch protection.
- **Rewrite the three bot-authored `chore(release)` commits to the
  maintainer's identity.** Rejected — confirmed with the maintainer this is
  intentional, standard `semantic-release` behavior, not a defect to fix.

## Decision Outcome

Chosen options: **B**, with **require PR + 0 required approvals**, and
**no required status checks**.

Sequence:

1. While still private: community-standard files (`CONTRIBUTING.md`,
   `CODE_OF_CONDUCT.md`, `SECURITY.md`, issue/PR templates), README
   overhaul, GitHub About (description + topics), and repo-settings
   hardening (squash-merge only, auto-delete branches on merge) — all of
   which work on a private repo.
2. Maintainer flips visibility to public.
3. Immediately: a GitHub Ruleset on `refs/heads/main` — require pull
   request (0 required approvals, dismiss stale reviews on push), block
   force-pushes, block deletion, require linear history — with the
   maintainer/repository-admin as a bypass actor so the release pipeline's
   direct push keeps working unchanged.
4. Confirm secret scanning, push protection, and Dependabot alerts are
   active (free for public repos; sometimes need explicit enabling).

### Consequences

- Good: `main` is meaningfully protected against force-push, deletion, and
  merge-commit history the moment it's public, with no gap longer than the
  time to run the ruleset command.
- Good: the release pipeline is untouched — no config change, no new
  friction.
- Good: matches how the maintainer actually works today (solo, gates
  local) instead of importing process from a team context that doesn't
  exist here.
- Accepted trade-off: no required status check means a PR can be merged
  without GitHub itself having verified the gates ran — mitigated by the
  gates being fast, well-documented, and part of `CONTRIBUTING.md`'s
  explicit expectation, but this is enforced by convention, not by the
  platform. Revisit if this repository ever adds real CI.
- Deferred, not rejected outright: requiring signed commits. Not currently
  used anywhere in this repository's history; worth reconsidering once
  there are external contributors, but adding it now is friction with no
  existing practice to preserve.
