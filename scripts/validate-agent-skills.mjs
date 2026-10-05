#!/usr/bin/env node
/**
 * Validate the platform-neutral Agent Skills layer.
 *
 * Claude plugin validation remains separate because Claude has additional
 * packaging rules. This gate checks only the shared contract: directory name,
 * required frontmatter, and progressive-disclosure references for long bodies.
 */

import { existsSync, readFileSync, readdirSync } from "node:fs";
import { join, relative, resolve } from "node:path";

const root = resolve(process.cwd());
const skillsRoot = join(root, "skills");
const errors = [];
const skills = [];

function parseFrontmatter(text) {
  if (!text.startsWith("---")) return null;
  const end = text.indexOf("\n---", 3);
  return end < 0 ? null : text.slice(3, end);
}

function scalar(frontmatter, key) {
  const match = frontmatter.match(new RegExp(`^${key}:\\s*(.+)$`, "m"));
  if (!match) return null;
  return match[1].trim().replace(/^(["'])(.*)\1$/, "$2");
}

if (existsSync(skillsRoot)) {
  for (const entry of readdirSync(skillsRoot, { withFileTypes: true })) {
    if (!entry.isDirectory()) continue;
    const path = join(skillsRoot, entry.name, "SKILL.md");
    if (existsSync(path)) skills.push({ path, name: entry.name });
  }
}

for (const skill of skills) {
  const rel = relative(root, skill.path);
  const text = readFileSync(skill.path, "utf8");
  const frontmatter = parseFrontmatter(text);
  if (!frontmatter) {
    errors.push(`${rel}: missing YAML frontmatter`);
    continue;
  }

  const name = scalar(frontmatter, "name");
  const description = scalar(frontmatter, "description");
  if (name !== skill.name) errors.push(`${rel}: name must equal directory '${skill.name}'`);
  if (!description) errors.push(`${rel}: missing description`);
  if (description && description.length > 200) errors.push(`${rel}: description exceeds 200 characters`);
  if (text.split("\n").length > 200 && !existsSync(join(root, "skills", skill.name, "references"))) {
    errors.push(`${rel}: long skill requires references/`);
  }
}

console.log("AGENT SKILLS CONTRACT");
console.log(`Skills discovered: ${skills.length}`);
console.log(`Errors:            ${errors.length}`);
for (const error of errors) console.error(`  ✗ ${error}`);
if (errors.length) process.exit(1);
console.log(`✓ ${skills.length} shared skill(s) satisfy the portable contract`);
