/**
 * Conventional Commits (docs/RELEASE.md).
 *
 * Header: `type(scope): subject`, 72 characters at most (aim for 50). The body says why.
 * A breaking change is `type(scope)!:` or a `BREAKING CHANGE:` footer.
 *
 * Scopes are the component ids in releases/components.json (releases are cut per
 * component) plus the repo-level scopes below. A new component's scope is valid as soon as
 * it is in the registry.
 *
 * No AI attribution: a commit carrying a Co-Authored-By for an AI assistant or a
 * "Generated with ..." line is rejected (scripts/no-ai-attribution.js, CLAUDE.md).
 */
const { components } = require('./releases/components.json');
const { findAttribution } = require('./scripts/no-ai-attribution.js');

const REPO_SCOPES = [
  'repo', 'docs', 'rules', 'scripts', 'schema', 'data', 'lists',
  'ci', 'deps', 'mise', 'release', 'solution',
];

module.exports = {
  extends: ['@commitlint/config-conventional'],
  plugins: [
    {
      rules: {
        'no-ai-attribution': ({ raw }) => {
          const hit = findAttribution(raw);
          return [!hit, hit ? `AI attribution is not allowed: "${hit}"` : ''];
        },
      },
    },
  ],
  rules: {
    'header-max-length': [2, 'always', 72],
    'scope-enum': [2, 'always', [...components.map((c) => c.id), ...REPO_SCOPES]],
    'no-ai-attribution': [2, 'always'],
    // Bodies are prose and may carry long URLs or paths.
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
  },
};
