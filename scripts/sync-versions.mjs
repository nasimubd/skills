#!/usr/bin/env node
/**
 * Version Sync Script for semantic-release
 *
 * Updates version fields in all JSON files that contain version information.
 * Called by @semantic-release/exec during the prepare step.
 *
 * Usage: node scripts/sync-versions.mjs <version>
 * Example: node scripts/sync-versions.mjs 3.0.0
 *
 * Architecture: marketplace.json-only versioning
 * - Individual plugins do NOT carry their own plugins/<name>/plugin.json
 * - Every plugin version lives in .claude-plugin/marketplace.json
 *
 * AUTO-DISCOVERY: the plugin count is read from marketplace.json at run time.
 * Nothing here hardcodes how many plugins exist, so adding one needs no edit
 * to this file. A count of ZERO is a legitimate state, not an error: this
 * marketplace ships empty by design until the first plugin lands, and
 * marketplace.json then carries exactly one version field (the root).
 *
 * WHY THE COUNTS ARE ASSERTED
 * A regex that silently matched fewer fields than expected would publish a
 * release where some files carry the new version and others keep the old one,
 * and nothing would say so. Every file therefore declares how many version
 * fields it must contain, and a mismatch fails the release rather than
 * shipping a half-bumped tree.
 */

import { readFileSync, writeFileSync, readdirSync, statSync } from "fs";
import { resolve, join } from "path";

const VERSION = process.argv[2];

if (!VERSION) {
  console.error("Usage: node scripts/sync-versions.mjs <version>");
  console.error("Example: node scripts/sync-versions.mjs 3.0.0");
  process.exit(1);
}

// Validate semver format
if (!/^\d+\.\d+\.\d+(-[\w.]+)?$/.test(VERSION)) {
  console.error(`Invalid version format: ${VERSION}`);
  console.error("Expected: X.Y.Z or X.Y.Z-prerelease");
  process.exit(1);
}

// Files to sync (relative to repo root).
// This list is exactly what this repository has — there is deliberately no
// root-level plugin.json here, so it is not listed. Adding a file here without
// adding its EXPECTED_COUNTS entry is caught below before any write happens.
const FILES = [
  "package.json",
  ".claude-plugin/plugin.json",
  ".claude-plugin/marketplace.json",
];

/**
 * Auto-discover plugin count from marketplace.json
 * Returns: { pluginCount, pluginNames }
 */
function discoverPluginCount() {
  const marketplacePath = resolve(process.cwd(), ".claude-plugin/marketplace.json");
  try {
    const content = JSON.parse(readFileSync(marketplacePath, "utf8"));
    const plugins = content.plugins || [];
    return {
      pluginCount: plugins.length,
      pluginNames: plugins.map(p => p.name),
    };
  } catch (err) {
    console.error(`Error reading marketplace.json: ${err.message}`);
    process.exit(1);
  }
}

/**
 * Validate that plugins/ directory count matches marketplace.json
 * This catches the case where plugin files exist but weren't registered
 */
function validatePluginDirectories(expectedPlugins) {
  const pluginsDir = resolve(process.cwd(), "plugins");
  try {
    const dirs = readdirSync(pluginsDir).filter(name => {
      const path = join(pluginsDir, name);
      return statSync(path).isDirectory() && !name.startsWith(".");
    });

    const missing = dirs.filter(d => !expectedPlugins.includes(d));
    const extra = expectedPlugins.filter(p => !dirs.includes(p));

    if (missing.length > 0) {
      console.warn(`\n⚠️  Plugin directories not registered in marketplace.json:`);
      missing.forEach(m => console.warn(`   - plugins/${m}/`));
      console.warn(`   Run: Add these to .claude-plugin/marketplace.json\n`);
    }

    if (extra.length > 0) {
      console.warn(`\n⚠️  Plugins in marketplace.json without directories:`);
      extra.forEach(e => console.warn(`   - ${e}`));
    }

    return { dirs, missing, extra };
  } catch (err) {
    console.warn(`Could not validate plugins directory: ${err.message}`);
    return { dirs: [], missing: [], extra: [] };
  }
}

// Auto-discover plugin count
const { pluginCount, pluginNames } = discoverPluginCount();
console.log(
  pluginCount === 0
    ? "Discovered 0 plugins in marketplace.json (empty marketplace — expected until the first plugin lands)"
    : `Discovered ${pluginCount} plugins in marketplace.json`
);

// Validate plugin directories match
const { missing } = validatePluginDirectories(pluginNames);
if (missing.length > 0) {
  console.error(`\n❌ Unregistered plugins detected! Register them in marketplace.json first.`);
  process.exit(1);
}

// Expected version field counts per file (auto-discovered).
// marketplace.json holds one root version plus one per plugin, so a zero-plugin
// marketplace expects exactly 1 — no special case, and no division anywhere in
// this script, so an empty registry cannot produce NaN or a divide-by-zero.
const EXPECTED_COUNTS = {
  "package.json": 1,
  ".claude-plugin/plugin.json": 1,
  ".claude-plugin/marketplace.json": 1 + pluginCount, // 1 root + N plugins
};

// FILES and EXPECTED_COUNTS must describe the same set of files. If they drift,
// the per-file check below still passes while the total check fails with a
// number nobody can trace back to a file. Fail here instead, naming the key.
{
  const filesSet = new Set(FILES);
  const countsSet = new Set(Object.keys(EXPECTED_COUNTS));
  const missingCount = FILES.filter(f => !countsSet.has(f));
  const strayCount = [...countsSet].filter(f => !filesSet.has(f));
  if (missingCount.length > 0 || strayCount.length > 0) {
    console.error("\n❌ FILES and EXPECTED_COUNTS disagree — fix this script, not the data:");
    missingCount.forEach(f => console.error(`   - in FILES but has no EXPECTED_COUNTS entry: ${f}`));
    strayCount.forEach(f => console.error(`   - in EXPECTED_COUNTS but not in FILES: ${f}`));
    process.exit(1);
  }
}

// Version regex pattern
const VERSION_PATTERN = /"version":\s*"[0-9]+\.[0-9]+\.[0-9]+(-[\w.]+)?"/g;

// PASS 1 — read and plan every file. Nothing is written yet.
//
// Writing as we iterate would mean that a failure on the third file leaves the
// first two already bumped: the tree ends up carrying two versions at once, and
// the error message says nothing about the files that DID change. Plan
// everything, validate the whole plan, then write.
const plan = [];

for (const file of FILES) {
  const filePath = resolve(process.cwd(), file);

  try {
    const content = readFileSync(filePath, "utf8");
    const matches = content.match(VERSION_PATTERN) || [];

    if (matches.length === 0) {
      plan.push({ file, filePath, replacements: 0, status: "no-match" });
      continue;
    }

    plan.push({
      file,
      filePath,
      replacements: matches.length,
      status: "planned",
      updated: content.replace(VERSION_PATTERN, `"version": "${VERSION}"`),
    });
  } catch (err) {
    if (err.code === "ENOENT") {
      plan.push({ file, filePath, replacements: 0, status: "not-found" });
    } else {
      throw err;
    }
  }
}

// Validate the plan. Every declared file must be present and must carry exactly
// the number of version fields it declared — a file that is missing, or that
// matched nothing, is a failure and not a warning, because either one would
// leave the tree half-bumped.
let hasError = false;
for (const { file, replacements, status } of plan) {
  const expected = EXPECTED_COUNTS[file];
  if (status === "not-found") {
    console.error(`Validation error: ${file} is declared in FILES but does not exist`);
    hasError = true;
  } else if (status === "no-match") {
    console.error(
      `Validation error: ${file} exists but contains 0 version fields, expected ${expected}`
    );
    hasError = true;
  } else if (replacements !== expected) {
    console.error(
      `Validation error: ${file} expected ${expected} replacements, got ${replacements}`
    );
    hasError = true;
  }
}

if (hasError) {
  console.error("\nVersion sync aborted — no files were modified.");
  process.exit(1);
}

// PASS 2 — the plan is fully validated, so commit it to disk.
let totalReplacements = 0;
for (const { file, filePath, replacements, updated } of plan) {
  writeFileSync(filePath, updated, "utf8");
  console.log(`Updated ${file}: ${replacements} version field(s)`);
  totalReplacements += replacements;
}

// Summary
console.log("\n--- Version Sync Summary ---");
console.log(`Version: ${VERSION}`);
console.log(`Files processed: ${FILES.length}`);
console.log(`Plugins registered: ${pluginCount}`);
console.log(
  `Total replacements: ${totalReplacements} (expected ${Object.values(EXPECTED_COUNTS).reduce((a, b) => a + b, 0)})`
);

// Total is derived, never hardcoded: one field each for package.json and
// .claude-plugin/plugin.json, plus 1 + pluginCount for marketplace.json.
// With zero plugins that is 1 + 1 + 1 = 3.
const expectedTotal = Object.values(EXPECTED_COUNTS).reduce((a, b) => a + b, 0);
if (totalReplacements !== expectedTotal) {
  console.error(`\nExpected ${expectedTotal} total replacements, got ${totalReplacements}`);
  process.exit(1);
}

console.log("\nVersion sync completed successfully!");
