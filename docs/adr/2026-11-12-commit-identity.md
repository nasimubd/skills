# Never let git guess a commit identity

## Status

Current. Extends [2026-10-28-git-protocol.md](./2026-10-28-git-protocol.md); that record's
decisions stand.

## Context and Problem Statement

Git builds an author and committer from the operating-system account when no `user.name` and
`user.email` are configured: the account's full name, and an address at the machine's host
name or IP. On the maintainer's machine that produced commits authored under an employer's
name with an address on the local network. The repository is public, so both are published,
and removing them later means rewriting history and moving released tags.

The git protocol already checked commit messages for AI attribution, but nothing checked who
a commit was attributed to. The failure was silent: git prints nothing when it guesses, and an
AI tool that commits without reading the identity first will not notice either.

## Decision Drivers

- The mistake is cheap to prevent and expensive to undo in a public repository.
- The repository takes contributions, so the rule cannot force one person's name on everyone.
- There is no CI by design, so enforcement has to run locally (as for the rest of the protocol).
- An identity that was set on purpose is the person's choice, even if unusual.

## Considered Options

- **Document it only.** Rejected: the same reasoning as the 2026-10-28 record; an instruction
  can be skipped, and this failure is silent.
- **A fixed allow-list of names.** Rejected: it would block contributors and would itself name
  people in the repository.
- **Set the identity globally on the maintainer's machine.** Rejected as the fix: it helps one
  machine, protects no clone, and changes the identity used for unrelated repositories.
- **Stop git guessing, and reject an identity that is machine-derived.** Chosen.

## Decision Outcome

1. `mise run hooks:install` sets `user.useConfigOnly=true` in the clone. Git then refuses to
   commit without an explicit identity instead of inventing one. This removes the root cause.
2. The same task fills a missing identity from the signed-in `gh` account (the login and its
   `<id>+<login>@users.noreply.github.com` address), and leaves any identity already configured,
   locally or globally, alone. With no `gh`, it says what to set.
3. `scripts/commit-identity.cjs` is the single definition of an acceptable identity: a non-empty
   name and an email whose domain is not an IP address, a bare host name or a private network
   name. The commit-msg hook runs it for the identity about to commit, before the message is
   read; `mise run pr:check` runs it for every author and committer on the branch. It catches an
   identity that was set but is machine-derived, for example through `GIT_AUTHOR_*`.
4. The check does not judge names or addresses that look deliberate. A name containing a
   separator, or a work address, passes; only values that are evidently derived from the
   machine fail.
5. The rule is written down in `.claude/rules/git.md`, because the usual cause is a tool
   committing without checking.

### Consequences

- Good: the leak cannot recur silently on any clone that ran `hooks:install`; git itself refuses.
- Good: a machine-derived identity set by other means is still caught locally, before a push.
- Trade-off: a fresh clone must run `mise run hooks:install` once, as for the rest of the
  protocol; until then the hook refuses commits and says so.
- Trade-off: a deliberate but unwanted identity (a real work address, for instance) is not
  detected. That is a person's decision, and the check is not the place to second-guess it.
- Limit: GitHub's rebase-and-merge writes the merging account's **profile name** as the
  committer. That is configured in the GitHub profile, outside this repository, and no local
  check can change it.
- Limit: commits made before this decision keep the identity they were made with. Rewriting
  published history is a separate, destructive decision (it needs a force-push to the protected
  branch and moves released tags) and is not part of this record.
