#!/usr/bin/env node
// Render the repository template into a folder and register the discovered components.
// Never overwrites an existing file (it is reported as kept); `--force` overwrites the
// convention files only, never component sources.
//
//   scaffold.js --dir <repo> --name <slug> [--repo owner/name] [--title T] [--description D]
//               [--discovery discovery.json] [--no-export] [--force]
//
// After rendering it runs, inside the new repository, `scripts/export.js` and
// `scripts/release-pin.js pin` for every component (read-only on the platforms), unless
// --no-export. Prints a JSON summary on stdout; progress on stderr.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const PLUGIN = path.resolve(__dirname, '..');
const TEMPLATE = path.join(PLUGIN, 'template');
const CONFIG_FILE = path.join(process.env.AUTOMATION_SCAFFOLD_CONFIG_DIR || path.join(os.homedir(), '.config', 'automation-scaffold'), 'config.json');
const log = (s) => process.stderr.write(`${s}\n`);

const KIND = {
  'canvas-app': { prefix: 'app', dir: (s, n) => `src/CanvasApps/${n}`, label: 'Canvas app' },
  'cloud-flow': { prefix: 'flow', dir: (s) => `src/Flows/${s}`, label: 'Cloud flow' },
  'n8n-workflow': { prefix: 'n8n', dir: (s) => `workflows/${s}`, label: 'n8n workflow' },
  'make-scenario': { prefix: 'make', dir: (s) => `src/Make/${s}`, label: 'Make scenario' },
};

function args() {
  const a = { dir: null, name: null, repo: null, title: null, description: null, discovery: null, export: true, force: false };
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    const v = argv[i];
    if (v === '--dir') a.dir = path.resolve(argv[++i]);
    else if (v === '--name') a.name = argv[++i];
    else if (v === '--repo') a.repo = argv[++i];
    else if (v === '--title') a.title = argv[++i];
    else if (v === '--description') a.description = argv[++i];
    else if (v === '--discovery') a.discovery = argv[++i];
    else if (v === '--no-export') a.export = false;
    else if (v === '--force') a.force = true;
    else throw new Error(`unknown argument ${v}`);
  }
  if (!a.dir || !a.name) throw new Error('usage: scaffold.js --dir <repo> --name <slug> [--title T] [--description D] [--discovery file] [--no-export] [--force]');
  if (!/^[a-z0-9]+(-[a-z0-9]+)*$/.test(a.name)) throw new Error('--name must be lowercase kebab-case');
  return a;
}

/** Slug for ids and folders: drop working prefixes ([OPT], TEST -), keep words. */
function slugify(name) {
  return String(name)
    .replace(/^\s*\[OPT\]\s*/i, '').replace(/^\s*TEST\s*-\s*/i, '')
    .normalize('NFKD').replace(/[^\w\s-]/g, ' ').trim().toLowerCase()
    .replace(/[\s_]+/g, '-').replace(/-+/g, '-').replace(/^-|-$/g, '') || 'unnamed';
}
/**
 * Component slug: the artifact's slug without the project's own name in front (it is already
 * the repository), cut on a word boundary to at most MAX_SLUG characters. The id is the
 * Conventional Commits scope, and commitlint caps the whole header at 72 characters.
 */
const MAX_SLUG = 36;
function componentSlug(name, project) {
  let slug = slugify(name);
  const rest = slug.startsWith(`${project}-`) ? slug.slice(project.length + 1) : '';
  if (rest) slug = rest;
  while (slug.length > MAX_SLUG && slug.includes('-')) slug = slug.slice(0, slug.lastIndexOf('-'));
  return slug.slice(0, MAX_SLUG);
}
/** One factual sentence for the README and the GitHub About: what the repository holds. */
function describe(title, components) {
  const count = (kind, one, many) => {
    const n = components.filter((c) => c.kind === kind).length;
    return n ? `${n} ${n === 1 ? one : many}` : null;
  };
  const parts = [
    count('canvas-app', 'Power Apps canvas app', 'Power Apps canvas apps'),
    count('cloud-flow', 'Power Automate flow', 'Power Automate flows'),
    count('n8n-workflow', 'n8n workflow', 'n8n workflows'),
    count('make-scenario', 'Make scenario', 'Make scenarios'),
  ].filter(Boolean);
  const list = parts.length > 1 ? `${parts.slice(0, -1).join(', ')} and ${parts.at(-1)}` : parts[0];
  return list
    ? `${title}: ${list}, exported from production and released per component.`
    : `${title}: automation exported from production and released per component.`;
}

/** GitHub topics from the registered component kinds and the release convention. */
const KIND_TOPICS = {
  'canvas-app': ['power-platform', 'power-apps'],
  'cloud-flow': ['power-platform', 'power-automate'],
  'n8n-workflow': ['n8n'],
  'make-scenario': ['make'],
};
function topicsFor(components) {
  const kinds = components.map((c) => KIND_TOPICS[c.kind] ?? []).flat();
  return [...new Set([...kinds, 'automation', 'semantic-release', 'conventional-commits'])];
}

const folderName = (name) => slugify(name).split('-').map((w) => w[0].toUpperCase() + w.slice(1)).join('-');

function walk(dir, base = dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const p = path.join(dir, e.name);
    return e.isDirectory() ? walk(p, base) : [path.relative(base, p)];
  });
}

const fill = (text, vars) => text.replace(/\{\{([A-Z_]+)\}\}/g, (m, k) => (k in vars ? vars[k] : m));

function mermaid(discovery) {
  if (!discovery?.nodes?.length) return '_No components discovered yet. Add them as described in docs/RELEASE.md._';
  const id = new Map(discovery.nodes.map((n, i) => [n.key, `N${i}`]));
  const shape = (n) => {
    const label = `${n.name}`.replace(/"/g, "'");
    const kind = { 'canvas-app': 'app', 'cloud-flow': 'flow', 'n8n-workflow': 'n8n', 'make-scenario': 'Make', 'sharepoint-list': 'list', 'zapier-hook': 'Zapier', 'make-hook': 'Make hook' }[n.kind] ?? n.kind;
    return n.kind === 'sharepoint-list' ? `${id.get(n.key)}[("${label}<br/><i>${kind}</i>")]` : `${id.get(n.key)}["${label}<br/><i>${kind}</i>"]`;
  };
  const lines = ['```mermaid', 'flowchart LR'];
  for (const n of discovery.nodes) lines.push(`  ${shape(n)}`);
  for (const e of discovery.edges) lines.push(`  ${id.get(e.from)} -->|${e.relation}| ${id.get(e.to)}`);
  lines.push('```');
  return lines.join('\n');
}

function architectureDoc(discovery, components, vars) {
  const name = new Map((discovery?.nodes ?? []).map((n) => [n.key, n.name]));
  const out = [
    `# Architecture: ${vars.PROJECT_TITLE}`, '',
    'Generated by `automation-scaffold` from a read-only discovery. Every link below cites where it',
    'was found: the artifact, the JSON path inside it and the value. Nothing is inferred from names.', '',
    'Scope follows the event chain: what the starting artifact writes, the flows those writes trigger,',
    'and what those flows call. A list that is only read is listed but not followed further.', '',
  ];
  if (!discovery) return [...out, '_No discovery was run._', ''].join('\n');
  out.push(`Discovery: ${discovery.generatedAt}, starting from ${discovery.seeds.map((s) => `"${s.query}"`).join(', ')}, depth ${discovery.depth}.`);
  out.push(`Examined: ${discovery.examined.apps} apps, ${discovery.examined.flows} flows, ${discovery.examined.n8nWorkflows} n8n workflows, ${discovery.examined.makeScenarios} Make scenarios.`, '');
  if (discovery.skipped?.length) out.push('Not examined:', ...discovery.skipped.map((s) => `- ${s}`), '');
  out.push(mermaid(discovery), '', '## Artifacts', '', '| Artifact | Kind | Component | Platform IDs |', '|---|---|---|---|');
  for (const n of discovery.nodes) {
    const c = components.find((x) => x.key === n.key);
    const ids = Object.entries(n.platform ?? {}).filter(([, v]) => v).map(([k, v]) => `${k} \`${v}\``).join('<br/>');
    out.push(`| ${n.name} | ${n.kind} | ${c ? `\`${c.id}\`` : (n.kind === 'zapier-hook' ? 'documented only (no export API)' : '—')} | ${ids || '—'} |`);
  }
  out.push('', '## Links and evidence', '', '| From | Link | To | Evidence (artifact · path · value) |', '|---|---|---|---|');
  for (const e of discovery.edges) {
    const ev = e.evidence.map((x) => `\`${x.artifact}\` · \`${x.path}\` · \`${String(x.value).replace(/\|/g, '\\|')}\``
      + (x.target ? ` → \`${x.target}\`` : '')
      + (x.write ? `<br/>write: \`${x.write.replace(/\|/g, '\\|')}\`` : '')
      + (x.operationId ? ` · operation \`${x.operationId}\`` : '')).join('<br/>');
    out.push(`| ${name.get(e.from)} | ${e.relation} | ${name.get(e.to)} | ${ev} |`);
  }
  out.push('');
  return out.join('\n');
}

function main() {
  const a = args();
  const config = fs.existsSync(CONFIG_FILE) ? JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8')) : {};
  const discovery = a.discovery ? JSON.parse(fs.readFileSync(a.discovery, 'utf8')) : null;
  const title = a.title ?? a.name.split('-').map((w) => w[0].toUpperCase() + w.slice(1)).join(' ');

  // Components from discovery, merged with any already registered.
  fs.mkdirSync(a.dir, { recursive: true });
  const regFile = path.join(a.dir, 'releases', 'components.json');
  const existing = fs.existsSync(regFile) ? JSON.parse(fs.readFileSync(regFile, 'utf8')).components : [];
  const components = existing.map((c) => ({ ...c }));
  const used = new Set(components.map((c) => c.id));
  const known = new Map(components.map((c) => [JSON.stringify(c.platform), c]));
  for (const n of discovery?.nodes ?? []) {
    const k = KIND[n.kind];
    if (!k) continue;
    const prior = known.get(JSON.stringify(n.platform));
    if (prior) { prior.key = n.key; continue; }
    const slug = componentSlug(n.name, a.name);
    let id = `${k.prefix}-${slug}`;
    for (let i = 2; used.has(id); i++) id = `${k.prefix}-${slug}-${i}`;
    used.add(id);
    const folder = k.dir(id.slice(k.prefix.length + 1), folderName(id.slice(k.prefix.length + 1)));
    components.push({ key: n.key, id, kind: n.kind, displayName: n.name, path: folder, platform: Object.fromEntries(Object.entries(n.platform).filter(([, v]) => v)) });
  }

  const description = a.description ?? describe(title, components);
  const systems = [
    config.powerPlatform?.environmentId && `Power Platform environment \`${config.powerPlatform.environmentName ?? 'default'}\` (\`${config.powerPlatform.environmentId}\`)`,
    config.n8n?.url && `n8n ${config.n8n.url}`,
    config.make?.zone && `Make.com ${config.make.zone}`,
  ].filter(Boolean);
  const kinds = new Set(components.map((c) => c.kind));
  const badge = (label, text, color) => `![${label}](https://img.shields.io/badge/${encodeURIComponent(label).replace(/-/g, '--')}-${encodeURIComponent(text)}-${color})`;
  const badges = [
    kinds.has('canvas-app') && badge('Power Apps', 'canvas app', '742774'),
    kinds.has('cloud-flow') && badge('Power Automate', 'cloud flows', '0066FF'),
    kinds.has('n8n-workflow') && badge('n8n', 'workflows', 'EA4B71'),
    kinds.has('make-scenario') && badge('Make', 'scenarios', '6D00CC'),
  ].filter(Boolean).join('\n');
  const vars = {
    PROJECT_SLUG: a.name,
    PROJECT_TITLE: title,
    DESCRIPTION: description,
    SYSTEMS_LINE: systems.length ? systems.join(' · ') : 'none configured yet (see project.json)',
    POWER_PLATFORM_LINE: config.powerPlatform?.environmentId
      ? `\`${config.powerPlatform.environmentName ?? 'default'}\` (\`${config.powerPlatform.environmentId}\`). Treat it as production unless docs/environment.md says otherwise.`
      : 'No environment configured yet; set it in project.json.',
    N8N_LINE: config.n8n?.url ? `n8n instance: ${config.n8n.url}` : 'No n8n instance configured yet; set it in project.json.',
    MAKE_LINE: config.make?.zone ? `Make zone: ${config.make.zone}` : 'No Make zone configured yet; set it in project.json.',
    DATE: new Date().toISOString().slice(0, 10),
    SEEDS: discovery ? discovery.seeds.map((s) => `"${s.query}"`).join(', ') : 'none',
    BADGES: badges,
    ARCHITECTURE_MERMAID: mermaid(discovery),
    COMPONENTS_TABLE: components.length
      ? ['| Component | Kind | Platform name | Folder |', '|---|---|---|---|', ...components.map((c) => `| \`${c.id}\` | ${KIND[c.kind]?.label ?? c.kind} | ${c.displayName} | \`${c.path}\` |`)].join('\n')
      : '_None yet. Add components as described in docs/RELEASE.md._',
  };

  // Render the template.
  const written = [];
  const kept = [];
  for (const rel of walk(TEMPLATE)) {
    const dest = path.join(a.dir, rel);
    if (fs.existsSync(dest) && !(a.force && rel !== 'releases/components.json')) { kept.push(rel); continue; }
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    const src = path.join(TEMPLATE, rel);
    fs.writeFileSync(dest, fill(fs.readFileSync(src, 'utf8'), vars));
    fs.chmodSync(dest, fs.statSync(src).mode);
    written.push(rel);
  }

  // project.json: IDs and URLs only.
  const projectFile = path.join(a.dir, 'project.json');
  if (!fs.existsSync(projectFile) || a.force) {
    const project = {
      name: a.name,
      // The GitHub repository's About: applied by `publish about` (and after the PR merges).
      github: { repo: a.repo ?? null, description, topics: topicsFor(components) },
      powerPlatform: config.powerPlatform?.environmentId ? { environmentId: config.powerPlatform.environmentId, environmentName: config.powerPlatform.environmentName ?? null } : undefined,
      n8n: config.n8n?.url ? { url: config.n8n.url, keychainItem: config.n8n.keychainItem ?? null } : undefined,
      make: config.make?.zone ? { zone: config.make.zone, teamId: config.make.teamId ?? null, keychainItem: config.make.keychainItem ?? null } : undefined,
    };
    fs.writeFileSync(projectFile, `${JSON.stringify(project, null, 2)}\n`);
    written.push('project.json');
  } else kept.push('project.json');

  // Registry and component folders.
  fs.mkdirSync(path.dirname(regFile), { recursive: true });
  const registry = { $schema: './components.schema.json', components: components.map(({ key, ...c }) => c) };
  fs.writeFileSync(regFile, `${JSON.stringify(registry, null, 2)}\n`);
  for (const c of components) {
    const dir = path.join(a.dir, c.path);
    fs.mkdirSync(dir, { recursive: true });
    const pkg = path.join(dir, 'package.json');
    if (!fs.existsSync(pkg)) {
      const base = path.relative(dir, path.join(a.dir, 'release.base.cjs')).split(path.sep).join('/');
      fs.writeFileSync(pkg, `${JSON.stringify({ name: c.id, version: '0.0.0', private: true, release: { extends: ['semantic-release-monorepo', base] } }, null, 2)}\n`);
      written.push(path.relative(a.dir, pkg));
    }
  }

  // Generated documents (always refreshed: they describe the current discovery).
  fs.mkdirSync(path.join(a.dir, 'docs'), { recursive: true });
  fs.writeFileSync(path.join(a.dir, 'docs', 'architecture.md'), architectureDoc(discovery, components, vars));
  const env = [
    `# Environment: ${title}`, '',
    '| System | Value |', '|---|---|',
    `| Power Platform | ${config.powerPlatform?.environmentId ? `${config.powerPlatform.environmentName ?? ''} \`${config.powerPlatform.environmentId}\`` : 'not configured'} |`,
    `| n8n | ${config.n8n?.url ?? 'not configured'} |`,
    `| Make.com | ${config.make?.zone ?? 'not configured'} |`,
    `| GitHub | ${a.repo ? `\`${a.repo}\`` : 'not recorded'} |`, '',
    'Secrets are never stored here. Scripts read them at run time: Azure through `az login`,',
    'n8n from `N8N_API_KEY` or the Keychain item in `project.json`, Make from `MAKE_API_TOKEN` or its Keychain item.', '',
  ].join('\n');
  fs.writeFileSync(path.join(a.dir, 'docs', 'environment.md'), env);
  written.push('docs/architecture.md', 'docs/environment.md');

  // Export and pin every component (read-only on the platforms).
  const results = [];
  if (a.export) {
    for (const c of components) {
      const run = (script, ...rest) => execFileSync('node', [path.join(a.dir, 'scripts', script), ...rest], { cwd: a.dir, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
      try {
        const exp = run('export.js', c.id);
        const pin = run('release-pin.js', 'pin', c.id);
        results.push({ id: c.id, ok: true, export: exp, pin });
        log(`${exp}\n${pin}`);
      } catch (e) {
        results.push({ id: c.id, ok: false, error: String(e.stderr || e.message).trim() });
        log(`${c.id}: export/pin failed: ${String(e.stderr || e.message).trim()}`);
      }
    }
  }

  const summary = { dir: a.dir, name: a.name, components: registry.components, written: written.length, kept, exports: results };
  process.stdout.write(`${JSON.stringify(summary, null, 2)}\n`);
  log(`Scaffolded ${a.dir}: ${written.length} file(s) written, ${kept.length} kept, ${components.length} component(s)`
    + (a.export ? `, ${results.filter((r) => r.ok).length} exported and pinned` : ''));
  if (results.some((r) => !r.ok)) process.exitCode = 1;
}

if (require.main === module) {
  try { main(); } catch (e) { console.error(`scaffold: ${e.message}`); process.exitCode = 1; }
}

module.exports = { slugify, componentSlug, describe, topicsFor };
