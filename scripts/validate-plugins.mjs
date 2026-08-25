#!/usr/bin/env bun
// FILE-SIZE-OK — one validator covering registration, hooks, skills and dependencies
/**
 * Plugin Registration Validator
 *
 * Validates that every plugin directory is registered in marketplace.json with a
 * complete, schema-valid entry, and tracks inter-plugin dependencies.
 *
 * Runs under bun or node; both are supported and the shebang picks bun.
 *
 * Usage:
 *   bun scripts/validate-plugins.mjs           # Validate only
 *   bun scripts/validate-plugins.mjs --fix     # Show fix instructions
 *   bun scripts/validate-plugins.mjs --strict  # Fail on warnings too
 *   bun scripts/validate-plugins.mjs --deps    # Show dependency graph
 *
 * Check groups:
 *   1. Plugin directories have marketplace.json entries (registration)
 *   2. Marketplace entries have required fields (JSON Schema validation)
 *   3. Source paths in marketplace.json exist on disk
 *   4. Hooks paths (if specified) exist on disk
 *   5. No orphaned entries (registered but no directory)
 *   6. Inter-plugin dependencies are tracked and circular deps detected
 *   7. Referenced skills exist in target plugins
 *   8. Hook output format matches what Claude Code actually reads
 *   9. Hook JSON structure from manage-hooks.sh (prevents "Invalid discriminator value")
 *  10. All skills/{name}/SKILL.md must have name + description frontmatter
 *
 * EMPTY MARKETPLACE IS VALID.
 * This repository ships zero plugins by design until the first one lands. Every
 * check below is written to produce nothing rather than to fail when there is
 * nothing to check, and the run exits 0. Do not "fix" that by asserting a
 * minimum plugin count — the schema owns that decision, in one place.
 *
 * Integration:
 *   - Pre-commit hook
 *   - CI validation
 *   - Manual: run before cutting a release
 *
 * Dependencies:
 *   - tinyglobby: file globbing
 *   - ajv: JSON Schema validation
 * Both are imported statically, so a missing dependency fails loudly at startup
 * rather than degrading into a validator that checks less than it claims to.
 */

import { readFileSync, readdirSync, statSync, existsSync } from "fs";
import { resolve, join, dirname, relative, basename } from "path";
import { execSync } from "child_process";
import { glob } from "tinyglobby";
import Ajv from "ajv";

const SHOW_FIX = process.argv.includes("--fix");
const STRICT_MODE = process.argv.includes("--strict");
const SHOW_DEPS = process.argv.includes("--deps");

// Legacy constant for backward compatibility
const REQUIRED_FIELDS = ["name", "description", "version", "source", "category"];

// Load JSON Schema for marketplace.json validation
// ADR: Uses AJV (industry standard) for schema validation
const schemaPath = resolve(dirname(import.meta.url.replace("file://", "")), "marketplace.schema.json");
let marketplaceSchema;
let validateSchema;
try {
  marketplaceSchema = JSON.parse(readFileSync(schemaPath, "utf8"));
  // Remove $schema key - AJV doesn't need it for validation
  delete marketplaceSchema.$schema;
  const ajv = new Ajv({ allErrors: true, strict: false });
  validateSchema = ajv.compile(marketplaceSchema);
} catch (err) {
  console.warn(`⚠️  Could not load marketplace.schema.json: ${err.message}`);
  console.warn(`   Falling back to basic field validation.`);
  validateSchema = null;
}

// The allowed category values, read out of the schema rather than restated, so
// the --fix template cannot suggest a category the schema rejects.
const CATEGORIES =
  marketplaceSchema?.properties?.plugins?.items?.properties?.category?.enum ?? [];

// Load JSON Schema for hooks.json validation
// ADR: Prevents "Invalid discriminator value" regressions from malformed hook structures
const hooksSchemaPath = resolve(dirname(import.meta.url.replace("file://", "")), "hooks.schema.json");
let hooksSchema;
let validateHooksSchema;
try {
  hooksSchema = JSON.parse(readFileSync(hooksSchemaPath, "utf8"));
  delete hooksSchema.$schema;
  const ajv = new Ajv({ allErrors: true, strict: false });
  validateHooksSchema = ajv.compile(hooksSchema);
} catch (err) {
  console.warn(`⚠️  Could not load hooks.schema.json: ${err.message}`);
  console.warn(`   Hook structure validation disabled.`);
  validateHooksSchema = null;
}

/**
 * Read marketplace.json and return full plugin entries.
 * Memoized: this is called from six places and the file cannot change mid-run,
 * so re-reading it would only create a window where two callers disagree.
 */
let marketplaceCache;
function getMarketplaceData() {
  if (marketplaceCache !== undefined) return marketplaceCache;
  const marketplacePath = resolve(process.cwd(), ".claude-plugin/marketplace.json");
  try {
    marketplaceCache = JSON.parse(readFileSync(marketplacePath, "utf8"));
    return marketplaceCache;
  } catch (err) {
    console.error(`❌ Error reading marketplace.json: ${err.message}`);
    console.error(`   Expected at: ${relative(process.cwd(), marketplacePath)}`);
    process.exit(1);
  }
}

/**
 * The marketplace's own name, as registered. Used to recognise this
 * marketplace's own installed files and to print correct install commands.
 * Never hardcode it — the manifest is the single source of truth.
 */
function getMarketplaceName() {
  const name = getMarketplaceData().name;
  return typeof name === "string" && name.length > 0 ? name : null;
}

/**
 * Read marketplace.json and extract plugin names (legacy compatibility)
 */
function getRegisteredPlugins() {
  const data = getMarketplaceData();
  return (data.plugins || []).map(p => p.name);
}

/**
 * Get all plugin directories.
 *
 * An absent plugins/ directory means "no plugins yet", which is the normal
 * state of an empty marketplace — it is not a validator failure. Any other
 * read error (permissions, a file where the directory should be) still aborts,
 * because that is a real problem being reported as one.
 */
function getPluginDirectories() {
  const pluginsDir = resolve(process.cwd(), "plugins");
  try {
    return readdirSync(pluginsDir).filter(name => {
      const path = join(pluginsDir, name);
      return statSync(path).isDirectory() && !name.startsWith(".");
    });
  } catch (err) {
    if (err.code === "ENOENT") return [];
    console.error(`❌ Error reading plugins directory: ${err.message}`);
    process.exit(1);
  }
}

/**
 * Validate marketplace.json entries have required fields and valid paths.
 * Uses AJV for JSON Schema validation + custom path existence checks.
 *
 * With zero plugins the AJV pass still runs — it validates the marketplace
 * object itself (name, version, owner), which is exactly what an empty
 * marketplace still needs to get right — and the per-plugin loop iterates
 * nothing.
 */
function validateMarketplaceEntries() {
  const data = getMarketplaceData();
  const plugins = data.plugins || [];
  const errors = [];
  const warnings = [];

  // Step 1: AJV Schema validation (if schema loaded successfully)
  if (validateSchema) {
    const valid = validateSchema(data);
    if (!valid && validateSchema.errors) {
      validateSchema.errors.forEach((err) => {
        const path = err.instancePath || err.dataPath || "";
        const message = err.message || "validation error";
        errors.push(`Schema: ${path} ${message}`);
      });
    }
  } else {
    // Fallback: manual required field checks if schema unavailable
    plugins.forEach((plugin, index) => {
      const prefix = `Plugin #${index + 1} (${plugin.name || "unnamed"})`;
      REQUIRED_FIELDS.forEach(field => {
        if (!plugin[field]) {
          errors.push(`${prefix}: Missing required field '${field}'`);
        }
      });
    });
  }

  // Step 2: Path existence checks (cannot be in JSON Schema)
  plugins.forEach((plugin, index) => {
    const prefix = `Plugin #${index + 1} (${plugin.name || "unnamed"})`;

    // Validate source path exists
    if (plugin.source) {
      const sourcePath = resolve(process.cwd(), plugin.source);
      if (!existsSync(sourcePath)) {
        errors.push(`${prefix}: Source path does not exist: ${plugin.source}`);
      }
    }

    // Validate hooks path exists (if specified)
    if (plugin.hooks) {
      const hooksPath = resolve(process.cwd(), plugin.hooks);
      if (!existsSync(hooksPath)) {
        errors.push(`${prefix}: Hooks file does not exist: ${plugin.hooks}`);
      }
    }

    // Warn if a plugin still declares a "commands" field. Skills are the single
    // canonical surface: a parallel commands/ layer duplicates every description
    // and the duplicate is always the one that goes stale.
    if (plugin.commands) {
      warnings.push(`${prefix}: Has deprecated "commands" field in marketplace.json — remove it, skills/ is the canonical surface`);
    }

    // Warn about missing optional but recommended fields
    if (!plugin.author) {
      warnings.push(`${prefix}: Missing recommended field 'author'`);
    }
    if (!plugin.keywords || plugin.keywords.length === 0) {
      warnings.push(`${prefix}: Missing recommended field 'keywords'`);
    }
  });

  return { errors, warnings };
}

/**
 * Recursively find all markdown files in a directory
 * Uses tinyglobby for efficient file globbing (72% smaller than globby)
 */
async function findMarkdownFiles(dir) {
  if (!existsSync(dir)) return [];

  // Use tinyglobby for efficient file discovery
  const pattern = join(dir, "**/*.md").replace(/\\/g, "/");
  const files = await glob(pattern, {
    absolute: true,
    onlyFiles: true,
  });
  return files;
}

/**
 * Extract Skill() invocations from a markdown file
 * Matches patterns like: Skill(plugin:skill), Skill(plugin-name:skill-name)
 * Returns array of { plugin, skill, file, line }
 */
function extractSkillDependencies(filePath) {
  const dependencies = [];
  try {
    const content = readFileSync(filePath, "utf8");
    const lines = content.split("\n");

    // Pattern: Skill(plugin:skill) or Skill(plugin-name:skill-name)
    const skillPattern = /Skill\(([a-z0-9-]+):([a-z0-9-]+)\)/gi;

    lines.forEach((line, index) => {
      let match;
      while ((match = skillPattern.exec(line)) !== null) {
        dependencies.push({
          plugin: match[1],
          skill: match[2],
          file: filePath,
          line: index + 1,
        });
      }
    });
  } catch (err) {
    // Explicit warning for unreadable files (no silent failures)
    console.warn(`⚠️  Could not read file: ${filePath} (${err.code || err.message})`);
  }
  return dependencies;
}

/**
 * Build dependency graph for all plugins
 * Returns { graph: Map<plugin, Set<dependsOn>>, details: [...] }
 */
async function buildDependencyGraph() {
  const pluginsDir = resolve(process.cwd(), "plugins");
  const directories = getPluginDirectories();
  const graph = new Map(); // plugin -> Set of plugins it depends on
  const details = []; // detailed dependency info

  // Process all plugins (await for async findMarkdownFiles)
  for (const pluginName of directories) {
    const pluginDir = join(pluginsDir, pluginName);
    const mdFiles = await findMarkdownFiles(pluginDir);

    for (const file of mdFiles) {
      const deps = extractSkillDependencies(file);
      for (const dep of deps) {
        // Skip self-references
        if (dep.plugin === pluginName) continue;

        // Add to graph
        if (!graph.has(pluginName)) {
          graph.set(pluginName, new Set());
        }
        graph.get(pluginName).add(dep.plugin);

        // Store detailed info
        details.push({
          from: pluginName,
          to: dep.plugin,
          skill: dep.skill,
          file: relative(process.cwd(), dep.file),
          line: dep.line,
        });
      }
    }
  }

  return { graph, details };
}

/**
 * Known complementary plugin pairs that have intentional bidirectional Skill()
 * references. These are NOT true circular dependencies — they are collaborative
 * workflows where each plugin recommends the other for a related task and
 * neither REQUIRES the other to function.
 *
 * Deliberately empty: this marketplace has no plugins yet, so it has no pairs.
 * Add entries in BOTH directions ("a:b" and "b:a") only when a cycle is
 * genuinely benign; every entry here is a suppressed warning, so an unjustified
 * one hides a real cycle.
 */
const KNOWN_COMPLEMENTARY_PAIRS = new Set([]);

/**
 * Check if a cycle is a known complementary pair (not a real circular dependency)
 */
function isComplementaryPair(cycle) {
  // A cycle like ["doc-tools", "itp", "doc-tools"] has 3 elements
  // The actual pair is the first two elements
  if (cycle.length !== 3) return false;
  const pair = `${cycle[0]}:${cycle[1]}`;
  return KNOWN_COMPLEMENTARY_PAIRS.has(pair);
}

/**
 * Detect circular dependencies using DFS
 * Returns array of cycles found, e.g., [["a", "b", "a"], ["x", "y", "z", "x"]]
 * Filters out known complementary pairs that are intentionally bidirectional.
 */
function detectCircularDependencies(graph) {
  const cycles = [];
  const visited = new Set();
  const recursionStack = new Set();

  function dfs(node, path) {
    if (recursionStack.has(node)) {
      // Found cycle - extract it from path
      const cycleStart = path.indexOf(node);
      const cycle = [...path.slice(cycleStart), node];
      cycles.push(cycle);
      return;
    }
    if (visited.has(node)) return;

    visited.add(node);
    recursionStack.add(node);
    path.push(node);

    const deps = graph.get(node) || new Set();
    for (const dep of deps) {
      dfs(dep, [...path]);
    }

    recursionStack.delete(node);
  }

  for (const node of graph.keys()) {
    if (!visited.has(node)) {
      dfs(node, []);
    }
  }

  // Filter out known complementary pairs (not real circular dependencies)
  return cycles.filter((cycle) => !isComplementaryPair(cycle));
}

/**
 * Find all hook files in plugin directories (shell, Python, TypeScript, JavaScript)
 * Returns array of { path, plugin, filename, language }
 * Uses tinyglobby for efficient file discovery
 *
 * Language support:
 *   - .sh → shell (bash)
 *   - .py → python
 *   - .ts → typescript (Bun)
 *   - .mjs → javascript (Bun)
 */
async function findHookScripts() {
  const pluginsDir = resolve(process.cwd(), "plugins");

  // Use tinyglobby to find all hook scripts at once.
  // .ts and .mjs are included so TypeScript/Bun hooks are validated too.
  const hookPaths = await glob("plugins/*/hooks/*.{sh,py,ts,mjs}", {
    cwd: process.cwd(),
    absolute: true,
    onlyFiles: true,
    ignore: [
      "**/__*.py",       // Exclude Python dunder files (__init__.py, etc.)
      "**/*.test.ts",    // Exclude TypeScript test files
      "**/*.spec.ts",    // Exclude TypeScript spec files
      "**/*.test.mjs",   // Exclude JavaScript test files
      "**/*.spec.mjs",   // Exclude JavaScript spec files
      "**/*.test.js",    // Exclude plain JS test files
      "**/*.spec.js",    // Exclude plain JS spec files
    ],
  });

  // Map paths to structured objects preserving language field
  const hookFiles = hookPaths.map((fullPath) => {
    const relPath = relative(pluginsDir, fullPath);
    const parts = relPath.split(/[/\\]/);
    const pluginName = parts[0];
    const filename = basename(fullPath);

    // Determine language from file extension
    let language;
    if (filename.endsWith(".sh")) {
      language = "shell";
    } else if (filename.endsWith(".py")) {
      language = "python";
    } else if (filename.endsWith(".ts")) {
      language = "typescript";
    } else if (filename.endsWith(".mjs")) {
      language = "javascript";
    } else {
      language = "unknown";
    }

    return {
      path: fullPath,
      plugin: pluginName,
      filename: filename,
      language: language,
    };
  });

  return hookFiles;
}

/**
 * Detect hook type from filename, content, and hooks.json
 * Returns: "PostToolUse" | "Stop" | "PreToolUse" | "SubagentStop" | "unknown"
 *
 * hooks.json is consulted first because it is authoritative; the filename and
 * content heuristics below only run when the script is not registered there.
 */
function detectHookType(filename, content, hooksJsonPath) {
  const lowerFilename = filename.toLowerCase();

  // Try to read hooks.json for definitive type
  if (existsSync(hooksJsonPath)) {
    try {
      const hooksJson = JSON.parse(readFileSync(hooksJsonPath, "utf8"));
      const hooks = hooksJson.hooks || hooksJson;

      // Search all hook types for this script
      for (const [hookType, matchers] of Object.entries(hooks)) {
        if (!Array.isArray(matchers)) continue;
        for (const matcher of matchers) {
          const hookList = matcher.hooks || [];
          for (const hook of hookList) {
            if (hook.command && hook.command.includes(filename)) {
              return hookType;
            }
          }
        }
      }
    } catch (err) {
      // Fall through to heuristics
    }
  }

  // Heuristics based on filename
  if (lowerFilename.includes("stop") && !lowerFilename.includes("subagent")) {
    return "Stop";
  }
  if (lowerFilename.includes("subagent")) {
    return "SubagentStop";
  }
  if (lowerFilename.includes("posttooluse") || lowerFilename.includes("post-tool")) {
    return "PostToolUse";
  }
  if (lowerFilename.includes("pretooluse") || lowerFilename.includes("pre-tool")) {
    return "PreToolUse";
  }
  if (lowerFilename.includes("sessionstart") || lowerFilename.includes("session-start") || lowerFilename.includes("session-bind")) {
    return "SessionStart";
  }
  if (lowerFilename.includes("empty-firing") || lowerFilename.includes("firing-detector")) {
    return "Stop";
  }

  // Content-based heuristics
  if (content.includes("PostToolUse") || content.includes("tool_response")) {
    return "PostToolUse";
  }
  if (content.includes("stop_hook_active") || content.includes('"Stop hook"') || content.includes("(Claude Code Stop hook)")) {
    return "Stop";
  }
  if (content.includes("permissionDecision") || content.includes("PreToolUse")) {
    return "PreToolUse";
  }
  if (content.includes("SessionStart") || content.includes('"hookEventName": "SessionStart"')) {
    return "SessionStart";
  }

  return "unknown";
}

/**
 * Validate hook output format for Claude Code consumption
 *
 * Different hook types have DIFFERENT semantics:
 *
 * PostToolUse:
 *   - "decision": "block" = VISIBILITY only (non-blocking)
 *   - "reason" = what Claude sees
 *   - MUST use decision:block for Claude to see output
 *
 * Stop/SubagentStop:
 *   - "decision": "block" = ACTUALLY BLOCKS stopping (forces continuation)
 *   - For informational: use {systemMessage: "..."} (hookSpecificOutput NOT supported)
 *   - Empty {} = allow stop normally
 *
 * PreToolUse:
 *   - "decision": "block" = DEPRECATED (use permissionDecision)
 *   - Use permissionDecision: "deny" + permissionDecisionReason
 *
 * Returns { errors: [...], warnings: [...] }
 */
async function validateHookOutputFormat() {
  const hookFiles = await findHookScripts();
  const errors = [];
  const warnings = [];

  // Fields that Claude Code actually reads from PostToolUse JSON
  const CLAUDE_VISIBLE_FIELDS = new Set(["decision", "reason"]);

  // Fields that are valid but not shown to Claude (informational)
  const OPTIONAL_FIELDS = new Set([
    "hookSpecificOutput",
    "suppressOutput",
    "systemMessage",
    "continue",
    "stopReason",
  ]);

  hookFiles.forEach(({ path, plugin, filename, language }) => {
    try {
      const content = readFileSync(path, "utf8");
      const lines = content.split("\n");
      const relPath = relative(process.cwd(), path);
      const hooksJsonPath = join(dirname(path), "hooks.json");

      // Detect hook type
      const hookType = detectHookType(filename, content, hooksJsonPath);

      // Skip non-hook Python files (utilities, adapters, etc.)
      if (language === "python" && hookType === "unknown") {
        // Check if it's actually a hook entry point (has main() or is referenced in hooks.json)
        const isHookEntryPoint =
          content.includes('if __name__ == "__main__"') ||
          content.includes("def main()");
        if (!isHookEntryPoint) {
          return; // Skip utility modules
        }
      }

      // Track issues for this file
      const fileIssues = [];

      // Helper: check if pattern exists in non-comment lines
      const hasPatternInCode = (pattern) => {
        return lines.some((line) => {
          const trimmed = line.trim();
          // Skip comment lines
          if (trimmed.startsWith("#") || trimmed.startsWith("//")) return false;
          return pattern.test(line);
        });
      };

      // === STOP HOOK VALIDATION ===
      // Check for decision:block used for informational purposes (should use additionalContext)
      if (hookType === "Stop" || hookType === "SubagentStop") {
        const hasDecisionBlock = hasPatternInCode(/["']?decision["']?\s*[:=]\s*["']block["']/);

        const hasAdditionalContext = content.includes("additionalContext");
        const hasStopHookActiveCheck = content.includes("stop_hook_active");

        // If using decision:block but NOT checking stop_hook_active, warn about infinite loop
        if (hasDecisionBlock && !hasStopHookActiveCheck) {
          warnings.push(
            `${relPath}: Stop hook uses "decision: block" but doesn't check stop_hook_active - risk of infinite loop`
          );
        }

        // If file seems informational (mentions "info", "summary", "validation results")
        // but uses decision:block, warn that it will actually block stopping
        // EXCEPTION: Files that clearly intend to block (loop control, continuation, etc.)
        const seemsInformational =
          content.toLowerCase().includes("validation result") ||
          content.toLowerCase().includes("session ended") ||
          content.toLowerCase().includes("link validation");

        const intentionallyBlocking =
          content.toLowerCase().includes("continue_session") ||
          content.toLowerCase().includes("loop") ||
          content.toLowerCase().includes("autonomous") ||
          content.toLowerCase().includes("force continuation") ||
          content.toLowerCase().includes("must be fixed") ||
          content.toLowerCase().includes("fix before") ||
          content.toLowerCase().includes("hard-blocking") ||
          filename.toLowerCase().includes("loop");

        if (hasDecisionBlock && seemsInformational && !hasAdditionalContext && !intentionallyBlocking) {
          warnings.push(
            `${relPath}: Stop hook appears informational but uses "decision: block" which ACTUALLY BLOCKS stopping`
          );
          warnings.push(
            `   → For informational output, use: {systemMessage: "..."} (Stop hooks don't support hookSpecificOutput)`
          );
        }

        // Check for incorrect continue:false usage
        if (content.includes('"continue": false') || content.includes("continue: false")) {
          // This is valid for hard stop, but warn if it seems like "allow stop" intent
          const beforeContinue = content.substring(0, content.indexOf("continue"));
          if (beforeContinue.includes("allow") || beforeContinue.includes("normal")) {
            warnings.push(
              `${relPath}: "continue: false" means HARD STOP, not "allow normal stop". Use {} for allow stop.`
            );
          }
        }
      }

      // === PRETOOLUSE HOOK VALIDATION ===
      if (hookType === "PreToolUse") {
        const hasDecisionBlock =
          content.includes('"decision": "block"') ||
          content.includes("decision: \"block\"") ||
          content.includes('decision: "block"');

        const hasDecisionAllow =
          content.includes('"decision": "allow"') ||
          content.includes("decision: \"allow\"") ||
          content.includes('decision: "allow"');

        const hasPermissionDecision = content.includes("permissionDecision");

        if (hasDecisionBlock && !hasPermissionDecision) {
          warnings.push(
            `${relPath}: PreToolUse hook uses deprecated "decision: block". Use permissionDecision: "deny" instead.`
          );
          warnings.push(
            `   → Use: {hookSpecificOutput: {permissionDecision: "deny", permissionDecisionReason: "..."}}`
          );
        }

        if (hasDecisionAllow && !hasPermissionDecision) {
          warnings.push(
            `${relPath}: PreToolUse hook uses deprecated "decision: allow". Use permissionDecision: "allow" instead.`
          );
          warnings.push(
            `   → Use: {hookSpecificOutput: {permissionDecision: "allow"}} or just exit 0 with no output`
          );
        }
      }

      // === POSTTOOLUSE HOOK VALIDATION ===
      if (hookType === "PostToolUse") {
        const hasDecisionBlock =
          content.includes('"decision": "block"') ||
          content.includes("decision: \"block\"") ||
          content.includes('decision: "block"') ||
          content.includes("{decision: \"block\"");

        // Check for jq output without decision:block
        if (!hasDecisionBlock && content.includes("jq")) {
          // Check if it's actually emitting JSON (not just parsing input)
          const hasJqOutput = content.match(/jq\s+(-n\s+)?.*'\{/);
          if (hasJqOutput) {
            warnings.push(
              `${relPath}: PostToolUse hook may be missing "decision: block" - output won't be visible to Claude`
            );
          }
        }

        // Check for extra fields that won't be visible
        lines.forEach((line, index) => {
          const lineNum = index + 1;

          // Pattern 1: jq -n with field definitions
          const jqObjectMatch = line.match(/jq\s+(-n\s+)?.*'\{([^}]+)\}'/);
          if (jqObjectMatch) {
            const objectContent = jqObjectMatch[2];
            const fieldPattern = /["']?(\w+)["']?\s*:/g;
            let fieldMatch;
            const foundFields = new Set();

            while ((fieldMatch = fieldPattern.exec(objectContent)) !== null) {
              foundFields.add(fieldMatch[1]);
            }

            const invisibleFields = [...foundFields].filter(
              (f) => !CLAUDE_VISIBLE_FIELDS.has(f) && !OPTIONAL_FIELDS.has(f)
            );

            if (invisibleFields.length > 0) {
              fileIssues.push({
                line: lineNum,
                fields: invisibleFields,
                lineContent: line.trim().substring(0, 80),
              });
            }
          }

          // Pattern 2: echo with JSON
          const echoJsonMatch = line.match(/echo\s+['"]?\{([^}]+)\}['"]?/);
          if (echoJsonMatch) {
            const jsonContent = echoJsonMatch[1];
            const fieldPattern = /"(\w+)"\s*:/g;
            let fieldMatch;
            const foundFields = new Set();

            while ((fieldMatch = fieldPattern.exec(jsonContent)) !== null) {
              foundFields.add(fieldMatch[1]);
            }

            const invisibleFields = [...foundFields].filter(
              (f) => !CLAUDE_VISIBLE_FIELDS.has(f) && !OPTIONAL_FIELDS.has(f)
            );

            if (invisibleFields.length > 0) {
              fileIssues.push({
                line: lineNum,
                fields: invisibleFields,
                lineContent: line.trim().substring(0, 80),
              });
            }
          }
        });

        // Report invisible field issues
        if (fileIssues.length > 0) {
          warnings.push(
            `${relPath}: Hook outputs fields invisible to Claude Code`
          );
          fileIssues.forEach((issue) => {
            warnings.push(
              `   Line ${issue.line}: Fields [${issue.fields.join(", ")}] will be LOGGED but NOT VISIBLE to Claude`
            );
            warnings.push(
              `   → Move content into "reason" field for Claude to see it`
            );
          });
        }
      }

      // === UNKNOWN HOOK TYPE ===
      if (hookType === "unknown" && content.includes("jq")) {
        warnings.push(
          `${relPath}: Could not determine hook type - verify output format manually`
        );
      }

      // === COMMON HOOK PITFALLS ===
      // Each of these encodes a hook that shipped, ran, and reported the wrong
      // thing. They are cheap to check and expensive to rediscover.

      // Pitfall 1: Checking command output without filtering success messages
      // e.g., ruff outputs "All checks passed!" which is non-empty but not an error
      // Exception: --output-format=json outputs [] on success, not a message
      if (
        content.includes("ruff check") &&
        !content.includes("--output-format=json") &&
        content.match(/\[\[\s*-n\s+"\$[A-Z_]*OUTPUT"/) &&
        !content.includes('grep -v "All checks passed"')
      ) {
        warnings.push(
          `${relPath}: Ruff output check may trigger false positives - ruff outputs "All checks passed!" on success`
        );
        warnings.push(
          `   → Filter with: | grep -v "All checks passed" | before storing output`
        );
      }

      // Pitfall 2: Path comparison without handling relative paths
      // e.g., using eval echo without CLAUDE_PROJECT_DIR for relative paths
      if (
        content.includes("eval echo") &&
        content.match(/\[\[.*==.*"\$HOME/) &&
        !content.includes("CLAUDE_PROJECT_DIR")
      ) {
        warnings.push(
          `${relPath}: Path comparison may fail for relative paths - eval echo doesn't convert relative to absolute`
        );
        warnings.push(
          `   → Use CLAUDE_PROJECT_DIR to resolve relative paths before comparison`
        );
      }

      // Pitfall 3: PostToolUse hooks emitting reminders for code files without content verification.
      // A traceability reminder that fires on the file extension alone keeps firing
      // after the condition is already satisfied, and gets tuned out.
      // Pattern: Sets REMINDER for file extensions but doesn't verify condition with file content
      if (
        hookType === "PostToolUse" &&
        content.match(/\.(py|ts|js|mjs|rs|go)\$/) &&  // Checks for code file extensions
        content.match(/REMINDER\s*=\s*["'][^"']+TRACEABILITY|REMINDER\s*=\s*["'][^"']+Consider/) &&  // Sets reminder
        !content.match(/head\s+-?\d+|grep\s+-[qE]|cat\s+["']?\$FILE/) // Doesn't check file content
      ) {
        warnings.push(
          `${relPath}: PostToolUse hook may emit false positive reminders - sets reminder for code files without checking file content`
        );
        warnings.push(
          `   → Before emitting traceability reminders, check if condition already satisfied: head -50 "$FILE" | grep -qE 'pattern'`
        );
      }

    } catch (err) {
      warnings.push(`Could not validate hook: ${path} (${err.message})`);
    }
  });

  return { errors, warnings };
}

/**
 * Validate hooks.json structure generated by manage-hooks.sh scripts
 * Extracts jq expressions, runs them, and validates output against schema
 *
 * This catches regressions like:
 * - PreToolUse entry with an extra {"hooks": [...]} wrapper
 * - Invalid type values (must be 'command' | 'prompt' | 'agent')
 * - Missing required fields
 *
 * Why it validates the generator rather than the output: a malformed hook entry
 * surfaces on someone else's machine as "Invalid discriminator value" at install
 * time, long after the commit that caused it. Running the jq expression here
 * moves that failure back to the repository that produced it.
 *
 * Returns { errors: [...], warnings: [...] }
 */
async function validateHooksJsonStructure() {
  const errors = [];
  const warnings = [];

  if (!validateHooksSchema) {
    warnings.push("hooks.schema.json not loaded - skipping hook structure validation");
    return { errors, warnings };
  }

  // Find all manage-hooks.sh scripts
  const hookScripts = await glob("plugins/*/scripts/manage-hooks.sh", {
    cwd: process.cwd(),
    absolute: true,
    onlyFiles: true,
  });

  for (const scriptPath of hookScripts) {
    const relPath = relative(process.cwd(), scriptPath);
    const pluginName = relPath.split("/")[1];

    try {
      const content = readFileSync(scriptPath, "utf8");

      // Extract jq expressions that generate hook entries
      // Pattern: jq -n --arg ... '{...}' or jq -n '{...}'
      const jqExpressions = [];
      const jqPattern = /jq\s+-n\s+(?:--arg\s+\w+\s+"[^"]*"\s*)*'(\{[^']+\})'/g;
      let match;

      while ((match = jqPattern.exec(content)) !== null) {
        const lineNum = content.substring(0, match.index).split("\n").length;
        jqExpressions.push({
          expression: match[1],
          fullMatch: match[0],
          line: lineNum,
        });
      }

      // Validate each extracted jq expression
      for (const { expression, fullMatch, line } of jqExpressions) {
        // Skip expressions that are clearly not hook entries
        if (!expression.includes("type") && !expression.includes("matcher")) {
          continue;
        }

        // Run jq to get actual JSON output
        try {
          // Replace $cmd variable references with placeholder for validation
          const testExpr = expression.replace(/\$\w+/g, '"placeholder"');
          const jqCmd = `jq -n '${testExpr}'`;

          const output = execSync(jqCmd, {
            encoding: "utf8",
            timeout: 5000,
          }).trim();

          const jsonOutput = JSON.parse(output);

          // Determine what schema to validate against based on content
          if (jsonOutput.matcher !== undefined) {
            // This is a hookMatcher (PreToolUse, PostToolUse)
            validateHookMatcher(jsonOutput, relPath, line, errors, warnings);
          } else if (jsonOutput.hooks !== undefined) {
            // This is a hookEventArray entry (Stop, SubagentStop)
            validateHookEventEntry(jsonOutput, relPath, line, errors, warnings);
          }
        } catch (jqErr) {
          warnings.push(
            `${relPath}:${line}: Could not validate jq expression: ${jqErr.message}`
          );
        }
      }
    } catch (err) {
      warnings.push(`${relPath}: Could not read script: ${err.message}`);
    }
  }

  return { errors, warnings };
}

/**
 * Validate a hookMatcher entry (used for PreToolUse, PostToolUse)
 * Structure: { matcher?: string, hooks: hookDefinition[] }
 */
function validateHookMatcher(entry, file, line, errors, warnings) {
  // Must have hooks array
  if (!entry.hooks || !Array.isArray(entry.hooks)) {
    errors.push(
      `${file}:${line}: hookMatcher missing required 'hooks' array`
    );
    return;
  }

  // Hooks must not be nested in extra wrapper
  // Bug detection: {"hooks": [{"matcher": "...", "hooks": [...]}]} is WRONG
  // Correct: {"matcher": "...", "hooks": [{type, command}]}
  if (entry.hooks.length > 0) {
    const firstHook = entry.hooks[0];
    if (firstHook.matcher !== undefined) {
      errors.push(
        `${file}:${line}: INVALID NESTING - hook entry has nested 'matcher' inside 'hooks' array. ` +
        `This causes "Invalid discriminator value" error. ` +
        `Remove outer {"hooks": [...]} wrapper.`
      );
      return;
    }
  }

  // Validate each hook definition
  for (let i = 0; i < entry.hooks.length; i++) {
    const hook = entry.hooks[i];
    validateHookDefinition(hook, `${file}:${line}[${i}]`, errors, warnings);
  }
}

/**
 * Validate a hookEventEntry (used for Stop, SubagentStop events without matcher)
 * Structure: { hooks: hookDefinition[] }
 */
function validateHookEventEntry(entry, file, line, errors, warnings) {
  // Must have hooks array
  if (!Array.isArray(entry.hooks)) {
    errors.push(
      `${file}:${line}: hookEventEntry 'hooks' must be an array`
    );
    return;
  }

  // Validate each hook definition
  for (let i = 0; i < entry.hooks.length; i++) {
    const hook = entry.hooks[i];
    validateHookDefinition(hook, `${file}:${line}[${i}]`, errors, warnings);
  }
}

/**
 * Validate individual hook definition
 * Structure: { type: "command"|"prompt"|"agent", command?: string, prompt?: string, timeout?: number }
 */
function validateHookDefinition(hook, location, errors, warnings) {
  const validTypes = ["command", "prompt", "agent"];

  // Must have type field
  if (!hook.type) {
    errors.push(
      `${location}: hookDefinition missing required 'type' field`
    );
    return;
  }

  // Type must be valid enum value
  if (!validTypes.includes(hook.type)) {
    errors.push(
      `${location}: Invalid type '${hook.type}'. Expected: ${validTypes.join(" | ")}. ` +
      `This causes "Invalid discriminator value" error.`
    );
    return;
  }

  // Type-specific validation
  if (hook.type === "command" && !hook.command) {
    errors.push(
      `${location}: type "command" requires 'command' field`
    );
  }

  if (hook.type === "prompt" && !hook.prompt) {
    errors.push(
      `${location}: type "prompt" requires 'prompt' field`
    );
  }

  // Validate timeout if present
  if (hook.timeout !== undefined) {
    if (typeof hook.timeout !== "number" || hook.timeout < 1 || hook.timeout > 600000) {
      warnings.push(
        `${location}: timeout should be 1-600000ms, got ${hook.timeout}`
      );
    }
  }
}

/**
 * Validate that referenced skills actually exist in target plugins
 * Returns { errors: [...], warnings: [...] }
 */
function validateSkillExistence(details) {
  const pluginsDir = resolve(process.cwd(), "plugins");
  const errors = [];
  const warnings = [];
  const checked = new Set(); // Avoid duplicate checks

  details.forEach((dep) => {
    const key = `${dep.to}:${dep.skill}`;
    if (checked.has(key)) return;
    checked.add(key);

    const targetPluginDir = join(pluginsDir, dep.to);

    // Check if target plugin exists
    if (!existsSync(targetPluginDir)) {
      errors.push(
        `Missing plugin '${dep.to}' referenced by ${dep.from} (${dep.file}:${dep.line})`
      );
      return;
    }

    // Check if skill exists in commands/ or skills/
    const commandPath = join(targetPluginDir, "commands", `${dep.skill}.md`);
    const skillDir = join(targetPluginDir, "skills", dep.skill);
    const skillPath = join(skillDir, "SKILL.md");

    const commandExists = existsSync(commandPath);
    const skillExists = existsSync(skillDir) && existsSync(skillPath);

    if (!commandExists && !skillExists) {
      warnings.push(
        `Skill '${dep.skill}' not found in plugin '${dep.to}' - referenced by ${dep.from} (${dep.file}:${dep.line})`
      );
    }
  });

  return { errors, warnings };
}

/**
 * Validate skills frontmatter completeness.
 *
 * Rule: every skills/{skill}/SKILL.md must have 'name' and 'description' in its
 * YAML frontmatter. That frontmatter is the single source for both the model's
 * view of the skill and its user-invocable slash command, so a skill missing it
 * is installed but undiscoverable.
 *
 * Returns { errors: [...], warnings: [...] }
 */
async function validateAllSkillsFrontmatter() {
  const errors = [];
  const warnings = [];

  const skillPaths = await glob("plugins/*/skills/*/SKILL.md", {
    cwd: process.cwd(),
    absolute: true,
    onlyFiles: true,
  });

  for (const skillPath of skillPaths) {
    const relPath = relative(process.cwd(), skillPath);
    try {
      const content = readFileSync(skillPath, "utf8");
      const fmMatch = content.match(/^---\n([\s\S]*?)\n---/);
      if (!fmMatch) {
        errors.push(`${relPath}: SKILL.md missing YAML frontmatter`);
        continue;
      }
      const fm = fmMatch[1];
      if (!fm.includes("name:")) errors.push(`${relPath}: missing 'name' in frontmatter`);
      if (!fm.includes("description:")) errors.push(`${relPath}: missing 'description' in frontmatter`);
    } catch (err) {
      warnings.push(`Could not validate skill frontmatter: ${relPath} (${err.message})`);
    }
  }

  return { errors, warnings };
}

/**
 * Extract declared dependencies from marketplace.json 'requires' field
 * Returns Map<plugin, string[]> of declared dependencies
 */
function getDeclaredDependencies() {
  const data = getMarketplaceData();
  const plugins = data.plugins || [];
  const deps = new Map();

  plugins.forEach((plugin) => {
    if (plugin.requires && Array.isArray(plugin.requires)) {
      deps.set(plugin.name, plugin.requires);
    }
  });

  return deps;
}

/**
 * Validate declared dependencies match detected dependencies
 * Returns { errors: [...], warnings: [...] }
 */
function validateDeclaredDependencies(declaredDeps, detectedGraph) {
  const errors = [];
  const warnings = [];
  const registeredPlugins = getRegisteredPlugins();

  // Check declared dependencies exist
  for (const [plugin, requires] of declaredDeps.entries()) {
    for (const req of requires) {
      if (!registeredPlugins.includes(req)) {
        errors.push(
          `Plugin '${plugin}' requires '${req}' which is not registered in marketplace`
        );
      }
    }
  }

  // Note: 'requires' field is not yet supported by Claude Code (see issue #9444)
  // These checks are disabled until the feature is implemented
  // Dependencies are detected automatically via Skill() call analysis

  return { errors, warnings };
}

/**
 * Generate installation instructions with dependencies
 */
function generateInstallInstructions(declaredDeps) {
  const lines = [];

  // Find plugins with dependencies
  const pluginsWithDeps = [...declaredDeps.entries()].filter(
    ([_, deps]) => deps.length > 0
  );

  if (pluginsWithDeps.length === 0) {
    return "";
  }

  const marketplace = getMarketplaceName() ?? "<marketplace>";

  lines.push("\n📋 Installation Instructions (with dependencies):");
  lines.push("─".repeat(50));

  for (const [plugin, requires] of pluginsWithDeps) {
    const allDeps = resolveTransitiveDeps(plugin, declaredDeps, new Set());
    // Remove the plugin itself from deps and dedupe
    allDeps.delete(plugin);
    const installOrder = [...allDeps, plugin];

    // Skip if only self (circular with no other deps)
    if (installOrder.length === 1 && installOrder[0] === plugin) {
      lines.push(`\n   ${plugin}: (circular dependency - install with peer)`);
      const peers = requires.filter(r => declaredDeps.has(r) && declaredDeps.get(r).includes(plugin));
      if (peers.length > 0) {
        lines.push(`   # Install together: ${plugin}, ${peers.join(", ")}`);
      }
      continue;
    }

    lines.push(`\n   ${plugin}:`);
    lines.push(`   # Install in order (dependencies first):`);
    installOrder.forEach((p, i) => {
      const marker = i === installOrder.length - 1 ? "→" : " ";
      // Order is plugin@marketplace, not marketplace@plugin — pasting the
      // reversed form fails with a confusing "not found" for a plugin that exists.
      lines.push(`   ${marker} /plugin install ${p}@${marketplace}`);
    });
  }

  return lines.join("\n");
}

/**
 * Resolve transitive dependencies (recursive)
 */
function resolveTransitiveDeps(plugin, declaredDeps, visited) {
  if (visited.has(plugin)) return new Set(); // Avoid circular
  visited.add(plugin);

  const direct = declaredDeps.get(plugin) || [];
  const all = new Set();

  for (const dep of direct) {
    // Add transitive deps first
    const transitive = resolveTransitiveDeps(dep, declaredDeps, visited);
    for (const t of transitive) {
      all.add(t);
    }
    all.add(dep);
  }

  return all;
}

/**
 * Format dependency graph for display
 */
function formatDependencyGraph(graph, details) {
  const lines = [];
  const registeredPlugins = getRegisteredPlugins();

  lines.push("\n📊 Inter-Plugin Dependency Graph:");
  lines.push("─".repeat(50));

  if (graph.size === 0) {
    lines.push("   No inter-plugin dependencies found.");
    return lines.join("\n");
  }

  // Group by source plugin
  for (const [plugin, deps] of graph.entries()) {
    const depsArray = [...deps];
    const isRegistered = (p) => registeredPlugins.includes(p);

    lines.push(`\n   ${plugin} depends on:`);
    depsArray.forEach((dep) => {
      const status = isRegistered(dep) ? "✓" : "✗";
      const depDetails = details.filter(
        (d) => d.from === plugin && d.to === dep
      );
      const skills = [...new Set(depDetails.map((d) => d.skill))].join(", ");
      lines.push(`      ${status} ${dep} (skills: ${skills})`);
    });
  }

  // Summary
  const allDeps = new Set();
  for (const deps of graph.values()) {
    for (const dep of deps) {
      allDeps.add(dep);
    }
  }

  lines.push("\n" + "─".repeat(50));
  lines.push(
    `   ${graph.size} plugins have dependencies on ${allDeps.size} other plugins`
  );

  return lines.join("\n");
}

/**
 * Validate ~/.claude/settings.json for shadow hooks.
 *
 * A "shadow hook" is a hook registered from outside this marketplace whose
 * script basename matches one this marketplace installs. Both fire, so every
 * effect happens twice: duplicate log entries, duplicate API calls, and two
 * block/allow decisions racing for the same tool call.
 *
 * Example: a hand-written ~/.claude/automation/.../wrapper.sh shadows the
 *          installed .../plugins/marketplaces/<marketplace>/.../wrapper.sh
 *
 * Ownership is decided by the INSTALL PATH, not by a substring of the
 * marketplace name. A bare name match would classify any command containing
 * that word — including unrelated paths under ~/.claude/skills/ — as this
 * marketplace's own, and then silently fail to report the real duplicate.
 *
 * Returns { errors: [...], warnings: [...] }
 */
function validateSettingsHookShadows() {
  const errors = [];
  const warnings = [];

  const home = process.env.HOME;
  if (!home) {
    warnings.push("HOME is not set — skipping settings.json shadow-hook check");
    return { errors, warnings };
  }

  const marketplaceName = getMarketplaceName();
  if (!marketplaceName) {
    warnings.push("marketplace.json has no 'name' — skipping settings.json shadow-hook check");
    return { errors, warnings };
  }

  // Claude Code installs a marketplace under plugins/marketplaces/<name>/ and
  // caches versioned copies under plugins/cache/<name>/. Anchor on those.
  const ownedPath = new RegExp(
    `/plugins/(?:marketplaces|cache)/${marketplaceName.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?:/|$)`
  );

  const settingsPath = join(home, ".claude", "settings.json");

  if (!existsSync(settingsPath)) {
    return { errors, warnings };
  }

  let settings;
  try {
    settings = JSON.parse(readFileSync(settingsPath, "utf8"));
  } catch {
    warnings.push("Could not parse ~/.claude/settings.json");
    return { errors, warnings };
  }

  const hookTypes = ["PreToolUse", "PostToolUse", "Stop"];

  for (const hookType of hookTypes) {
    const entries = settings.hooks?.[hookType] ?? [];

    // Extract command strings from each hook entry (handles nested .hooks[] structure)
    const getCommands = (entry) => {
      const cmds = [];
      if (entry.command) cmds.push(entry.command);
      if (Array.isArray(entry.hooks)) {
        for (const h of entry.hooks) {
          if (h.command) cmds.push(h.command);
        }
      }
      return cmds;
    };

    // Extract script basename from a command string
    const scriptBasename = (cmd) => {
      // Take last path component, stripping any leading runner (bash, bun, env, etc.)
      const parts = cmd.split(/\s+/);
      // Find the part that looks like a file path
      const pathPart = parts.find(p => p.includes("/")) || parts[parts.length - 1];
      return pathPart.split("/").pop();
    };

    // Split into hooks this marketplace installed and everything else
    const ownedBasenames = new Map(); // basename → full command
    const foreignEntries = []; // { basename, command }

    for (const entry of entries) {
      for (const cmd of getCommands(entry)) {
        const bn = scriptBasename(cmd);
        if (ownedPath.test(cmd)) {
          ownedBasenames.set(bn, cmd);
        } else {
          foreignEntries.push({ basename: bn, command: cmd });
        }
      }
    }

    // Check for shadows
    for (const { basename: bn, command } of foreignEntries) {
      if (ownedBasenames.has(bn)) {
        errors.push(
          `Shadow hook in ${hookType}: '${command}' duplicates '${ownedBasenames.get(bn)}' from marketplace '${marketplaceName}' (same basename '${bn}')`
        );
      }
    }
  }

  return { errors, warnings };
}

// Main validation - wrapped in async IIFE for tinyglobby async functions
(async () => {
const registered = getRegisteredPlugins();
const directories = getPluginDirectories();

const unregistered = directories.filter(d => !registered.includes(d));
const orphaned = registered.filter(r => !directories.includes(r));
const { errors: entryErrors, warnings: entryWarnings } = validateMarketplaceEntries();

console.log(`📦 Registered plugins: ${registered.length}`);
console.log(`📁 Plugin directories: ${directories.length}`);
if (registered.length === 0 && directories.length === 0) {
  console.log(`   (empty marketplace — valid; the registry has no plugins yet)`);
}

let hasErrors = false;
let hasWarnings = false;

// Check for unregistered directories. This is the check that catches a plugin
// which exists on disk, works locally, and is invisible to everyone else because
// nothing ever added it to the registry — a failure mode that produces no error
// anywhere until a user reports the plugin missing.
if (unregistered.length > 0) {
  console.error(`\n❌ Unregistered plugin directories (${unregistered.length}):`);
  unregistered.forEach(p => console.error(`   - plugins/${p}/`));
  hasErrors = true;

  if (SHOW_FIX) {
    // Take the author from the marketplace owner so this template cannot drift
    // from the manifest it is telling you to edit.
    const owner = getMarketplaceData().owner ?? {
      name: "nasimubd",
      url: "https://github.com/nasimubd",
    };
    const authorJson = JSON.stringify({ name: owner.name, ...(owner.url ? { url: owner.url } : {}) });

    console.log(`\n📝 To fix, add entries to .claude-plugin/marketplace.json:`);
    if (CATEGORIES.length > 0) {
      console.log(`   Replace "category" with one of: ${CATEGORIES.join(", ")}`);
    }
    unregistered.forEach(p => {
      // Emitted deliberately schema-valid, so that pasting it produces a tree
      // that passes rather than one that fails on the very next run:
      //   - "source" has no trailing slash (pattern is ^\./plugins/[a-z0-9-]+$)
      //   - "category" is a real enum member
      //   - "keywords" is OMITTED, not an empty array: keywords has minItems 1,
      //     so [] is an ERROR, while leaving it out is a WARNING telling you to
      //     add real ones. The nudge survives; the hard failure does not.
      console.log(`
    {
      "name": "${p}",
      "description": "TODO: Add description",
      "version": "0.1.0",
      "source": "./plugins/${p}",
      "category": "utilities",
      "author": ${authorJson},
      "strict": false
    }`);
    });
  }
}

// Check for entry validation errors (missing fields, invalid paths)
if (entryErrors.length > 0) {
  console.error(`\n❌ Marketplace entry errors (${entryErrors.length}):`);
  entryErrors.forEach(e => console.error(`   - ${e}`));
  hasErrors = true;
}

// Check for orphaned entries
if (orphaned.length > 0) {
  console.warn(`\n⚠️  Orphaned entries in marketplace.json (no directory):`);
  orphaned.forEach(p => console.warn(`   - ${p}`));
  hasWarnings = true;
}

// Check for entry warnings (missing recommended fields)
if (entryWarnings.length > 0) {
  console.warn(`\n⚠️  Marketplace entry warnings (${entryWarnings.length}):`);
  entryWarnings.forEach(w => console.warn(`   - ${w}`));
  hasWarnings = true;
}

// Dependency validation (detected from Skill() calls) - async with tinyglobby
const { graph: depGraph, details: depDetails } = await buildDependencyGraph();
const cycles = detectCircularDependencies(depGraph);
const { errors: depErrors, warnings: depWarnings } = validateSkillExistence(depDetails);

// Hook output format validation (what Claude Code actually reads) - async with tinyglobby
const { errors: hookErrors, warnings: hookWarnings } = await validateHookOutputFormat();

// Hook JSON structure validation (manage-hooks.sh jq expressions) - async with tinyglobby
// Catches the malformed shapes that surface at install time as "Invalid discriminator value"
const { errors: hookStructErrors, warnings: hookStructWarnings } = await validateHooksJsonStructure();

// Skills frontmatter validation (all skills/*/SKILL.md must have name + description)
const { errors: skillsFrontmatterErrors, warnings: skillsFrontmatterWarnings } = await validateAllSkillsFrontmatter();

// Declared dependency validation (from 'requires' field in marketplace.json)
const declaredDeps = getDeclaredDependencies();
const { errors: declErrors, warnings: declWarnings } = validateDeclaredDependencies(declaredDeps, depGraph);

// Settings.json shadow hook validation (prevents double-firing from duplicate hooks)
const { errors: shadowErrors, warnings: shadowWarnings } = validateSettingsHookShadows();

// Report circular dependencies
if (cycles.length > 0) {
  console.warn(`\n🔄 Circular dependencies detected (${cycles.length}):`);
  cycles.forEach((cycle) => {
    console.warn(`   - ${cycle.join(" → ")}`);
  });
  hasWarnings = true;
}

// Report missing plugins/skills (from Skill() detection)
if (depErrors.length > 0) {
  console.error(`\n❌ MISSING PLUGIN DEPENDENCIES (${depErrors.length}):`);
  depErrors.forEach((e) => console.error(`   - ${e}`));
  hasErrors = true;
}

if (depWarnings.length > 0) {
  console.warn(`\n⚠️  Missing skill references (${depWarnings.length}):`);
  depWarnings.forEach((w) => console.warn(`   - ${w}`));
  hasWarnings = true;
}

// Report declared dependency issues (from 'requires' field validation)
if (declErrors.length > 0) {
  console.error(`\n❌ MARKETPLACE.JSON 'requires' FIELD ERRORS (${declErrors.length}):`);
  declErrors.forEach((e) => console.error(`   - ${e}`));
  hasErrors = true;
}

if (declWarnings.length > 0) {
  console.warn(`\n⚠️  Declared dependency mismatches (${declWarnings.length}):`);
  declWarnings.forEach((w) => console.warn(`   - ${w}`));
  hasWarnings = true;
}

// Report hook output format issues
if (hookErrors.length > 0) {
  console.error(`\n❌ HOOK OUTPUT FORMAT ERRORS (${hookErrors.length}):`);
  hookErrors.forEach((e) => console.error(`   - ${e}`));
  hasErrors = true;
}

if (hookWarnings.length > 0) {
  console.warn(`\n⚠️  Hook output format issues (${hookWarnings.length}):`);
  console.warn(`   Claude Code only reads "decision" and "reason" fields from PostToolUse JSON.`);
  console.warn(`   Other fields are logged but NOT visible to Claude.`);
  hookWarnings.forEach((w) => console.warn(`   - ${w}`));
  hasWarnings = true;
}

// Report skills frontmatter errors (name + description required in every SKILL.md)
if (skillsFrontmatterErrors.length > 0) {
  console.error(`\n❌ SKILLS FRONTMATTER ERRORS (${skillsFrontmatterErrors.length}):`);
  console.error(`   All skills/*/SKILL.md must have 'name' and 'description' in YAML frontmatter`);
  skillsFrontmatterErrors.forEach((e) => console.error(`   - ${e}`));
  hasErrors = true;
}

if (skillsFrontmatterWarnings.length > 0) {
  console.warn(`\n⚠️  Skills frontmatter warnings (${skillsFrontmatterWarnings.length}):`);
  skillsFrontmatterWarnings.forEach((w) => console.warn(`   - ${w}`));
  hasWarnings = true;
}

// Report hook structure issues (manage-hooks.sh jq validation)
if (hookStructErrors.length > 0) {
  console.error(`\n❌ HOOK JSON STRUCTURE ERRORS (${hookStructErrors.length}):`);
  console.error(`   These will cause "Invalid discriminator value" errors when installing hooks.`);
  hookStructErrors.forEach((e) => console.error(`   - ${e}`));
  hasErrors = true;
}

if (hookStructWarnings.length > 0) {
  console.warn(`\n⚠️  Hook structure warnings (${hookStructWarnings.length}):`);
  hookStructWarnings.forEach((w) => console.warn(`   - ${w}`));
  hasWarnings = true;
}

// Report shadow hook issues (double-firing from duplicate registrations in settings.json)
if (shadowErrors.length > 0) {
  console.error(`\n❌ SHADOW HOOK ERRORS (${shadowErrors.length}):`);
  console.error(`   A hook registered outside this marketplace shares a script basename with`);
  console.error(`   one this marketplace installs, so both fire on every event.`);
  console.error(`   Remove the outside duplicate from ~/.claude/settings.json.`);
  shadowErrors.forEach((e) => console.error(`   - ${e}`));
  hasErrors = true;
}

if (shadowWarnings.length > 0) {
  console.warn(`\n⚠️  Shadow hook warnings (${shadowWarnings.length}):`);
  shadowWarnings.forEach((w) => console.warn(`   - ${w}`));
  hasWarnings = true;
}

// Show declared dependencies summary
if (declaredDeps.size > 0) {
  console.log(`\n📦 Declared Dependencies (marketplace.json 'requires'):`);
  for (const [plugin, requires] of declaredDeps.entries()) {
    console.log(`   ${plugin} → [${requires.join(", ")}]`);
  }
}

// Show dependency graph if requested
if (SHOW_DEPS) {
  console.log(formatDependencyGraph(depGraph, depDetails));
}

// Collect all issues for explicit summary
const allErrors = [
  ...(unregistered.length > 0 ? [`${unregistered.length} unregistered plugins`] : []),
  ...entryErrors,
  ...depErrors,
  ...declErrors,
  ...hookErrors,
  ...hookStructErrors,
  ...skillsFrontmatterErrors,
  ...shadowErrors,
];
const allWarnings = [
  ...(orphaned.length > 0 ? [`${orphaned.length} orphaned entries`] : []),
  ...entryWarnings,
  ...depWarnings,
  ...declWarnings,
  ...hookWarnings,
  ...hookStructWarnings,
  ...skillsFrontmatterWarnings,
  ...shadowWarnings,
  ...(cycles.length > 0 ? [`${cycles.length} circular dependencies`] : []),
];

// Show installation instructions if --deps flag
if (SHOW_DEPS && declaredDeps.size > 0) {
  console.log(generateInstallInstructions(declaredDeps));
}

// Exit with appropriate code - LOUD and EXPLICIT for Claude Code
console.log("\n" + "═".repeat(60));
console.log("VALIDATION SUMMARY");
console.log("═".repeat(60));
console.log(`Errors:   ${allErrors.length}`);
console.log(`Warnings: ${allWarnings.length}`);
console.log(`Plugins:  ${directories.length} directories, ${registered.length} registered`);
// Count skills across all plugins (canonical source: skills/{name}/SKILL.md).
// Printed unconditionally, including as 0: a line that disappears when the count
// is zero is indistinguishable from a counter that never ran.
const skillCount = (getMarketplaceData().plugins || []).reduce((count, p) => {
  if (p.source) {
    const skillsDir = resolve(process.cwd(), p.source, "skills");
    if (existsSync(skillsDir)) {
      count += readdirSync(skillsDir).filter(d => {
        return existsSync(join(skillsDir, d, "SKILL.md"));
      }).length;
    }
  }
  return count;
}, 0);
console.log(`Skills:   ${skillCount} skill(s) across registered plugins`);
console.log(`Dependencies: ${depGraph.size} plugins depend on ${[...new Set([...depGraph.values()].flatMap(s => [...s]))].length} others`);
console.log("═".repeat(60));

if (hasErrors) {
  console.error(`\n❌ VALIDATION FAILED - ${allErrors.length} error(s) must be fixed`);
  console.error(`   Run: bun scripts/validate-plugins.mjs --fix`);
  process.exit(1);
} else if (hasWarnings && STRICT_MODE) {
  console.error(`\n❌ VALIDATION FAILED (strict mode) - ${allWarnings.length} warning(s) must be fixed`);
  process.exit(1);
} else if (hasWarnings) {
  console.log(`\n⚠️  VALIDATION PASSED WITH ${allWarnings.length} WARNING(S)`);
  if (!SHOW_DEPS && depGraph.size > 0) {
    console.log(`   Run with --deps to see inter-plugin dependency graph.`);
  }
  process.exit(0);
} else if (directories.length === 0 && registered.length === 0) {
  // Say what was checked, not just that a check passed. "All 0 plugins valid"
  // reads as a pass that examined something; this reads as what it is.
  console.log(`\n✅ VALIDATION PASSED - empty marketplace, 0 plugins to validate`);
  console.log(`   Marketplace metadata is schema-valid; there is nothing registered yet.`);
  process.exit(0);
} else {
  console.log(`\n✅ VALIDATION PASSED - All ${directories.length} plugins valid`);
  if (!SHOW_DEPS && depGraph.size > 0) {
    console.log(`   Run with --deps to see inter-plugin dependency graph.`);
  }
  process.exit(0);
}
})();
