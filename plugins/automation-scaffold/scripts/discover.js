#!/usr/bin/env node
// Read-only discovery: start from one or more named artifacts (a canvas app, a cloud flow,
// an n8n workflow or a Make scenario) and follow the links between them, recording for
// every link the exact place it was found. Nothing is inferred from names alone.
//
//   discover.js --seed "<name or id>" [--seed ...] [--depth 4] [--exclude <name or id>]...
//               [--include-copies] [--out discovery.json]
//
// Traversal follows the event chain: forward along every link, and from a list only to the
// flows that list triggers. [OPT] and TEST - copies are left out unless --include-copies.
//
// Links (each with evidence = artifact + JSON path + value):
//   uses-list      app or flow → SharePoint list  (connection dataSets tableName / dataset+table)
//   touches-list   n8n workflow or Make scenario → list (the list id appears in its JSON)
//   calls-flow     app → flow (the flow id appears in the app) · flow → flow (child flow)
//   calls-webhook  flow/workflow/scenario → n8n workflow (URL path = webhook node path)
//   runs-workflow  n8n → n8n (Execute Workflow node)
//   calls-make     → Make scenario (hook URL = scenario's webhook)
//   calls-zapier   → Zapier hook (external, documented only)
//
// Configuration: ~/.config/automation-scaffold/config.json (written by the setup skill).
// PLATFORM_FIXTURES works as in template/scripts/lib/platform.js, for offline tests.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');

const CONFIG_FILE = path.join(process.env.AUTOMATION_SCAFFOLD_CONFIG_DIR || path.join(os.homedir(), '.config', 'automation-scaffold'), 'config.json');
const config = fs.existsSync(CONFIG_FILE) ? JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8')) : {};
if (config.azBin && !process.env.AZ_BIN) process.env.AZ_BIN = config.azBin;
const P = require('../template/scripts/lib/platform');

// Platforms discovery may query. Default: Power Apps, Power Automate and n8n only; Make is
// queried only when config.platforms lists "make". Make and Zapier URLs found inside a flow or
// workflow are still recorded, as external endpoints that were not examined.
const PLATFORMS = new Set(config.platforms ?? ['power-apps', 'power-automate', 'n8n']);

const GUID = /\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/gi;
const ZAPIER = /https:\/\/hooks\.zapier\.com\/hooks\/catch\/\d+\/[A-Za-z0-9]+\/?/g;
const MAKE_HOOK = /https:\/\/hook\.[a-z0-9.-]*make\.com\/[A-Za-z0-9]+/g;

function args() {
  const a = { seeds: [], depth: 4, out: null, exclude: [], includeCopies: false };
  const argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--seed') a.seeds.push(argv[++i]);
    else if (argv[i] === '--depth') a.depth = Number(argv[++i]);
    else if (argv[i] === '--out') a.out = argv[++i];
    else if (argv[i] === '--exclude') a.exclude.push(argv[++i]);
    else if (argv[i] === '--include-copies') a.includeCopies = true;
    else throw new Error(`unknown argument ${argv[i]}`);
  }
  if (!a.seeds.length) throw new Error('usage: discover.js --seed "<name or id>" [--seed ...] [--depth N] [--out file]');
  if (!Number.isInteger(a.depth) || a.depth < 0 || a.depth > 6) throw new Error('--depth must be 0-6');
  return a;
}

/** Every string leaf with its JSON path. */
function* strings(value, at = '$') {
  if (typeof value === 'string') yield [at, value];
  else if (Array.isArray(value)) for (let i = 0; i < value.length; i++) yield* strings(value[i], `${at}[${i}]`);
  else if (value && typeof value === 'object') for (const [k, v] of Object.entries(value)) yield* strings(v, `${at}.${/^[A-Za-z_$][\w$]*$/.test(k) ? k : JSON.stringify(k)}`);
}

/** Every object with its JSON path. */
function* objects(value, at = '$') {
  if (Array.isArray(value)) for (let i = 0; i < value.length; i++) yield* objects(value[i], `${at}[${i}]`);
  else if (value && typeof value === 'object') {
    yield [at, value];
    for (const [k, v] of Object.entries(value)) yield* objects(v, `${at}.${/^[A-Za-z_$][\w$]*$/.test(k) ? k : JSON.stringify(k)}`);
  }
}

const maskZapier = (u) => u.replace(/(catch\/\d+\/)[A-Za-z0-9]+/, '$1…');
const norm = (s) => String(s ?? '').trim().toLowerCase().replace(/\/+$/, '');

// ---------- inventory ----------

async function inventory() {
  const inv = { apps: [], flows: [], n8n: [], make: [], makeHooks: [], skipped: [] };
  const env = config.powerPlatform?.environmentId;

  if (env && PLATFORMS.has('power-apps')) {
    try {
      inv.apps = await P.getAll(`${P.PA_API}/apps?api-version=2016-11-01&$filter=environment%20eq%20%27${env}%27`, P.paAuth());
      // The list API gives data source titles only; the live package maps each to its site and list id.
      for (const a of inv.apps) {
        try {
          a.liveDataSources = await P.liveAppDataSources(a.name);
        } catch (e) { inv.skipped.push(`app ${a.properties?.displayName ?? a.name} data sources: ${e.message}`); }
      }
    } catch (e) { inv.skipped.push(`Power Apps: ${e.message}`); }
  }
  if (env && PLATFORMS.has('power-automate')) {
    try {
      const base = `${P.FLOW_API}/environments/${env}/flows?api-version=2016-11-01`;
      const listed = [...await P.getAll(base, P.flowAuth()), ...await P.getAll(`${base}&$filter=search('team')`, P.flowAuth())];
      const ids = [...new Set(listed.map((f) => f.name))];
      for (const id of ids) {
        try {
          const f = await P.getJson(`${P.FLOW_API}/environments/${env}/flows/${id}?api-version=2016-11-01`, P.flowAuth());
          inv.flows.push(f);
        } catch (e) { inv.skipped.push(`flow ${id}: ${e.message}`); }
      }
    } catch (e) { inv.skipped.push(`Power Automate: ${e.message}`); }
  }
  if (!env) inv.skipped.push('Power Platform: powerPlatform.environmentId not configured');

  if (config.n8n?.url && PLATFORMS.has('n8n')) {
    try {
      const base = P.n8nBase(config);
      inv.n8n = await P.getAll(`${base}/api/v1/workflows?limit=250`, P.n8nAuth(config), (b) => b.data ?? [],
        (b) => (b.nextCursor ? `${base}/api/v1/workflows?limit=250&cursor=${encodeURIComponent(b.nextCursor)}` : null));
    } catch (e) { inv.skipped.push(`n8n: ${e.message}`); }
  } else if (!config.n8n?.url) inv.skipped.push('n8n: n8n.url not configured');

  if (PLATFORMS.has('make') && config.make?.zone && config.make?.teamId) {
    try {
      const base = P.makeBase(config);
      const auth = P.makeAuth(config);
      const scenarios = (await P.getJson(`${base}/scenarios?teamId=${config.make.teamId}&pg%5Blimit%5D=500`, auth)).scenarios ?? [];
      for (const s of scenarios) {
        const bp = await P.getJson(`${base}/scenarios/${s.id}/blueprint`, auth);
        inv.make.push({ ...s, blueprint: bp.response?.blueprint ?? bp.response ?? {} });
      }
      inv.makeHooks = (await P.getJson(`${base}/hooks?teamId=${config.make.teamId}`, auth)).hooks ?? [];
    } catch (e) { inv.skipped.push(`Make: ${e.message}`); }
  }

  return inv;
}

// ---------- reads and writes ----------

/** SharePoint connector operations that change a list (anything else on a list reads it). */
const WRITE_OP = /^(Post|Patch|Put|Delete|Update|Create|Add|Copy|Move|Set|CheckIn|CheckOut|Discard|Approve|Grant|Stop|Rename)/i;

/**
 * Data sources an app writes, from its live .pa.yaml: Patch/Collect/Remove/RemoveIf/UpdateIf
 * on the source, or a form bound to it (forms submit to their DataSource). Formulas often
 * break lines after "(", so the search runs over whole files. Returns name → first evidence.
 */
function appWrites(sources) {
  const out = new Map();
  const note = (name, file, index, call, text) => {
    const key = norm(name.replace(/^'|'$/g, ''));
    if (!out.has(key)) out.set(key, { file, line: text.slice(0, index).split('\n').length, call });
  };
  for (const { name: file, text } of sources) {
    for (const m of text.matchAll(/\b(Patch|Collect|Remove|RemoveIf|UpdateIf)\(\s*('[^']+'|[A-Za-z_][A-Za-z0-9_]*)/g)) note(m[2], file, m.index, `${m[1]}(${m[2]}`, text);
    for (const m of text.matchAll(/\bDataSource:\s*=\s*('[^']+'|[A-Za-z_][A-Za-z0-9_]*)/g)) note(m[1], file, m.index, `form DataSource ${m[1]}`, text);
  }
  return out;
}

// ---------- graph ----------

function buildGraph(inv) {
  const nodes = new Map();
  const edges = new Map();
  const add = (key, node) => { if (!nodes.has(key)) nodes.set(key, { key, ...node }); return key; };
  const link = (from, to, relation, evidence) => {
    if (from === to) return;
    const k = `${from}|${relation}|${to}`;
    if (!edges.has(k)) edges.set(k, { from, to, relation, evidence: [] });
    const e = edges.get(k);
    if (e.evidence.length < 3) e.evidence.push(evidence);
  };
  const env = config.powerPlatform?.environmentId;

  const appKey = (a) => `app:${a.name}`;
  const flowKey = (f) => `flow:${f.name}`;
  const n8nKey = (w) => `n8n:${w.id}`;
  const makeKey = (s) => `make:${s.id}`;
  const listKey = (table) => `list:${norm(table)}`;

  for (const a of inv.apps) add(appKey(a), { kind: 'canvas-app', name: a.properties?.displayName ?? a.name, platform: { environmentId: env, appId: a.name } });
  for (const f of inv.flows) add(flowKey(f), { kind: 'cloud-flow', name: f.properties?.displayName ?? f.name, platform: { environmentId: env, flowId: f.name }, state: f.properties?.state });
  for (const w of inv.n8n) add(n8nKey(w), { kind: 'n8n-workflow', name: w.name, platform: { instance: config.n8n?.url, workflowId: w.id }, active: w.active });
  for (const s of inv.make) add(makeKey(s), { kind: 'make-scenario', name: s.name, platform: { zone: config.make?.zone, scenarioId: String(s.id) } });

  // Lists from apps: the live package's References/DataSources.json (site + list id per
  // connected data source); older app metadata with tableName under dataSets as a fallback.
  const lists = new Map();
  const addList = (site, table, name) => {
    const key = listKey(table);
    if (!lists.has(key)) lists.set(key, { site: site ?? null, table, name: name ?? null });
    const l = lists.get(key);
    if (!l.site && site) l.site = site;
    if (!l.name && name) l.name = name;
    add(key, { kind: 'sharepoint-list', name: l.name ?? table, platform: { site: l.site, list: table } });
    return key;
  };
  const DS_FILE = 'References/DataSources.json';
  for (const a of inv.apps) {
    const v = a.liveDataSources?.version;
    const writes = appWrites(a.liveDataSources?.sources ?? []);
    (a.liveDataSources?.dataSources ?? []).forEach((d, i) => {
      if (typeof d.TableName === 'string' && d.TableName && /sharepointonline/i.test(d.ApiId ?? '')) {
        const list = addList(d.DatasetName ?? null, d.TableName, d.Name ?? null);
        const w = writes.get(norm(d.Name));
        link(appKey(a), list, w ? 'writes-list' : 'reads-list',
          { artifact: `${appKey(a)} live ${v} ${DS_FILE}`, path: `$.DataSources[${i}].TableName`, value: d.TableName,
            ...(w ? { write: `${w.file}:${w.line} ${w.call}` } : {}) });
      }
    });
    for (const [at, o] of objects(a.properties ?? {}, '$.properties')) {
      if (typeof o.tableName === 'string') {
        const site = (at.match(/\.dataSets\."?(https?:[^".]+[^"]*)"?/) || [])[1] ?? null;
        const name = (at.match(/\.dataSources\.("?)([^".]+)\1$/) || [])[2] ?? null;
        link(appKey(a), addList(site, o.tableName, name), 'uses-list', { artifact: appKey(a), path: `${at}.tableName`, value: o.tableName });
      }
    }
  }
  // Lists from flows: steps whose inputs.parameters carry dataset + table. A list in the
  // trigger starts the flow (triggered-by); an action writes or reads it by its operationId.
  for (const f of inv.flows) {
    for (const [at, o] of objects(f.properties?.definition ?? {}, '$.properties.definition')) {
      const p = o.inputs?.parameters;
      if (typeof p?.dataset === 'string' && typeof p?.table === 'string' && !p.table.startsWith('@')) {
        const op = o.inputs?.host?.operationId ?? null;
        const relation = /\.triggers\.[^.]+$/.test(at) ? 'triggered-by' : WRITE_OP.test(op ?? '') ? 'writes-list' : op ? 'reads-list' : 'uses-list';
        link(flowKey(f), addList(p.dataset, p.table, null), relation,
          { artifact: flowKey(f), path: `${at}.inputs.parameters.table`, value: p.table, ...(op ? { operationId: op } : {}) });
      }
    }
  }
  const listGuids = [...lists.entries()].filter(([, l]) => /^[0-9a-f-]{36}$/i.test(l.table)).map(([k, l]) => [k, l.table.toLowerCase()]);

  // App → flow: the flow's id appears somewhere in the app.
  const flowIds = new Map(inv.flows.map((f) => [f.name.toLowerCase(), f]));
  for (const a of inv.apps) {
    const sources = [
      [a.properties ?? {}, '$.properties', appKey(a)],
      [{ DataSources: a.liveDataSources?.dataSources ?? [] }, '$', `${appKey(a)} live ${a.liveDataSources?.version} ${DS_FILE}`],
    ];
    for (const [json, root, artifact] of sources) {
      for (const [at, s] of strings(json, root)) {
        for (const g of s.match(GUID) ?? []) {
          const f = flowIds.get(g.toLowerCase());
          if (f) link(appKey(a), flowKey(f), 'calls-flow', { artifact, path: at, value: g });
        }
      }
    }
  }

  // Webhook targets.
  const n8nBase = config.n8n?.url ? norm(config.n8n.url) : null;
  const webhookPaths = new Map();
  for (const w of inv.n8n) {
    (w.nodes ?? []).forEach((n, i) => {
      if (/webhook/i.test(n.type ?? '') && n.parameters?.path) webhookPaths.set(norm(n.parameters.path), { w, at: `$.nodes[${i}].parameters.path` });
    });
  }
  const makeHooks = new Map(inv.makeHooks.map((h) => [norm(h.url), h]));
  const scenarioByHook = new Map();
  for (const s of inv.make) {
    for (const [at, o] of objects(s.blueprint, '$.blueprint')) {
      if (o.parameters && o.parameters.hook != null && /webhook/i.test(o.module ?? '')) scenarioByHook.set(String(o.parameters.hook), { s, at: `${at}.parameters.hook` });
    }
  }

  const scanOutbound = (fromKey, json, root) => {
    for (const [at, s] of strings(json, root)) {
      if (n8nBase && norm(s).includes(`${n8nBase}/webhook`)) {
        const m = norm(s).match(/\/webhook(?:-test)?\/([^?#\s"']+)/);
        const target = m && webhookPaths.get(norm(m[1]));
        if (target) link(fromKey, n8nKey(target.w), 'calls-webhook', { artifact: fromKey, path: at, value: `${config.n8n.url.replace(/\/+$/, '')}/webhook/${m[1]}`, target: `${n8nKey(target.w)} ${target.at}` });
      }
      for (const u of s.match(MAKE_HOOK) ?? []) {
        const hook = makeHooks.get(norm(u));
        const sc = hook && scenarioByHook.get(String(hook.id));
        if (sc) link(fromKey, makeKey(sc.s), 'calls-make', { artifact: fromKey, path: at, value: u, target: `${makeKey(sc.s)} ${sc.at}` });
        else link(fromKey, add(`external:${norm(u)}`, { kind: 'make-hook', name: u, platform: {}, note: 'external endpoint, not examined' }), 'calls-make', { artifact: fromKey, path: at, value: u });
      }
      for (const u of s.match(ZAPIER) ?? []) {
        const masked = maskZapier(u);
        link(fromKey, add(`zapier:${norm(masked)}`, { kind: 'zapier-hook', name: masked, platform: {}, note: 'external endpoint, not examined' }), 'calls-zapier', { artifact: fromKey, path: at, value: masked });
      }
      const low = s.toLowerCase();
      for (const [lk, g] of listGuids) if (low.includes(g) && !fromKey.startsWith('app:') && !fromKey.startsWith('flow:')) link(fromKey, lk, 'touches-list', { artifact: fromKey, path: at, value: g });
    }
  };
  for (const f of inv.flows) {
    scanOutbound(flowKey(f), f.properties?.definition ?? {}, '$.properties.definition');
    for (const [at, o] of objects(f.properties?.definition ?? {}, '$.properties.definition')) {
      const ref = o.host?.workflowReferenceName;
      if (o.type === 'Workflow' && ref && flowIds.has(String(ref).toLowerCase())) link(flowKey(f), flowKey(flowIds.get(String(ref).toLowerCase())), 'calls-flow', { artifact: flowKey(f), path: `${at}.host.workflowReferenceName`, value: ref });
    }
  }
  const n8nIds = new Map(inv.n8n.map((w) => [String(w.id), w]));
  for (const w of inv.n8n) {
    scanOutbound(n8nKey(w), { nodes: w.nodes ?? [] }, '$');
    (w.nodes ?? []).forEach((n, i) => {
      if (n.type === 'n8n-nodes-base.executeWorkflow') {
        const id = String(n.parameters?.workflowId?.value ?? n.parameters?.workflowId ?? '');
        if (n8nIds.has(id)) link(n8nKey(w), n8nKey(n8nIds.get(id)), 'runs-workflow', { artifact: n8nKey(w), path: `$.nodes[${i}].parameters.workflowId`, value: id });
      }
    });
  }
  for (const s of inv.make) scanOutbound(makeKey(s), s.blueprint, '$.blueprint');

  return { nodes, edges: [...edges.values()] };
}

function resolveSeed(seed, nodes) {
  const all = [...nodes.values()].filter((n) => !['sharepoint-list', 'zapier-hook', 'make-hook'].includes(n.kind));
  const s = norm(seed);
  const byId = all.filter((n) => Object.values(n.platform).some((v) => norm(v) === s));
  if (byId.length === 1) return byId[0].key;
  const exact = all.filter((n) => norm(n.name) === s);
  if (exact.length === 1) return exact[0].key;
  if (exact.length > 1) throw new Error(`seed "${seed}" matches ${exact.length} artifacts by name; use an id: ${exact.map((n) => `${n.name} (${n.key})`).join(', ')}`);
  const partial = all.filter((n) => norm(n.name).includes(s));
  if (partial.length === 1) return partial[0].key;
  if (partial.length > 1) throw new Error(`seed "${seed}" is ambiguous: ${partial.slice(0, 10).map((n) => `${n.name} (${n.key})`).join(', ')}`);
  throw new Error(`seed "${seed}" not found among ${all.length} apps, flows, workflows and scenarios`);
}

// Follow the event chain, not every shared reference:
//   forward along every link (app → list it uses, flow → what it calls or acts on, …);
//   backward only from a list to the flows it triggers (`triggered-by`).
// Never list → app: apps that share a list are siblings, not dependencies.
const COPY = /^\s*(\[OPT\]|TEST\s*-)/i;

function traverse(seedKeys, edges, depth, nodes, { exclude = [], includeCopies = false } = {}) {
  const skip = (k) => {
    const n = nodes.get(k);
    if (!n) return true;
    if (!includeCopies && COPY.test(n.name ?? '')) return true;
    return exclude.some((x) => norm(x) === norm(n.name) || Object.values(n.platform ?? {}).some((v) => norm(v) === norm(x)) || norm(x) === norm(k));
  };
  // A list continues the chain (to the flows it triggers) only when something kept in the
  // chain writes it. A list that is only read is documented and not expanded. A link whose
  // read/write is unknown (`uses-list`) counts as a write, so nothing is silently dropped.
  const WRITES = new Set(['writes-list', 'uses-list']);
  const dist = new Map(seedKeys.map((k) => [k, 0]));
  const written = new Set(seedKeys);
  const queue = [...seedKeys];
  while (queue.length) {
    const k = queue.shift();
    if (dist.get(k) >= depth) continue;
    for (const e of edges) {
      let other = null;
      if (e.from === k && e.relation !== 'triggered-by') other = e.to;
      else if (e.to === k && e.relation === 'triggered-by' && written.has(k)) other = e.from;
      if (!other || skip(other)) continue;
      if (e.from === k && WRITES.has(e.relation) && !written.has(other)) {
        written.add(other);
        if (dist.has(other)) queue.push(other); // reached earlier as read-only: expand it now
      }
      if (!dist.has(other)) { dist.set(other, dist.get(k) + 1); queue.push(other); }
    }
  }
  return dist;
}

async function main() {
  const a = args();
  const inv = await inventory();
  const { nodes, edges } = buildGraph(inv);
  const seedKeys = a.seeds.map((s) => resolveSeed(s, nodes));
  const dist = traverse(seedKeys, edges, a.depth, nodes, { exclude: a.exclude, includeCopies: a.includeCopies });
  const keep = new Set(dist.keys());
  const result = {
    generatedAt: new Date().toISOString(),
    seeds: a.seeds.map((s, i) => ({ query: s, key: seedKeys[i] })),
    depth: a.depth,
    excluded: { copies: !a.includeCopies, names: a.exclude },
    examined: { apps: inv.apps.length, flows: inv.flows.length, n8nWorkflows: inv.n8n.length, makeScenarios: inv.make.length },
    skipped: inv.skipped,
    nodes: [...keep].map((k) => ({ ...nodes.get(k), distance: dist.get(k) })).sort((x, y) => x.distance - y.distance || x.kind.localeCompare(y.kind) || x.name.localeCompare(y.name)),
    edges: edges.filter((e) => keep.has(e.from) && keep.has(e.to)),
  };
  const text = `${JSON.stringify(result, null, 2)}\n`;
  if (a.out) fs.writeFileSync(a.out, text); else process.stdout.write(text);

  const log = (s) => process.stderr.write(`${s}\n`);
  log(`Platforms queried: ${[...PLATFORMS].join(', ')}`);
  log(`Examined: ${result.examined.apps} apps, ${result.examined.flows} flows, ${result.examined.n8nWorkflows} n8n workflows, ${result.examined.makeScenarios} Make scenarios`);
  for (const s of inv.skipped) log(`  skipped: ${s}`);
  log(`Found ${result.nodes.length} related artifact(s) and ${result.edges.length} link(s) within depth ${a.depth}:`);
  for (const n of result.nodes) log(`  [${n.distance}] ${n.kind.padEnd(15)} ${n.name}`);
}

if (require.main === module) main().catch((e) => { console.error(`discover: ${e.message}`); process.exitCode = 1; });

module.exports = { buildGraph, resolveSeed, traverse, strings };
