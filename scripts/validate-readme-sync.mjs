#!/usr/bin/env node
/** Enforce the public README contract for every marketplace plugin. */
import { existsSync, readFileSync } from 'node:fs';
import { readdir } from 'node:fs/promises';
import { join, relative } from 'node:path';

const ROOT = process.env.SKILLS_ROOT ? process.env.SKILLS_ROOT : process.cwd();
const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));
const errors = [];
const marketplacePath = join(ROOT, '.claude-plugin', 'marketplace.json');
const rootReadmePath = join(ROOT, 'README.md');
if (!existsSync(marketplacePath) || !existsSync(rootReadmePath)) {
  console.error('README SYNC: missing marketplace.json or root README.md');
  process.exit(1);
}
const marketplace = readJson(marketplacePath);
const rootReadme = readFileSync(rootReadmePath, 'utf8');
const pluginsHeading = rootReadme.indexOf('## Plugins');
const pluginsSectionEnd = pluginsHeading >= 0 ? rootReadme.indexOf('\n\nThe repository also includes', pluginsHeading + 10) : -1;
const pluginTable = pluginsHeading >= 0 ? rootReadme.slice(pluginsHeading, pluginsSectionEnd >= 0 ? pluginsSectionEnd : undefined) : '';
const entries = Array.isArray(marketplace.plugins) ? marketplace.plugins : [];
const pluginDirs = new Set((await readdir(join(ROOT, 'plugins'), { withFileTypes: true }))
  .filter((entry) => entry.isDirectory() && existsSync(join(ROOT, 'plugins', entry.name, 'plugin.json'))).map((entry) => entry.name));
for (const entry of entries) {
  const dir = entry.source?.replace(/^\.\/plugins\//, '');
  if (!dir || !pluginDirs.has(dir)) continue;
  const pluginReadmePath = join(ROOT, 'plugins', dir, 'README.md');
  if (!existsSync(pluginReadmePath)) {
    errors.push(`${relative(ROOT, pluginReadmePath)} is required for registered plugin ${entry.name}`);
    continue;
  }
  const pluginReadme = readFileSync(pluginReadmePath, 'utf8');
  const headings = [...pluginReadme.matchAll(/^#\s+(.+)$/gmi)].map((match) => match[1].trim().toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, ''));
  if (!headings.includes(entry.name.toLowerCase()))
    errors.push(`${relative(ROOT, pluginReadmePath)} must have a heading for ${entry.name}`);
  if (!pluginReadme.includes(entry.description))
    errors.push(`${relative(ROOT, pluginReadmePath)} must include the marketplace description`);
  const rootLink = new RegExp(`\\./plugins/${dir.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\$&')}(?:\\)|/|\\b)`);
  if (!rootLink.test(rootReadme)) errors.push(`README.md must link ./plugins/${dir}`);
  const tableRow = `| [\`${entry.name}\`](./plugins/${dir}) | ${entry.description} | \`${entry.category}\` |`;
  if (!pluginTable.includes(tableRow)) errors.push(`README.md plugin table is missing or stale for ${entry.name}`);
}
for (const dir of pluginDirs) {
  if (!entries.some((entry) => entry.source === `./plugins/${dir}`))
    errors.push(`plugins/${dir} has no marketplace entry; README cannot be kept in sync`);
}
console.log(`README SYNC: ${entries.length} registered plugin(s), ${pluginDirs.size} plugin director${pluginDirs.size === 1 ? 'y' : 'ies'}`);
if (errors.length) { for (const error of errors) console.error(`✗ ${error}`); process.exit(1); }
console.log('✓ plugin README files and root README links are synchronized');
