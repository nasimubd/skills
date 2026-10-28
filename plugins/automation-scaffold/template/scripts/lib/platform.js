// Shared platform access for this repository's scripts: tokens, HTTP, digests and
// redaction for Power Apps, Power Automate, n8n and Make.com. Read-only: nothing in
// this file writes to a platform.
//
// Configuration comes from project.json at the repository root (IDs and URLs only,
// never secrets). Secrets come from environment variables or the macOS Keychain at
// run time and are never printed or written:
//   Azure (Power Platform)  `az account get-access-token` (az login once)
//   n8n                     N8N_API_KEY, else Keychain item project.json n8n.keychainItem
//   Make.com                MAKE_API_TOKEN, else Keychain item project.json make.keychainItem
//
// PLATFORM_FIXTURES=<dir> replaces every network call with files from <dir>/routes.json
// ([{ "match": "<url substring>", "file": "<file>" }]); it exists for offline tests.

'use strict';

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..', '..');

const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

/** JSON with object keys sorted at every level, so equal content always hashes equally. */
function canonical(value) {
  if (Array.isArray(value)) return `[${value.map(canonical).join(',')}]`;
  if (value && typeof value === 'object') {
    return `{${Object.keys(value).sort().map((k) => `${JSON.stringify(k)}:${canonical(value[k])}`).join(',')}}`;
  }
  return JSON.stringify(value === undefined ? null : value);
}

function loadProject(root = ROOT) {
  const file = path.join(root, 'project.json');
  if (!fs.existsSync(file)) return {};
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

// ---------- fixtures (offline tests only) ----------

const FIXTURES = process.env.PLATFORM_FIXTURES;

function fixtureFor(url) {
  const routes = JSON.parse(fs.readFileSync(path.join(FIXTURES, 'routes.json'), 'utf8'));
  const hit = routes.find((r) => url.includes(r.match));
  if (!hit) throw new Error(`fixture: no route for ${url}`);
  return path.join(FIXTURES, hit.file);
}

// ---------- credentials ----------

function azToken(resource, azBin = process.env.AZ_BIN || loadProject().azBin || 'az') {
  if (FIXTURES) return 'fixture-token';
  try {
    return execFileSync(azBin, ['account', 'get-access-token', '--resource', resource, '--query', 'accessToken', '-o', 'tsv'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    throw new Error(`no Azure token for ${resource}; run: az login`);
  }
}

function keychainSecret(envVar, item, what) {
  if (FIXTURES) return 'fixture-secret';
  if (process.env[envVar]) return process.env[envVar].trim();
  if (!item) throw new Error(`${what}: set ${envVar} or name a Keychain item in project.json`);
  let out;
  try {
    out = execFileSync('security', ['find-generic-password', '-a', process.env.USER ?? '', '-s', item, '-w'],
      { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim();
  } catch {
    throw new Error(`${what}: Keychain item "${item}" not found for account ${process.env.USER}; set ${envVar} or add the item`);
  }
  // `security -w` prints the value hex-encoded when it holds a non-printable byte (for example
  // a newline pasted with the key). Decode it, as the n8n export scripts in use already do.
  if (/^[0-9a-f]+$/.test(out) && out.length % 2 === 0 && !out.includes('.')) out = Buffer.from(out, 'hex').toString('utf8');
  return out.replace(/\s+/g, '');
}

// ---------- HTTP ----------

async function getJson(url, headers = {}) {
  if (FIXTURES) return JSON.parse(fs.readFileSync(fixtureFor(url), 'utf8'));
  for (let attempt = 1; ; attempt++) {
    const res = await fetch(url, { headers: { Accept: 'application/json', ...headers } });
    if ((res.status === 429 || res.status >= 500) && attempt < 4) {
      await new Promise((r) => setTimeout(r, 1000 * Number(res.headers.get('retry-after') || attempt * 2)));
      continue;
    }
    if (!res.ok) throw new Error(`GET ${url.split('?')[0]}: HTTP ${res.status}`);
    return res.json();
  }
}

async function getBytes(url) {
  if (FIXTURES) return fs.readFileSync(fixtureFor(url));
  const res = await fetch(url);
  if (!res.ok) throw new Error(`download failed: HTTP ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}

/** Follow `nextLink` / `@odata.nextLink` / `nextCursor` paging and return every item. */
async function getAll(url, headers, pick = (b) => b.value ?? b.data ?? [], next = (b) => b.nextLink ?? b['@odata.nextLink']) {
  const out = [];
  for (let u = url; u; ) {
    const body = await getJson(u, headers);
    out.push(...pick(body));
    u = next(body, u);
  }
  return out;
}

// ---------- redaction ----------

const SECRET_KEY = /authorization|api[-_]?key|apikey|token|secret|password|passwd|client[-_]?secret|x-[a-z-]*key/i;
const SECRET_SHAPES = [/Bearer\s+[A-Za-z0-9._~+/-]{20,}=*/g, /eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{5,}/g];

/**
 * Deep copy with secrets replaced: any literal string under a secret-looking key, and any
 * bearer token or JWT anywhere. Expressions (n8n "=..." and Power Automate "@...") are kept,
 * because they reference a secret rather than contain one.
 */
function redact(value, key = '') {
  if (Array.isArray(value)) return value.map((v) => redact(v, key));
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([k, v]) => {
      // Header arrays as [{name, value}] (n8n HTTP node)
      if (k === 'value' && typeof value.name === 'string' && SECRET_KEY.test(value.name)) return [k, redactLiteral(v, value.name)];
      return [k, redact(v, k)];
    }));
  }
  if (typeof value === 'string') {
    if (SECRET_KEY.test(key)) return redactLiteral(value, key);
    let s = value;
    for (const re of SECRET_SHAPES) s = s.replace(re, '{{REDACTED:bearer-or-jwt}}');
    return s;
  }
  return value;
}

/**
 * redact() plus a second pass: every literal secret found under a secret-looking name is also
 * removed wherever else the same value appears (another node, a URL, a body), as the n8n export
 * scripts already in use do. Values shorter than 12 characters are left to the first pass.
 */
function redactEverywhere(value) {
  const secrets = new Set();
  const collect = (v, key = '') => {
    if (Array.isArray(v)) v.forEach((x) => collect(x, key));
    else if (v && typeof v === 'object') {
      for (const [k, x] of Object.entries(v)) {
        if (k === 'value' && typeof v.name === 'string' && SECRET_KEY.test(v.name)) collect(x, v.name);
        else collect(x, k);
      }
    } else if (typeof v === 'string' && SECRET_KEY.test(key) && v.length >= 12 && !/^[=@]|^\{\{REDACTED/.test(v)) secrets.add(v);
  };
  collect(value);
  let text = JSON.stringify(redact(value));
  for (const s of secrets) text = text.split(JSON.stringify(s).slice(1, -1)).join('{{REDACTED:secret}}');
  return JSON.parse(text);
}

function redactLiteral(v, name) {
  if (typeof v !== 'string') return v;
  if (v.startsWith('=') || v.startsWith('@') || v.startsWith('{{REDACTED')) return v;
  return v.length ? `{{REDACTED:${String(name).toLowerCase()}}}` : v;
}

// ---------- per-kind normalisation and digests ----------

const isAppSource = (name) => /^Src\/.+\.pa\.yaml$/.test(name) && !name.endsWith('_EditorState.pa.yaml');

/** Digest over named text files: name + content hash, sorted by name, LF line endings. */
function digestFiles(files) {
  const lines = files
    .map(({ name, text }) => ({ name, text: text.replace(/\r\n/g, '\n') }))
    .sort((a, b) => (a.name < b.name ? -1 : 1))
    .map(({ name, text }) => `${name}\0${sha256(text)}\n`);
  return sha256(lines.join(''));
}

/**
 * A flow definition as it decides behaviour: without its description, with the defaults
 * Power Automate adds on save filled in (so a definition hashes the same before and after a
 * save), and secrets redacted.
 */
function normalizeFlow(def) {
  const d = JSON.parse(JSON.stringify(def ?? {}));
  delete d.description;
  const auth = "@parameters('$authentication')";
  const fill = (step) => {
    if (step?.type === 'OpenApiConnection' && step.inputs && !step.inputs.authentication) step.inputs.authentication = auth;
  };
  const walkActions = (actions) => {
    for (const a of Object.values(actions ?? {})) {
      fill(a);
      walkActions(a.actions);
      walkActions(a.else?.actions);
      for (const c of Object.values(a.cases ?? {})) walkActions(c.actions);
      walkActions(a.default?.actions);
    }
  };
  walkActions(d.actions);
  for (const t of Object.values(d.triggers ?? {})) {
    fill(t);
    if (t.recurrence && !t.evaluatedRecurrence) t.evaluatedRecurrence = t.recurrence;
  }
  return redactEverywhere(d);
}

const n8nBehaviour = (wf) => redactEverywhere({ nodes: wf.nodes ?? [], connections: wf.connections ?? {}, settings: wf.settings ?? {} });

/** What an n8n export keeps: the published version when there is one, never pinData or staticData. */
function n8nExport(wf) {
  const v = wf.activeVersion?.nodes ? wf.activeVersion : wf;
  return redactEverywhere({
    id: wf.id,
    name: wf.name,
    exportedVersionId: wf.activeVersionId ?? wf.versionId ?? null,
    active: wf.active ?? false,
    settings: wf.settings ?? {},
    tags: (wf.tags ?? []).map((t) => t.name ?? t),
    nodes: v.nodes ?? [],
    connections: v.connections ?? {},
  });
}

const makeBehaviour = (bp) => redactEverywhere({ flow: bp.flow ?? [], metadata: { ...(bp.metadata ?? {}), version: undefined } });

// ---------- platform endpoints ----------

const PA_API = 'https://api.powerapps.com/providers/Microsoft.PowerApps';
const FLOW_API = 'https://api.flow.microsoft.com/providers/Microsoft.ProcessSimple';
const PA_RESOURCE = 'https://service.powerapps.com/';
const FLOW_RESOURCE = 'https://service.flow.microsoft.com/';

const paAuth = () => ({ Authorization: `Bearer ${azToken(PA_RESOURCE)}` });
const flowAuth = () => ({ Authorization: `Bearer ${azToken(FLOW_RESOURCE)}` });

function n8nBase(project) {
  const url = project.n8n?.url;
  if (!url) throw new Error('project.json n8n.url is not set');
  return url.replace(/\/+$/, '');
}
const n8nAuth = (project) => ({ 'X-N8N-API-KEY': keychainSecret('N8N_API_KEY', project.n8n?.keychainItem, 'n8n API key') });

function makeBase(project) {
  const zone = project.make?.zone;
  if (!zone) throw new Error('project.json make.zone is not set (e.g. eu1.make.com)');
  return `https://${zone.replace(/^https?:\/\//, '')}/api/v2`;
}
const makeAuth = (project) => ({ Authorization: `Token ${keychainSecret('MAKE_API_TOKEN', project.make?.keychainItem, 'Make API token')}` });

/** Unzip the .pa.yaml sources out of an .msapp held in memory. */
function appFilesFromMsapp(bytes) {
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'msapp-'));
  try {
    const file = path.join(tmp, 'app.msapp');
    fs.writeFileSync(file, bytes);
    // Power Apps writes entry names with backslashes (`Src\App.pa.yaml`). Normalise the name
    // for matching and for the digest, but extract by the archive's own name; unzip treats a
    // backslash in its argument as an escape, so it is doubled.
    const entries = execFileSync('unzip', ['-Z1', file], { encoding: 'utf8' }).split('\n').filter(Boolean)
      .map((raw) => ({ raw, name: raw.replace(/\\/g, '/') })).filter((e) => isAppSource(e.name));
    return entries.map(({ raw, name }) => ({
      name,
      text: execFileSync('unzip', ['-p', file, raw.replace(/\\/g, '\\\\')], { maxBuffer: 64 * 1024 * 1024 }).toString('utf8'),
    }));
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

/**
 * The live version and its package bytes. The versions API returns the package link signed at
 * publish time, which expires seven days later (an older app then fails with HTTP 403). The app
 * endpoint signs the same blob afresh, so download from there, after checking it is the live
 * version's blob.
 */
async function livePackage(appId) {
  const { value } = await getJson(`${PA_API}/apps/${appId}/versions?api-version=2016-11-01`, paAuth());
  const live = (value ?? []).find((v) => v.isLive);
  if (!live) return null;
  const app = await getJson(`${PA_API}/apps/${appId}?api-version=2016-11-01`, paAuth());
  const blob = (u) => (u ? new URL(u).pathname : null);
  const fresh = app.properties?.appUris?.documentUri?.value;
  if (!fresh || blob(fresh) !== blob(live.properties.appDefinition.properties.appUris?.documentUri?.value)) {
    throw new Error(`app ${appId}: the app's package is not the live version ${live.name}`);
  }
  return { live, bytes: await getBytes(fresh) };
}

async function liveApp(appId) {
  const pkg = await livePackage(appId);
  if (!pkg) throw new Error(`app ${appId}: no live (published) version`);
  const def = pkg.live.properties.appDefinition.properties;
  return { version: pkg.live.name, at: def.lastPublishTime ?? def.appVersion ?? null, files: appFilesFromMsapp(pkg.bytes) };
}

/**
 * The live app's data sources (References/DataSources.json in its package): each connected
 * list with its site (DatasetName) and list id (TableName), and any flow the app calls.
 * The app list API only returns data source titles, so this file is the authoritative map.
 */
async function liveAppDataSources(appId) {
  const pkg = await livePackage(appId);
  if (!pkg) return { version: null, dataSources: [], sources: [] };
  const { live, bytes } = pkg;
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'msapp-'));
  try {
    const file = path.join(tmp, 'app.msapp');
    fs.writeFileSync(file, bytes);
    const names = execFileSync('unzip', ['-Z1', file], { encoding: 'utf8' }).split('\n').filter(Boolean);
    const read = (raw) => execFileSync('unzip', ['-p', file, raw.replace(/\\/g, '\\\\')], { maxBuffer: 64 * 1024 * 1024 }).toString('utf8');
    const raw = names.find((n) => n.replace(/\\/g, '/') === 'References/DataSources.json');
    const sources = names.map((n) => ({ raw: n, name: n.replace(/\\/g, '/') })).filter((e) => isAppSource(e.name))
      .map((e) => ({ name: e.name, text: read(e.raw) }));
    return { version: live.name, dataSources: raw ? JSON.parse(read(raw)).DataSources ?? [] : [], sources };
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
}

async function liveFlow(environmentId, flowId) {
  const f = await getJson(`${FLOW_API}/environments/${environmentId}/flows/${flowId}?api-version=2016-11-01`, flowAuth());
  return {
    version: f.properties.lastModifiedTime,
    at: f.properties.lastModifiedTime,
    state: f.properties.state,
    displayName: f.properties.displayName,
    definition: f.properties.definition,
    connectionReferences: f.properties.connectionReferences ?? {},
  };
}

async function liveN8n(project, workflowId) {
  const wf = await getJson(`${n8nBase(project)}/api/v1/workflows/${workflowId}`, n8nAuth(project));
  return { version: wf.activeVersionId ?? wf.versionId ?? null, at: wf.activeVersion?.updatedAt ?? wf.updatedAt ?? null, active: wf.active, workflow: wf };
}

async function liveMake(project, scenarioId) {
  const base = makeBase(project);
  const auth = makeAuth(project);
  const { scenario } = await getJson(`${base}/scenarios/${scenarioId}`, auth);
  const { response } = await getJson(`${base}/scenarios/${scenarioId}/blueprint`, auth);
  return { version: scenario?.lastEdit ?? null, at: scenario?.lastEdit ?? null, active: scenario?.isActive, blueprint: response?.blueprint ?? response };
}

module.exports = {
  ROOT, sha256, canonical, loadProject, azToken, keychainSecret, getJson, getBytes, getAll,
  redact, redactEverywhere, isAppSource, digestFiles, normalizeFlow, n8nBehaviour, n8nExport, makeBehaviour,
  PA_API, FLOW_API, paAuth, flowAuth, n8nBase, n8nAuth, makeBase, makeAuth,
  appFilesFromMsapp, liveApp, liveAppDataSources, liveFlow, liveN8n, liveMake,
};
