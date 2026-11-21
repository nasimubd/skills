#!/usr/bin/env node
// The one definition of an acceptable commit identity for this repository, used by the
// commit-msg hook (the identity about to commit) and by `mise run pr:check` (every commit
// on the branch).
//
// Why it exists: with no user.name/user.email configured, git invents an identity from the
// operating-system account: the account's full name and an address at the machine's host
// name or IP. In a public repository that publishes an employer's name and a private network
// address. `user.useConfigOnly` (set by `mise run hooks:install`) stops git guessing; this
// check catches an identity that was set but is machine-derived, for example through the
// GIT_AUTHOR_* environment variables or a hand-copied config.
//
//   commit-identity.cjs                    check the author and committer git would use now
//   commit-identity.cjs --range <revs>     check every author and committer in a revision range
//   commit-identity.cjs --stdin            check lines of the form "Name <email>"
//
// Exit 0 when every identity is acceptable, 1 otherwise (naming each problem and the fix).

'use strict';

const { execFileSync } = require('node:child_process');

const PRIVATE_SUFFIXES = ['local', 'lan', 'home', 'internal', 'localdomain', 'localhost', 'corp', 'intranet', 'private', 'home.arpa'];

const FIX =
  'Set one: git config user.name <your name or GitHub login>; ' +
  'git config user.email <id>+<login>@users.noreply.github.com ' +
  '(`mise run hooks:install` does this when the gh CLI is signed in).';

// Returns a short description of what is wrong, or null when the identity is acceptable.
function identityProblem(name, email) {
  if (!String(name ?? '').trim()) return 'the name is empty';
  const mail = String(email ?? '').trim();
  const m = /^[^@\s<>]+@([^@\s<>]+)$/.exec(mail);
  if (!m) return `"${mail}" is not an email address`;
  const domain = m[1].toLowerCase();
  if (/^\[.*\]$/.test(domain) || domain.includes(':') || /^\d{1,3}(\.\d{1,3}){3}$/.test(domain)) {
    return 'the email domain is an IP address (git guessed it from this machine)';
  }
  if (!domain.includes('.')) return 'the email domain is a bare host name (git guessed it from this machine)';
  if (PRIVATE_SUFFIXES.some((s) => domain === s || domain.endsWith(`.${s}`))) {
    return 'the email domain is a private network name (git guessed it from this machine)';
  }
  return null;
}

// "Name <email> 1699999999 +0000" or "Name <email>" -> { name, email } or null.
function parseIdent(line) {
  const m = /^(.*?)\s*<([^>]*)>/.exec(line.trim());
  return m ? { name: m[1], email: m[2] } : null;
}

function git(args) {
  return execFileSync('git', args, { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}

function collect(argv) {
  const out = []; // { label, line }
  const rangeAt = argv.indexOf('--range');
  if (argv.includes('--stdin')) {
    const lines = require('node:fs').readFileSync(0, 'utf8').split('\n').filter((l) => l.trim());
    for (const line of lines) out.push({ label: 'identity', line });
  } else if (rangeAt !== -1) {
    const range = argv[rangeAt + 1];
    if (!range) { console.error('commit-identity: --range needs a revision range'); process.exit(2); }
    const seen = new Set();
    const log = git(['log', '--format=A\t%an <%ae>%nC\t%cn <%ce>', range]);
    for (const row of log.split('\n').filter(Boolean)) {
      const [kind, ident] = row.split('\t');
      const label = kind === 'A' ? 'author' : 'committer';
      const key = `${label}:${ident}`;
      if (!seen.has(key)) { seen.add(key); out.push({ label, line: ident }); }
    }
  } else {
    for (const [label, v] of [['author', 'GIT_AUTHOR_IDENT'], ['committer', 'GIT_COMMITTER_IDENT']]) {
      try {
        out.push({ label, line: git(['var', v]).trim() });
      } catch (e) {
        out.push({ label, line: '', error: 'git has no identity configured for this repository' });
      }
    }
  }
  return out;
}

function main(argv) {
  const items = collect(argv);
  let problems = 0;
  for (const { label, line, error } of items) {
    const id = error ? null : parseIdent(line);
    const problem = error || (id ? identityProblem(id.name, id.email) : `"${line}" is not "Name <email>"`);
    if (problem) {
      problems += 1;
      const shown = id ? `${id.name} <${id.email}>` : line || '(none)';
      console.error(`✗ commit identity (${label}) ${shown}: ${problem}.`);
    }
  }
  if (problems) {
    console.error(FIX);
    return 1;
  }
  if (argv.includes('--range') || argv.includes('--stdin')) {
    console.log(`✓ commit identity: ${items.length} author/committer identit${items.length === 1 ? 'y' : 'ies'}, none machine-derived`);
  }
  return 0;
}

if (require.main === module) {
  process.exit(main(process.argv.slice(2)));
}

module.exports = { identityProblem, parseIdent };
