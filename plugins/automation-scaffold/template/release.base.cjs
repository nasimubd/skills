/**
 * Shared semantic-release config for every component (docs/RELEASE.md).
 *
 * Not discovered from the repo root on purpose: each component's package.json extends
 * ["semantic-release-monorepo", "<relative path>/release.base.cjs"], and scripts/release.sh
 * runs semantic-release inside each component folder. semantic-release-monorepo keeps only
 * the commits that touched that folder and tags the release `<id>-vX.Y.Z`.
 *
 * Rules:
 *  - every commit type releases: breaking = major, feat = minor, everything else = patch;
 *  - `BREAKING` is accepted alongside `BREAKING CHANGE` / `BREAKING-CHANGE`, so a breaking
 *    change can never ship as a minor;
 *  - the parser's "-field-" syntax is off: a line of dashes in a body would otherwise
 *    swallow the rest of the body from the notes;
 *  - the release commit is `chore(release): <tag> [skip ci]`, made by semantic-release-bot,
 *    with no AI attribution;
 *  - GitHub comments, labels and back-references are off (tag-driven, not PR-driven);
 *  - one CHANGELOG.md per component.
 *
 * Keep `${nextRelease.gitTag}` in a plain (non-template) string: @semantic-release/git
 * expands it with lodash, not JavaScript.
 */
const path = require('path');

const component = require(path.join(process.cwd(), 'package.json')).name;

/** A regex that can't match: disables the parser's "-field-" capture. */
const NEVER_MATCHES = /(?!)/;

/** Identical for commit-analyzer and release-notes-generator, or the bump and the notes disagree. */
const parserOpts = {
  noteKeywords: ['BREAKING CHANGE', 'BREAKING-CHANGE', 'BREAKING'],
  fieldPattern: NEVER_MATCHES,
};

module.exports = {
  branches: ['main'],
  plugins: [
    [
      '@semantic-release/commit-analyzer',
      {
        preset: 'conventionalcommits',
        parserOpts,
        releaseRules: [
          { breaking: true, release: 'major' },
          { type: 'docs', release: 'patch' },
          { type: 'chore', release: 'patch' },
          { type: 'style', release: 'patch' },
          { type: 'refactor', release: 'patch' },
          { type: 'test', release: 'patch' },
          { type: 'build', release: 'patch' },
          { type: 'ci', release: 'patch' },
          { type: 'revert', release: 'patch' },
        ],
      },
    ],
    ['@semantic-release/release-notes-generator', { preset: 'conventionalcommits', parserOpts }],
    ['@semantic-release/changelog', { changelogFile: 'CHANGELOG.md', changelogTitle: `# Changelog: ${component}` }],
    [
      '@semantic-release/git',
      {
        assets: ['CHANGELOG.md'],
        message: 'chore(release): ${nextRelease.gitTag} [skip ci]',
      },
    ],
    [
      '@semantic-release/github',
      {
        // The production pin travels with the release.
        assets: [{ path: 'release.lock.json', label: 'Production pin (release.lock.json)' }],
        successCommentCondition: false,
        failCommentCondition: false,
        releasedLabels: false,
        addReleases: false,
      },
    ],
  ],
};
