#!/usr/bin/env node
/**
 * validate-skill-body.mjs — enforce the SKILL.md structural contract.
 *
 * WHY THIS EXISTS
 *
 * A plugin's slash command is resolved from the skill's DIRECTORY name. The
 * `name:` field in frontmatter does not select it. That means a mismatch between
 * the two is invisible at runtime — the command still resolves, so nothing
 * breaks loudly — while the `description:` and its trigger keywords, which DO
 * drive model-side skill selection, go on advertising the old identity.
 *
 * This is not hypothetical. A sibling marketplace renamed four skill
 * directories with `git mv` and left their frontmatter untouched. Months later
 * the skills still declared retired names and still listed retired trigger
 * keywords, so a request phrased in the CURRENT vocabulary matched them worse
 * than one phrased in the vocabulary that had been deleted. The reference
 * implementation checks that `name:` is non-empty and stops there — the
 * information needed for the real check is already in scope, unused.
 *
 * THE CONTRACT
 *
 *   1. `name:` equals the containing directory name.        [error]
 *   2. `description:` exists and is <= 200 characters.      [error]
 *      Descriptions are always in context; they are charged against a budget.
 *   3. A SKILL.md over 200 lines has a `references/` sibling. [error]
 *      Progressive disclosure: the body loads on trigger, references load on
 *      demand. A long body spends context nobody asked for.
 *   4. A Self-Evolving banner appears near the top.          [error]
 *   5. `## Post-Execution Reflection` is the LAST section.   [error]
 *      Last, deliberately — recency is what makes it get read.
 *
 * Read-only. Exits 0 on success, 1 on any error. `--strict` promotes warnings.
 * Prints counted evidence: a gate that reports "ok" without saying how many
 * files it looked at is indistinguishable from a gate that looked at none.
 */

import { readFileSync, existsSync } from "node:fs";
import { readdir } from "node:fs/promises";
import { join, dirname, basename } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const STRICT = process.argv.includes("--strict");

const MAX_DESCRIPTION_CHARS = 200;
const MAX_BODY_LINES = 200;
const BANNER_SEARCH_LINES = 30;
const REFLECTION_HEADING = "## Post-Execution Reflection";
const BANNER_PATTERN = /^>\s*\*\*Self-Evolving Skill\*\*/;

const errors = [];
const warnings = [];

/** Discover plugins/<plugin>/skills/<skill>/SKILL.md without a glob dependency. */
async function discoverSkills() {
  const found = [];
  const pluginsDir = join(ROOT, "plugins");
  if (!existsSync(pluginsDir)) return found;

  for (const plugin of await readdir(pluginsDir, { withFileTypes: true })) {
    if (!plugin.isDirectory()) continue;
    const skillsDir = join(pluginsDir, plugin.name, "skills");
    if (!existsSync(skillsDir)) continue;

    for (const skill of await readdir(skillsDir, { withFileTypes: true })) {
      if (!skill.isDirectory()) continue;
      const skillMd = join(skillsDir, skill.name, "SKILL.md");
      if (existsSync(skillMd)) {
        found.push({
          path: skillMd,
          rel: join("plugins", plugin.name, "skills", skill.name, "SKILL.md"),
          dirName: skill.name,
          dir: join(skillsDir, skill.name),
        });
      }
    }
  }
  return found;
}

/**
 * Extract the frontmatter block. Returns null when the file does not open with
 * a fence. Deliberately regex-based rather than a YAML dependency: the contract
 * is a handful of scalar fields, and a parser would accept shapes the runtime
 * does not.
 */
function parseFrontmatter(text) {
  if (!text.startsWith("---")) return null;
  const end = text.indexOf("\n---", 3);
  if (end === -1) return null;
  return text.slice(3, end);
}

function scalar(frontmatter, key) {
  const match = frontmatter.match(new RegExp(`^${key}:\\s*(.+)$`, "m"));
  if (!match) return null;
  let value = match[1].trim();
  // Strip one layer of matching quotes.
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1);
  }
  return value;
}

const skills = await discoverSkills();

for (const skill of skills) {
  const text = readFileSync(skill.path, "utf8");
  const frontmatter = parseFrontmatter(text);

  if (frontmatter === null) {
    errors.push(`${skill.rel}: no YAML frontmatter block`);
    continue;
  }

  // 1 — name must equal the directory name.
  const name = scalar(frontmatter, "name");
  if (!name) {
    errors.push(`${skill.rel}: frontmatter has no 'name'`);
  } else if (name !== skill.dirName) {
    errors.push(
      `${skill.rel}: name is '${name}' but the directory is '${skill.dirName}'. ` +
        `The slash command resolves on the DIRECTORY, so this mismatch is invisible at ` +
        `runtime while the description and its triggers keep advertising '${name}'. ` +
        `Rename one to match the other.`
    );
  }

  // 2 — description present and within budget.
  const description = scalar(frontmatter, "description");
  if (!description) {
    errors.push(`${skill.rel}: frontmatter has no 'description'`);
  } else if (description.length > MAX_DESCRIPTION_CHARS) {
    errors.push(
      `${skill.rel}: description is ${description.length} chars, limit is ${MAX_DESCRIPTION_CHARS}. ` +
        `Descriptions are always in context — move detail into the body or references/.`
    );
  }

  // A colon inside the description breaks YAML parsing; the house form uses a hyphen.
  if (description && /\bTRIGGERS\s*:/.test(description)) {
    warnings.push(`${skill.rel}: use 'TRIGGERS - ' with a hyphen; a colon breaks YAML parsing`);
  }

  const lines = text.split("\n");

  // 3 — long bodies require references/.
  if (lines.length > MAX_BODY_LINES && !existsSync(join(skill.dir, "references"))) {
    errors.push(
      `${skill.rel}: ${lines.length} lines exceeds ${MAX_BODY_LINES} but has no references/ sibling. ` +
        `The body loads on every trigger; references load on demand.`
    );
  }

  // 4 — Self-Evolving banner near the top.
  const head = lines.slice(0, BANNER_SEARCH_LINES);
  if (!head.some((line) => BANNER_PATTERN.test(line))) {
    errors.push(
      `${skill.rel}: no Self-Evolving banner in the first ${BANNER_SEARCH_LINES} lines. ` +
        `Expected a line starting: > **Self-Evolving Skill**:`
    );
  }

  // 5 — Post-Execution Reflection must be the final section.
  const headings = lines.filter((line) => line.startsWith("## "));
  if (headings.length === 0) {
    errors.push(`${skill.rel}: no '## ' sections at all`);
  } else if (headings[headings.length - 1].trim() !== REFLECTION_HEADING) {
    errors.push(
      `${skill.rel}: last section is '${headings[headings.length - 1].trim()}', expected '${REFLECTION_HEADING}'. ` +
        `It is last on purpose — recency is what makes it get read.`
    );
  }
}

// ── Report ──────────────────────────────────────────────────────────────────
console.log("═".repeat(60));
console.log("SKILL BODY CONTRACT");
console.log("═".repeat(60));
console.log(`Skills discovered: ${skills.length}`);
console.log(`Errors:            ${errors.length}`);
console.log(`Warnings:          ${warnings.length}${STRICT ? " (strict: promoted to errors)" : ""}`);

if (skills.length === 0) {
  console.log("");
  console.log("· no SKILL.md files found under plugins/*/skills/*/");
  console.log("  This is expected while the marketplace is empty. It is reported, not");
  console.log("  silently passed — zero discovered and zero failed are different facts.");
}

for (const warning of warnings) console.log(`  ⚠ ${warning}`);

if (errors.length > 0 || (STRICT && warnings.length > 0)) {
  console.error("");
  for (const err of errors) console.error(`  ✗ ${err}`);
  if (STRICT) for (const warning of warnings) console.error(`  ✗ ${warning}`);
  console.error("");
  process.exit(1);
}

if (skills.length > 0) {
  console.log("");
  console.log(`✓ ${skills.length} skill(s) satisfy the body contract`);
}
process.exit(0);
