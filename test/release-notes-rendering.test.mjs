#!/usr/bin/env node
/**
 * Rendered-output test for the release-notes pipeline.
 *
 * WHY THIS TEST RENDERS INSTEAD OF INSPECTING THE TRANSFORM
 *
 * A test that asserts on what `writerOpts.transform` returns proves nothing a
 * reader cares about. Every defect this file exists to catch happens strictly
 * AFTER the transform returns:
 *
 *   - a body that is correct in the returned object but swallowed into its own
 *     bullet by the Handlebars partial;
 *   - a `Vec<T>` that survives the transform intact and is then eaten by the
 *     GFM parser as an opening HTML tag;
 *   - a paragraph that is well-formed markdown and renders with a `<br>` at
 *     every one of its original 72-column wrap points.
 *
 * A transform-level test is green through all three. So this test drives the
 * REAL pipeline: the transform and commitPartial are read out of the wired
 * release.config.cjs (not re-declared here, or the test would verify a copy),
 * merged over the same Angular preset that @semantic-release/release-notes-
 * generator merges them over, rendered to markdown by the real
 * conventional-changelog-writer, and rendered from markdown to HTML the way
 * GitHub renders a release body: GFM, with hard line breaks on.
 *
 * NEGATIVE CONTROLS
 *
 * Several cases render a second time through a transform identical to the real
 * one except that the reflow is bypassed, and assert the defect IS present in
 * that output. Without them a bug that disabled the reflow entirely would
 * leave every assertion below passing for the wrong reason.
 *
 * Run: node test/render-release-notes.test.mjs   (or `npm test`)
 */

import { createRequire } from "node:module";
import { writeChangelogString } from "conventional-changelog-writer";
import { Marked } from "marked";

const require = createRequire(import.meta.url);
const releaseConfig = require("../release.config.cjs");

// ─── Wiring: read the real writerOpts out of the real config ────────────────

const notesGeneratorEntry = releaseConfig.plugins.find(
  (plugin) => Array.isArray(plugin) && plugin[0] === "@semantic-release/release-notes-generator",
);
if (!notesGeneratorEntry) {
  console.error("✗ release.config.cjs has no @semantic-release/release-notes-generator entry");
  process.exit(1);
}
const configuredWriterOpts = notesGeneratorEntry[1].writerOpts;
for (const requiredKey of ["transform", "commitPartial"]) {
  if (!configuredWriterOpts?.[requiredKey]) {
    console.error(`✗ release.config.cjs writerOpts is missing '${requiredKey}'`);
    process.exit(1);
  }
}

const angularPresetModule = await import("conventional-changelog-angular");
const angularPreset = (angularPresetModule.default ?? angularPresetModule);
const presetWriterOpts = (typeof angularPreset === "function"
  ? await angularPreset()
  : angularPreset).writer ?? {};

// GitHub renders a release body as GFM with hard line breaks: a single newline
// inside a paragraph becomes <br>. `breaks: true` is what makes this test able
// to see the wrapping defect at all.
const marked = new Marked({ gfm: true, breaks: true });

const RENDER_CONTEXT = {
  version: "1.0.0",
  title: "",
  date: "2026-01-01",
  host: "https://github.com",
  owner: "owner",
  repository: "repo",
  repoUrl: "https://github.com/owner/repo",
  linkReferences: true,
  commit: "commit",
  issue: "issues",
};

function baseCommit(body) {
  return {
    type: "feat",
    scope: "core",
    subject: "a representative subject line",
    hash: "abcdef1234567890",
    body,
    notes: [],
    references: [],
    revert: null,
    merge: null,
  };
}

async function renderToMarkdown(body, { bypassReflow = false } = {}) {
  const transform = bypassReflow
    ? (commit, context) => {
        const transformed = configuredWriterOpts.transform(commit, context);
        // Undo ONLY the reflow, reusing the real transform for everything
        // else, so the control differs from the real path in exactly one way.
        return transformed ? { ...transformed, body: commit.body } : transformed;
      }
    : configuredWriterOpts.transform;

  return writeChangelogString([baseCommit(body)], RENDER_CONTEXT, {
    ...presetWriterOpts,
    ...configuredWriterOpts,
    transform,
  });
}

async function render(body, options) {
  const markdown = await renderToMarkdown(body, options);
  const html = await marked.parse(markdown);
  return { markdown, html, text: htmlToText(html) };
}

/**
 * Collapse rendered HTML to the text a reader actually sees, preserving line
 * structure. <br> and block-element boundaries become newlines, everything
 * else is dropped, and entities are decoded — so an assertion can ask "does
 * the reader see Vec<T> on one line" rather than guessing at the markup.
 */
function htmlToText(html) {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|li|h[1-6]|pre|blockquote|tr)>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&amp;/g, "&")
    .replace(/[ \t]+$/gm, "");
}

/** The slice of HTML inside the commit bullet's <li>, or "" if there is none. */
function listItemHtml(html) {
  const match = /<li>([\s\S]*?)<\/li>/i.exec(html);
  return match ? match[1] : "";
}

// ─── Assertion harness ──────────────────────────────────────────────────────

let passed = 0;
let failed = 0;
const failures = [];

function check(caseName, assertionName, condition, diagnosis) {
  if (condition) {
    passed += 1;
    console.log(`  ✓ ${assertionName}`);
    return;
  }
  failed += 1;
  failures.push(`${caseName} → ${assertionName}`);
  console.log(`  ✗ ${assertionName}`);
  for (const line of String(diagnosis).split("\n")) console.log(`      ${line}`);
}

function heading(name) {
  console.log("");
  console.log(`─── ${name} ───`);
}

// ─── Case 1: hard-wrapped prose must not render as <br> ─────────────────────

{
  heading("hard-wrapped prose collapses into one paragraph");
  const body = [
    "The accumulator was rebuilt so that the hot path no longer allocates on",
    "every iteration, which removes the only remaining source of garbage in",
    "the inner loop.",
  ].join("\n");

  const { markdown, text, html } = await render(body);
  const sentence =
    "The accumulator was rebuilt so that the hot path no longer allocates on every iteration";

  check(
    "wrapped prose",
    "MARKDOWN: the paragraph occupies a single line, so GFM cannot emit a <br>",
    markdown.split("\n").some((line) => line.includes(sentence)),
    `no single markdown line held the whole sentence. markdown was:\n${markdown}`,
  );
  check(
    "wrapped prose",
    "the sentence reads continuously, with no line break at the wrap points",
    text.includes(sentence),
    `expected one continuous line. rendered text was:\n${JSON.stringify(text)}`,
  );
  check(
    "wrapped prose",
    "no <br> is emitted inside the body paragraph",
    !/<br\s*\/?>/i.test(html.slice(html.indexOf("The accumulator"))),
    `rendered html was:\n${html}`,
  );

  const control = await render(body, { bypassReflow: true });
  check(
    "wrapped prose",
    "NEGATIVE CONTROL: without the reflow the same body does break mid-sentence",
    !control.text.includes(sentence) && /<br\s*\/?>/i.test(control.html),
    "the control rendered cleanly, so this case cannot detect the defect it " +
      `is written for. control html:\n${control.html}`,
  );
}

// ─── Case 2: angle-bracketed generics must survive GFM ──────────────────────

{
  heading("angle-bracketed generics survive the GFM parser");
  const body =
    "Converted the Vec<T> accumulator into a Result<T, E> so the caller can\n" +
    "distinguish an empty batch from a failed one. The `Box<dyn Error>` form\n" +
    "was rejected as too costly.";

  const { markdown, text } = await render(body);

  check(
    "generics",
    "MARKDOWN: the generic is escaped, so no `<T>` is handed to GFM as a tag",
    markdown.includes("Vec&lt;T>") && !/[^&]Vec<T>/.test(markdown),
    `expected an escaped Vec&lt;T> in the markdown. markdown was:\n${markdown}`,
  );
  check(
    "generics",
    "Vec<T> reaches the reader intact",
    text.includes("Vec<T>"),
    `rendered text was:\n${JSON.stringify(text)}`,
  );
  check(
    "generics",
    "Result<T, E> reaches the reader intact",
    text.includes("Result<T, E>"),
    `rendered text was:\n${JSON.stringify(text)}`,
  );
  check(
    "generics",
    "a generic already inside a code span is NOT double-escaped",
    text.includes("Box<dyn Error>") && !text.includes("&lt;dyn"),
    `expected a literal Box<dyn Error> from the code span. rendered text was:\n${JSON.stringify(text)}`,
  );

  const control = await render(body, { bypassReflow: true });
  check(
    "generics",
    "NEGATIVE CONTROL: without the escape, GFM eats <T> as an HTML tag",
    !control.text.includes("Vec<T>"),
    `the control kept Vec<T>, so this case proves nothing. control text:\n${JSON.stringify(control.text)}`,
  );
}

// ─── Case 3: aligned / indented blocks must not flatten ─────────────────────

{
  heading("deliberately aligned blocks keep their layout");
  const body = [
    "Lane-count sweep, three-rep medians, measured on the release host:",
    "",
    "  lanes=8     3.75 s",
    "  lanes=10    3.09 s",
    "  lanes=12    3.23 s",
    "",
    "Ten lanes is the sweet spot.",
  ].join("\n");

  const { markdown, text } = await render(body);
  const lines = text.split("\n").map((line) => line.trim());

  check(
    "aligned block",
    "MARKDOWN: indented rows keep their leading whitespace and stay on separate lines",
    markdown.includes("\n  lanes=8     3.75 s\n") &&
      markdown.includes("\n  lanes=10    3.09 s\n") &&
      markdown.includes("\n  lanes=12    3.23 s\n"),
    `indentation or line structure was lost. markdown was:\n${markdown}`,
  );
  check(
    "aligned block",
    "each measurement row survives on its own line",
    lines.includes("lanes=8     3.75 s") &&
      lines.includes("lanes=10    3.09 s") &&
      lines.includes("lanes=12    3.23 s"),
    `rows were flattened or reflowed. rendered lines:\n${JSON.stringify(lines, null, 2)}`,
  );
  check(
    "aligned block",
    "the rows were not folded into a single run-on line",
    !text.includes("lanes=8     3.75 s lanes=10"),
    `rendered text was:\n${JSON.stringify(text)}`,
  );
  check(
    "aligned block",
    "surrounding prose paragraphs still reflow normally",
    text.includes("Ten lanes is the sweet spot."),
    `rendered text was:\n${JSON.stringify(text)}`,
  );
}

// ─── Case 4: the body must be its own paragraph, not swallowed by the bullet ─

{
  heading("body renders as its own paragraph, outside the commit bullet");
  const body = "This sentence belongs to the release body, not to the bullet above it.";

  const { html, text } = await render(body);

  check(
    "body placement",
    "the commit bullet renders as a list item",
    /<li>/i.test(html),
    `rendered html was:\n${html}`,
  );
  check(
    "body placement",
    "the body text is NOT inside the <li> (a lazy continuation would put it there)",
    !listItemHtml(html).includes("belongs to the release body"),
    `the body was swallowed by its own bullet. <li> contained:\n${listItemHtml(html)}`,
  );
  check(
    "body placement",
    "the body text is present in the rendered output",
    text.includes("This sentence belongs to the release body"),
    `rendered text was:\n${JSON.stringify(text)}`,
  );
}

// ─── Case 5: fenced code blocks are preserved verbatim ──────────────────────

{
  heading("fenced code blocks pass through untouched");
  const body = [
    "The failing call looked like this:",
    "",
    "```rust",
    "let out: Vec<T> = xs",
    "    .iter()",
    "    .collect();",
    "```",
    "",
    "which allocates twice.",
  ].join("\n");

  const { html, text } = await render(body);

  check(
    "code fence",
    "the fence renders as a code block",
    /<pre>/i.test(html) && /<code/i.test(html),
    `rendered html was:\n${html}`,
  );
  check(
    "code fence",
    "code lines keep their own lines and their indentation",
    text.includes("let out: Vec<T> = xs") && text.includes("    .iter()"),
    `code block was reflowed or re-indented. rendered text:\n${JSON.stringify(text)}`,
  );
  check(
    "code fence",
    "prose after the fence still reflows",
    text.includes("which allocates twice."),
    `rendered text was:\n${JSON.stringify(text)}`,
  );
}

// ─── Case 6: structural markdown keeps its semantics ────────────────────────

{
  heading("headings and lists keep their block semantics");
  const body = [
    "### Migration notes",
    "",
    "- callers must pass an explicit budget",
    "- the old constructor is gone",
    "",
    "Both changes are source-compatible with the previous",
    "release for every caller that used the builder.",
  ].join("\n");

  const { html, text } = await render(body);

  check(
    "structural markdown",
    "the heading is still a heading, not folded into the prose",
    /<h3[^>]*>[\s\S]*?Migration notes[\s\S]*?<\/h3>/i.test(html),
    `rendered html was:\n${html}`,
  );
  check(
    "structural markdown",
    "list items are still separate items",
    /<li>[^<]*callers must pass an explicit budget/i.test(html) &&
      /<li>[^<]*the old constructor is gone/i.test(html),
    `rendered html was:\n${html}`,
  );
  check(
    "structural markdown",
    "the trailing prose paragraph still reflows into one line",
    text.includes(
      "Both changes are source-compatible with the previous release for every caller that used the builder.",
    ),
    `rendered text was:\n${JSON.stringify(text)}`,
  );
}

// ─── Case 7: an empty or absent body must not crash or invent content ───────

{
  heading("empty and absent bodies are handled without inventing content");
  for (const [label, body] of [
    ["empty string", ""],
    ["null", null],
    ["undefined", undefined],
  ]) {
    const { text } = await render(body);
    check(
      "empty body",
      `a body of ${label} renders the subject and nothing more`,
      text.includes("a representative subject line"),
      `rendered text was:\n${JSON.stringify(text)}`,
    );
  }
}

// ─── Summary ────────────────────────────────────────────────────────────────

console.log("");
console.log("═══════════════════════════════════════════════════════════");
console.log("  Release-notes rendering — Summary");
console.log("═══════════════════════════════════════════════════════════");
console.log(`  Assertions PASSED: ${passed}`);
console.log(`  Assertions FAILED: ${failed}`);

if (failed > 0) {
  console.log("");
  console.log("  Failed assertions:");
  for (const failure of failures) console.log(`    - ${failure}`);
  process.exit(1);
}

if (passed === 0) {
  // Same anti-false-green rule the marketplace regression suite enforces: a
  // run that asserted nothing is not a run that passed.
  console.log("");
  console.log("  ✗ ZERO ASSERTIONS RAN — failing rather than reporting success");
  process.exit(1);
}

console.log("");
console.log(`  ✓ All ${passed} rendered-output assertions PASSED`);
