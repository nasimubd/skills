# 1.0.0 (2026-09-29)


### Bug Fixes

* **release:** accept every legitimate GitHub token prefix ([d36f8bf](https://github.com/nasimubd/skills/commit/d36f8bf7a89aab186f34a1959e2d1ab5a4f4d654))

Check 2 accepted only ghp_ and github_pat_, so a gho_ OAuth token — what `gh auth token` returns when the CLI is authenticated interactively, and therefore the most common way this variable gets set on a developer machine — was reported as malformed.

Now accepts ghp_ (classic PAT), gho_ (OAuth), ghu_ (user-to-server), ghs_ (server-to-server) and github_pat_ (fine-grained). All five are valid for the API calls a release makes.

Found by running the gate rather than reading it. A gate that blocks the ordinary path is worse than no gate: the reflex it trains is to bypass it.
* **release:** reflow commit bodies for GFM, and stop hiding lockfile diffs ([e95b7df](https://github.com/nasimubd/skills/commit/e95b7df14b2c21ecd550a009cd35dd8be77d137b))

Two corrections to the scaffold.

The release-notes generator emitted commit bodies raw. GitHub renders a release body as GFM with hard line breaks on, so a body wrapped at 72 columns arrived studded with &lt;br>, an angle-bracketed generic like Vec&lt;T> was eaten as an unknown HTML tag, and indented blocks flattened. The transform now joins prose runs while preserving fences, structural lines and genuinely aligned columns, and escapes angle brackets outside code spans.

No try/catch around it, deliberately. It runs during generateNotes, before a tag exists, so a throw aborts the release with nothing published — which is the outcome we want. Catching would restore exactly the silent degradation being removed: an error logged, the raw body published, and a release that looks wrong for a reason nobody sees.

The test asserts on rendered output, not on the transform's return value — a transform-only test passes while every release still looks wrong. It was mutation-tested from both directions: bypass the reflow and 6 of its 25 assertions fail, covering all three modes; restore it and all 25 pass.

Separately, .gitattributes had `-diff` on lockfiles. `-diff` marks a file binary for diff purposes, so git reports only "Binary files differ" — locally and in review. For a lockfile that is precisely backwards: the lockfile diff is the one place a changed resolution, a substituted registry or an unexpected transitive dependency becomes visible to a person. Collapsing it is helpful; hiding it is a supply-chain review gap.

Not hypothetical: adding one test-only dependency split the tree and pinned a second copy of a package under semantic-release to satisfy a peer range. Invisible under `-diff`; one line of diff without it. That copy is now pinned to match what semantic-release already resolves.

CHANGELOG.md keeps `-diff` — it restates commits that are themselves reviewable, so nothing is lost by not diffing it.


### Features

* **repo:** scaffold the marketplace ([d5e8ac0](https://github.com/nasimubd/skills/commit/d5e8ac08f4092512d98f74bee8e3b8a1739911db))

An empty marketplace with working machinery, so the first plugin lands against gates that already pass rather than alongside gates written at the same time.

Structure follows an established reference marketplace: marketplace.json as the single source of truth, a tracked .claude-plugin/plugins symlink so a ./plugins/&lt;name> source resolves from either root, hub-and-spoke CLAUDE.md with progressive disclosure, and semantic-release cutting v&lt;version> tags with notes generated from commits.

Two gates here do not exist upstream:

- check-version-equality.mjs asserts the version lockstep actually holds
  — every plugin entry equals the marketplace root, and no per-plugin
  manifest carries a version key at all. Upstream's own strategy document
  specified this and it was never written; the observable cost was an
  entry six minor versions behind the marketplace shipping it, and a
  manifest pinned across roughly sixteen majors because it was in the
  release assets but not the version sync list.

- validate-skill-body.mjs asserts a skill's frontmatter name equals its
  directory name, plus the description budget, the references/ threshold
  and the two mandatory body sections. A slash command resolves on the
  directory, so a mismatch is invisible at runtime while the description
  keeps advertising the old identity.

Both were exercised against deliberately broken fixtures, not just against a passing tree.

Three divergences from the reference, each deliberate:

- .gitignore carries a !.claude/commands/ negation. The reference ignores
  .claude/ wholesale because it has no command wrappers; this repo commits
  its release namespace.
- .gitattributes exists. The reference has none, despite a committed
  symlink and a generated changelog now past a megabyte.
- Exactly one lockfile. The reference ships two.

Preflight is 462 lines against the reference's 1072: the universal core kept, seventeen hook-architecture audits not ported and tombstoned with the reason. Its empty-registry waiver for the test suite is derived from the manifest on every run, so it lapses by itself when the first plugin is registered — a flag set by hand is a flag left on.
