/**
 * Conventional Commits for this repository (.claude/rules/git.md).
 *
 * Header: `type(scope): subject`, 72 characters at most (aim for 50). The body says why.
 * A breaking change is `type(scope)!:` or a `BREAKING CHANGE:` footer. The scope is
 * optional; when given it must be a plugin, skill or Codex plugin in this tree (read from
 * the directories, so a new one is valid as soon as it exists) or a repo-level scope below.
 *
 * No AI attribution: a Co-Authored-By for an AI assistant or a "Generated with ..." line is
 * rejected (scripts/no-ai-attribution.cjs).
 */
const fs = require('fs');
const path = require('path');
const { findAttribution } = require('./scripts/no-ai-attribution.cjs');

const dirsIn = (rel) => {
  const dir = path.join(__dirname, rel);
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir, { withFileTypes: true }).filter((d) => d.isDirectory()).map((d) => d.name);
};

const REPO_SCOPES = [
  'repo', 'release', 'marketplace', 'agent-skills', 'deps', 'mise',
  'scripts', 'hooks', 'tests', 'docs', 'ci', 'schema',
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
    'scope-enum': [2, 'always', [...new Set([...dirsIn('plugins'), ...dirsIn('skills'), ...dirsIn('codex-plugins'), ...REPO_SCOPES])]],
    'no-ai-attribution': [2, 'always'],
    // Bodies are prose and may carry long URLs or paths; release notes carry long lines.
    'body-max-line-length': [0],
    'footer-max-line-length': [0],
  },
};
