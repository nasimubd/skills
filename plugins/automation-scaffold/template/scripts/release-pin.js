#!/usr/bin/env node
// Production pins (docs/RELEASE.md). Read-only on every platform.
//
//   node scripts/release-pin.js pin <id>    record what is live -> <path>/release.lock.json
//   node scripts/release-pin.js verify      compare production with every pin; exit 1 on drift
//   node scripts/release-pin.js check <id>  exit 0 only when the committed source matches the pin
//                                           (the release gate in scripts/release.sh)
//
// A digest covers what decides behaviour and nothing that changes on every export, and is
// computed the same way from git and from production, so "same digest" means "same thing":
//   canvas-app     Src/**/*.pa.yaml except _EditorState.pa.yaml, LF line endings
//   cloud-flow     definition without description, save-time defaults added, secrets redacted, keys sorted
//   n8n-workflow   nodes, connections and settings, secrets redacted, keys sorted
//   make-scenario  blueprint flow and metadata (without its version), secrets redacted, keys sorted
// Nothing is printed or written except IDs, versions and digests.

'use strict';

const fs = require('fs');
const path = require('path');
const P = require('./lib/platform');

const REGISTRY = path.join(P.ROOT, 'releases', 'components.json');
const components = () => JSON.parse(fs.readFileSync(REGISTRY, 'utf8')).components;
const lockPath = (c) => path.join(P.ROOT, c.path, 'release.lock.json');
const short = (d) => (d ? d.slice(0, 12) : 'none');
const readJson = (f) => (fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, 'utf8')) : null);

const KINDS = {
  'canvas-app': {
    covers: 'Src/**/*.pa.yaml except _EditorState.pa.yaml, LF line endings',
    source(c) {
      const dir = path.join(P.ROOT, c.path, 'src', 'Src');
      if (!fs.existsSync(dir)) return null;
      const files = fs.readdirSync(dir, { recursive: true })
        .map((f) => `Src/${String(f).split(path.sep).join('/')}`)
        .filter(P.isAppSource)
        .map((name) => ({ name, text: fs.readFileSync(path.join(dir, name.slice(4)), 'utf8') }));
      return P.digestFiles(files);
    },
    async live(c) {
      const app = await P.liveApp(c.platform.appId);
      return { version: app.version, at: app.at, digest: P.digestFiles(app.files) };
    },
  },
  'cloud-flow': {
    covers: 'definition without description, save-time defaults added, secrets redacted, keys sorted',
    source(c) {
      const def = readJson(path.join(P.ROOT, c.path, 'definition.json'));
      return def ? P.sha256(P.canonical(P.normalizeFlow(def.properties?.definition ?? def))) : null;
    },
    async live(c) {
      const f = await P.liveFlow(c.platform.environmentId, c.platform.flowId);
      return { version: f.version, at: f.at, state: f.state, digest: P.sha256(P.canonical(P.normalizeFlow(f.definition))) };
    },
  },
  'n8n-workflow': {
    covers: 'nodes, connections and settings, secrets redacted, keys sorted',
    source(c) {
      const wf = readJson(path.join(P.ROOT, c.path, 'workflow.json'));
      return wf ? P.sha256(P.canonical(P.n8nBehaviour(wf))) : null;
    },
    async live(c) {
      const n = await P.liveN8n(P.loadProject(), c.platform.workflowId);
      if (!n.version) throw new Error(`${c.id}: workflow has no published version`);
      return { version: n.version, at: n.at, active: n.active, digest: P.sha256(P.canonical(P.n8nBehaviour(P.n8nExport(n.workflow)))) };
    },
  },
  'make-scenario': {
    covers: 'blueprint flow and metadata without its version, secrets redacted, keys sorted',
    source(c) {
      const bp = readJson(path.join(P.ROOT, c.path, 'blueprint.json'));
      return bp ? P.sha256(P.canonical(P.makeBehaviour(bp))) : null;
    },
    async live(c) {
      const m = await P.liveMake(P.loadProject(), c.platform.scenarioId);
      return { version: m.version, at: m.at, active: m.active, digest: P.sha256(P.canonical(P.makeBehaviour(m.blueprint))) };
    },
  },
};

function find(id) {
  const c = components().find((x) => x.id === id);
  if (!c) throw new Error(`unknown component "${id}" (see releases/components.json)`);
  if (!KINDS[c.kind]) throw new Error(`${id}: kind "${c.kind}" has no pin support`);
  return c;
}

async function pin(id) {
  const c = find(id);
  const k = KINDS[c.kind];
  const live = await k.live(c);
  const lock = {
    component: c.id,
    platform: c.platform,
    live: { version: live.version, at: live.at, ...(live.state ? { state: live.state } : {}), ...(live.active !== undefined ? { active: live.active } : {}) },
    digest: { algorithm: 'sha256', value: live.digest, covers: k.covers },
    pinnedAt: new Date().toISOString(),
  };
  fs.writeFileSync(lockPath(c), `${JSON.stringify(lock, null, 2)}\n`);
  const src = k.source(c);
  const vs = src == null ? 'no source in git' : src === live.digest ? 'matches source in git' : 'DIFFERS from source in git';
  console.log(`${c.id}: pinned live ${live.version} sha256:${short(live.digest)} (${vs}) -> ${path.relative(P.ROOT, lockPath(c))}`);
}

async function verify() {
  let drift = 0;
  const all = components();
  for (const c of all) {
    const lock = readJson(lockPath(c));
    if (!lock) { console.log(`${c.id}\tNO PIN\trun: mise run release:pin ${c.id}`); drift++; continue; }
    const live = await KINDS[c.kind].live(c);
    const same = live.digest === lock.digest.value;
    const status = same ? (live.version === lock.live.version ? 'ok' : 'ok (re-saved, same content)') : 'DRIFT';
    if (!same) drift++;
    console.log(`${c.id}\t${status}\tpinned ${lock.live.version} sha256:${short(lock.digest.value)}\tlive ${live.version} sha256:${short(live.digest)}`);
  }
  console.log(`Checked ${all.length} component(s); ${drift} need attention.`);
  process.exitCode = drift ? 1 : 0;
}

function check(id) {
  const c = find(id);
  const lock = readJson(lockPath(c));
  if (!lock) { console.log(`${c.id}: no pin; run mise run release:pin ${c.id}`); process.exitCode = 1; return; }
  const src = KINDS[c.kind].source(c);
  if (src == null) { console.log(`${c.id}: no source in git; the release records the pin only`); return; }
  if (src !== lock.digest.value) {
    console.log(`${c.id}: source sha256:${short(src)} differs from pinned live sha256:${short(lock.digest.value)}; deploy and re-pin before releasing`);
    process.exitCode = 1;
    return;
  }
  console.log(`${c.id}: source matches the pinned live version ${lock.live.version}`);
}

async function main() {
  const [cmd, id] = process.argv.slice(2);
  if (cmd === 'pin' && id) return pin(id);
  if (cmd === 'verify') return verify();
  if (cmd === 'check' && id) return check(id);
  console.error('usage: release-pin.js pin <id> | verify | check <id>');
  process.exitCode = 2;
}

if (require.main === module) main().catch((e) => { console.error(`release-pin: ${e.message}`); process.exitCode = 1; });

module.exports = { KINDS };
