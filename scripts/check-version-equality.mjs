#!/usr/bin/env node
/**
 * check-version-equality.mjs — assert the version lockstep actually holds.
 *
 * WHY THIS EXISTS
 *
 * This marketplace uses single-number versioning: one semver value is stamped
 * into every manifest by scripts/sync-versions.mjs at release time. That script
 * asserts REPLACEMENT COUNTS — it verifies it rewrote the number of fields it
 * expected to rewrite. What it cannot see is a value that drifted between
 * releases and then got silently overwritten, or a version field living in a
 * file it was never told about.
 *
 * The reference implementation this marketplace was modelled on had exactly
 * that hole. Its own version-consistency strategy document specified this check
 * and it was never written. The observable result, at the time of writing: one
 * plugin entry sat six minor versions behind the marketplace it shipped in, and
 * a per-plugin manifest stayed pinned at an ancient version across roughly
 * sixteen major releases — because it was listed in the release commit's asset
 * list (so it shipped) but not in the version sync script's file list (so it
 * never bumped). Nothing failed. Nothing could have.
 *
 * THE THREE INVARIANTS
 *
 *   1. The marketplace root version equals the marketplace-as-a-plugin manifest
 *      version equals the package version. Three files, one number.
 *
 *   2. Every registered plugin entry carries exactly the root version. A plugin
 *      arriving from a merge with its own version is the drift vector that
 *      produced the incident above.
 *
 *   3. No per-plugin manifest carries a `version` key at all. The marketplace
 *      entry is the single source of truth for a plugin's version. A `version`
 *      in plugins/<name>/plugin.json is unmanaged by definition — nothing bumps
 *      it, so it can only ever be right by coincidence and wrong by default.
 *      This is doctrine upstream stated and practice contradicted; here it is
 *      enforced.
 *
 * Read-only. Exits 0 on success, 1 on any violation. Prints counted evidence,
 * never a bare tick — a gate that only says "ok" cannot be distinguished from a
 * gate that did nothing.
 */

import { readFileSync, existsSync } from "node:fs";
import { readdir } from "node:fs/promises";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");

const MARKETPLACE = ".claude-plugin/marketplace.json";
const PLUGIN_MANIFEST = ".claude-plugin/plugin.json";
const PACKAGE = "package.json";

/** Files that scripts/sync-versions.mjs is responsible for bumping. */
const MANAGED_VERSION_FILES = [PACKAGE, PLUGIN_MANIFEST, MARKETPLACE];

const errors = [];
const notes = [];

function readJson(relPath, { required = true } = {}) {
  const abs = join(ROOT, relPath);
  if (!existsSync(abs)) {
    if (required) errors.push(`${relPath} does not exist`);
    return null;
  }
  try {
    return JSON.parse(readFileSync(abs, "utf8"));
  } catch (err) {
    errors.push(`${relPath} is not valid JSON: ${err.message}`);
    return null;
  }
}

const marketplace = readJson(MARKETPLACE);
const pluginManifest = readJson(PLUGIN_MANIFEST);
const pkg = readJson(PACKAGE, { required: false });

if (!marketplace) {
  console.error("✗ cannot proceed without a readable marketplace manifest");
  process.exit(1);
}

const rootVersion = marketplace.version;

if (typeof rootVersion !== "string" || !/^\d+\.\d+\.\d+$/.test(rootVersion)) {
  errors.push(`${MARKETPLACE} version is not semver: ${JSON.stringify(rootVersion)}`);
}

// ── Invariant 1: the three managed manifests agree ───────────────────────────
const managed = [
  [MARKETPLACE, rootVersion],
  [PLUGIN_MANIFEST, pluginManifest?.version],
  [PACKAGE, pkg?.version],
];

for (const [file, version] of managed) {
  if (version === undefined) {
    // package.json may legitimately not exist yet during scaffolding.
    if (file === PACKAGE && !pkg) {
      notes.push(`${PACKAGE} absent — skipped (not yet scaffolded)`);
      continue;
    }
    errors.push(`${file} has no version field`);
    continue;
  }
  if (version !== rootVersion) {
    errors.push(`${file} version is ${version}, expected ${rootVersion} (marketplace root)`);
  }
}

// ── Invariant 2: every registered plugin entry carries the root version ──────
const entries = Array.isArray(marketplace.plugins) ? marketplace.plugins : [];

for (const entry of entries) {
  const name = entry?.name ?? "<unnamed>";
  if (entry?.version !== rootVersion) {
    errors.push(
      `marketplace entry '${name}' version is ${entry?.version}, expected ${rootVersion}. ` +
        `A plugin entry that carries its own version is the drift vector this gate exists to catch — ` +
        `it usually arrives via a merge and nothing downstream corrects it.`
    );
  }
}

// ── Invariant 3: no per-plugin manifest carries a version key ────────────────
let scannedManifests = 0;
const pluginsDir = join(ROOT, "plugins");

if (existsSync(pluginsDir)) {
  const dirents = await readdir(pluginsDir, { withFileTypes: true });
  for (const dirent of dirents) {
    if (!dirent.isDirectory()) continue;
    for (const candidate of [
      join("plugins", dirent.name, "plugin.json"),
      join("plugins", dirent.name, ".claude-plugin", "plugin.json"),
    ]) {
      const abs = join(ROOT, candidate);
      if (!existsSync(abs)) continue;
      scannedManifests += 1;
      if (MANAGED_VERSION_FILES.includes(candidate)) continue;
      const manifest = readJson(candidate, { required: false });
      if (manifest && Object.hasOwn(manifest, "version")) {
        errors.push(
          `${candidate} carries a 'version' key (${manifest.version}). ` +
            `Per-plugin manifests must not — nothing bumps them, so the value can only drift. ` +
            `The marketplace entry is the single source of truth. Remove the key.`
        );
      }
    }
  }
}

// ── Report ──────────────────────────────────────────────────────────────────
console.log("═".repeat(60));
console.log("VERSION EQUALITY");
console.log("═".repeat(60));
console.log(`Marketplace version:   ${rootVersion ?? "<unreadable>"}`);
console.log(`Managed manifests:     ${managed.filter(([, v]) => v !== undefined).length} checked`);
console.log(`Plugin entries:        ${entries.length} checked`);
console.log(`Per-plugin manifests:  ${scannedManifests} scanned for stray version keys`);
for (const note of notes) console.log(`  · ${note}`);
console.log(`Errors:                ${errors.length}`);

if (errors.length > 0) {
  console.error("");
  for (const err of errors) console.error(`  ✗ ${err}`);
  console.error("");
  console.error("Version lockstep is broken. Do not release.");
  process.exit(1);
}

console.log("");
console.log(`✓ version lockstep holds across ${managed.filter(([, v]) => v !== undefined).length} manifests and ${entries.length} plugin entries`);
process.exit(0);
