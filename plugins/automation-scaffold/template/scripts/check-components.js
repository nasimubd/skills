#!/usr/bin/env node
// Check releases/components.json against the component folders (docs/RELEASE.md).
// Every component needs: a unique id with the right prefix for its kind, an existing folder,
// and <path>/package.json named after the id and extending semantic-release-monorepo plus
// the shared release.base.cjs. Prints what it examined; exit 1 on any problem.

'use strict';

const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const PREFIX = { 'canvas-app': 'app-', 'cloud-flow': 'flow-', 'n8n-workflow': 'n8n-', 'make-scenario': 'make-' };

const { components } = JSON.parse(fs.readFileSync(path.join(ROOT, 'releases', 'components.json'), 'utf8'));
const problems = [];
const seenIds = new Set();
const seenPaths = new Set();

for (const c of components) {
  const where = `${c.id ?? '(no id)'}`;
  if (!PREFIX[c.kind]) problems.push(`${where}: unknown kind "${c.kind}"`);
  else if (!c.id?.startsWith(PREFIX[c.kind])) problems.push(`${where}: id must start with "${PREFIX[c.kind]}" for kind ${c.kind}`);
  if (seenIds.has(c.id)) problems.push(`${where}: duplicate id`);
  if (seenPaths.has(c.path)) problems.push(`${where}: path ${c.path} is used by another component`);
  seenIds.add(c.id);
  seenPaths.add(c.path);

  const dir = path.join(ROOT, c.path ?? '');
  if (!c.path || !fs.existsSync(dir)) { problems.push(`${where}: folder ${c.path} does not exist`); continue; }
  const pkgFile = path.join(dir, 'package.json');
  if (!fs.existsSync(pkgFile)) { problems.push(`${where}: missing ${c.path}/package.json`); continue; }
  const pkg = JSON.parse(fs.readFileSync(pkgFile, 'utf8'));
  if (pkg.name !== c.id) problems.push(`${where}: ${c.path}/package.json name is "${pkg.name}", expected "${c.id}"`);
  if (pkg.private !== true) problems.push(`${where}: ${c.path}/package.json must be private`);
  const ext = [].concat(pkg.release?.extends ?? []);
  const base = path.relative(dir, path.join(ROOT, 'release.base.cjs')).split(path.sep).join('/');
  if (!ext.includes('semantic-release-monorepo') || !ext.some((e) => e === base || e === `./${base}`)) {
    problems.push(`${where}: release.extends must be ["semantic-release-monorepo", "${base}"]`);
  }
}

console.log(`Components checked: ${components.length}`);
for (const p of problems) console.error(`  ✗ ${p}`);
if (problems.length) { console.error(`${problems.length} problem(s)`); process.exit(1); }
console.log('✓ registry and component folders agree');
