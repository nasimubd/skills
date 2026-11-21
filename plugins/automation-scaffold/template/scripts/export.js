#!/usr/bin/env node
// Export a registered component's production source into its folder (read-only on the
// platform). Secrets are redacted and n8n pinData/staticData are dropped before anything
// is written.
//
//   node scripts/export.js <id>     one component
//   node scripts/export.js --all    every component in releases/components.json
//
// Writes, per kind:
//   canvas-app     <path>/src/Src/**/*.pa.yaml   (the live published version)
//   cloud-flow     <path>/definition.json, <path>/manifest.json
//   n8n-workflow   <path>/workflow.json          (the published version when there is one)
//   make-scenario  <path>/blueprint.json

'use strict';

const fs = require('fs');
const path = require('path');
const P = require('./lib/platform');

const write = (file, data) => {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, typeof data === 'string' ? data : `${JSON.stringify(data, null, 2)}\n`);
};

const EXPORTERS = {
  async 'canvas-app'(c, dir) {
    const app = await P.liveApp(c.platform.appId);
    const src = path.join(dir, 'src');
    fs.rmSync(path.join(src, 'Src'), { recursive: true, force: true });
    for (const f of app.files) write(path.join(src, f.name), f.text.replace(/\r\n/g, '\n'));
    return `${app.files.length} .pa.yaml file(s) @ ${app.version}`;
  },
  async 'cloud-flow'(c, dir) {
    const f = await P.liveFlow(c.platform.environmentId, c.platform.flowId);
    write(path.join(dir, 'definition.json'), P.redactEverywhere(f.definition));
    const triggers = Object.entries(f.definition?.triggers ?? {}).map(([name, t]) => ({ name, type: t.type, kind: t.kind ?? null }));
    const connections = Object.entries(f.connectionReferences).map(([name, r]) => ({
      name, api: r.apiName ?? r.api?.name ?? r.id ?? null, connectionReference: r.connectionReferenceLogicalName ?? null,
    }));
    write(path.join(dir, 'manifest.json'), { displayName: f.displayName, state: f.state, triggers, connections });
    return `definition + manifest @ ${f.version}`;
  },
  async 'n8n-workflow'(c, dir) {
    const n = await P.liveN8n(P.loadProject(), c.platform.workflowId);
    write(path.join(dir, 'workflow.json'), P.n8nExport(n.workflow));
    return `workflow @ ${n.version ?? 'unpublished'} (pinData stripped, secrets redacted)`;
  },
  async 'make-scenario'(c, dir) {
    const m = await P.liveMake(P.loadProject(), c.platform.scenarioId);
    write(path.join(dir, 'blueprint.json'), P.redactEverywhere(m.blueprint));
    return `blueprint @ ${m.version ?? 'unknown'}`;
  },
};

async function exportOne(c) {
  const run = EXPORTERS[c.kind];
  if (!run) throw new Error(`${c.id}: kind "${c.kind}" cannot be exported`);
  const summary = await run(c, path.join(P.ROOT, c.path));
  console.log(`${c.id}: ${summary} -> ${c.path}`);
}

async function main() {
  const arg = process.argv[2];
  const all = JSON.parse(fs.readFileSync(path.join(P.ROOT, 'releases', 'components.json'), 'utf8')).components;
  if (!arg) { console.error('usage: export.js <id> | --all'); process.exitCode = 2; return; }
  const targets = arg === '--all' ? all : all.filter((c) => c.id === arg);
  if (!targets.length) throw new Error(`unknown component "${arg}"`);
  for (const c of targets) await exportOne(c);
  console.log(`Exported ${targets.length} component(s).`);
}

if (require.main === module) main().catch((e) => { console.error(`export: ${e.message}`); process.exitCode = 1; });

module.exports = { exportOne };
