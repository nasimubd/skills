/**
 * semantic-release configuration (CommonJS).
 *
 * This file is CommonJS rather than YAML because the release-notes generator
 * has to carry a body-preserving `writerOpts.transform` — a JavaScript function
 * that YAML cannot express. The default Angular preset's transform returns only
 * { notes, type, scope, shortHash, subject, references } and DROPS the commit
 * body, so multi-paragraph Conventional-Commit bodies never reach the published
 * notes. The transform below restores the body in both the returned object and
 * the commit template.
 *
 * IMPORTANT: exec command strings keep the literal `${nextRelease.version}`
 * token intact so it survives to @semantic-release/exec's lodash template step
 * — it must NOT be interpreted as a JS template expression here. Build it by
 * concatenation (see RELEASE_VERSION_PLACEHOLDER) and interpolate that value,
 * never a raw `${...}` inside a JS template literal.
 *
 * Config discovery: semantic-release finds `.releaserc.{yaml,yml}` BEFORE
 * `release.config.{js,cjs}`. Never add a `.releaserc.*` file to this
 * repository — it would silently shadow this one, and every lesson encoded
 * below would stop applying with no error and no warning.
 */

const COMMIT_HASH_DISPLAY_LENGTH = 7;

/**
 * The literal `${nextRelease.version}` token that @semantic-release/exec expands
 * via lodash template at release time. Built by concatenation so it is NOT a JS
 * template placeholder here (that would resolve to `undefined` at require time,
 * and also trips linters' no-template-curly-in-string rule). Interpolate it into
 * exec command strings via a template literal — the value below is what survives
 * to lodash. (Assembled from a variable + a literal so neither
 * no-template-curly-in-string nor no-useless-concat fires.)
 */
const DOLLAR_SIGN = "$";
const RELEASE_VERSION_PLACEHOLDER = DOLLAR_SIGN + "{nextRelease.version}";

/**
 * Disable conventional-commits-parser's "extra field" syntax, which silently truncates
 * release notes.
 *
 * The parser's default `fieldPattern` is /^-(.*?)-$/. A line of dashes matches it — so a
 * setext heading underline (`----------` under a title) or a markdown horizontal rule
 * puts the parser into field-capture mode, and EVERY REMAINING LINE of the commit body is
 * swallowed into a bogus field that no writer template ever emits. Not moved to the
 * footer, not flagged: gone.
 *
 * Measured on a real release whose commit body used setext underlines for its sections:
 * 66 body lines in, 8 published. A notes-extensiveness gate that measures the notes file
 * will not catch this — the loss happens downstream of such a gate, between parsing and
 * rendering.
 *
 * A regex that cannot match anything turns the feature off. Nothing in this repository
 * uses `-field-` syntax, and a commit body is markdown, where dashes are ordinary.
 */
const NEVER_MATCHES = /(?!)/;

/**
 * Escape `<` outside code spans, so GFM cannot swallow it as an HTML tag.
 *
 * `Vec<T>`, `Result<T, E>`, `List<String>` and every other generic written in
 * ordinary prose is, to a GFM parser, an opening HTML tag. The tag is dropped
 * from the rendered output and the release note reads "converted Vec to a
 * borrowed slice" — the type parameter has vanished, and nothing in the
 * pipeline reports an error. Escaping to `&lt;` renders the literal character.
 *
 * Code spans are skipped: inside backticks GFM already renders content
 * verbatim, so escaping there would publish a visible `&lt;` instead of `<`.
 * Closing-run matching follows CommonMark — a code span closes on a backtick
 * run of EQUAL length, which is what makes ``a ` b`` work.
 *
 * Only `<` is escaped, never `>`. A bare `>` mid-line is ordinary text, and a
 * `>` in the first column is a blockquote that isStructuralMarkdownLine()
 * already preserves. Escaping it too would corrupt intentional quoting.
 *
 * Known and accepted: an autolink written `<https://example.com>` loses its
 * angle brackets. Bare URLs autolink in GFM regardless, so the link still
 * works — and a body that says `Vec<T>` is far commoner than one that hand-
 * writes an autolink.
 */
function escapeAngleBracketsOutsideCodeSpans(line) {
  let out = "";
  let i = 0;
  while (i < line.length) {
    if (line[i] === "`") {
      let j = i;
      while (j < line.length && line[j] === "`") j += 1;
      const marker = line.slice(i, j);
      const rest = line.slice(j);
      const closingRun = new RegExp("(?<!`)" + marker + "(?!`)").exec(rest);
      if (closingRun) {
        // Emit the whole span — opening run, content, closing run — untouched.
        out += marker + rest.slice(0, closingRun.index + marker.length);
        i = j + closingRun.index + marker.length;
      } else {
        // Unclosed run: not a code span. Treat the backticks as literal text
        // and carry on escaping from just past them.
        out += marker;
        i = j;
      }
      continue;
    }
    out += line[i] === "<" ? "&lt;" : line[i];
    i += 1;
  }
  return out;
}

/**
 * Lines that carry their own block semantics and must never be folded into a
 * neighbouring paragraph. Joining a heading to the prose above it does not
 * merely look wrong — it stops being a heading.
 */
function isStructuralMarkdownLine(line) {
  return (
    /^ {0,3}#{1,6}(\s|$)/.test(line) || //            ATX heading
    /^ {0,3}>/.test(line) || //                       blockquote
    /^ {0,3}([-*_])(\s*\1){2,}\s*$/.test(line) || //  thematic break
    /^ {0,3}([-*+]|\d{1,9}[.)])(\s|$)/.test(line) || // list item
    /^ {0,3}(=+|-+)\s*$/.test(line) || //             setext underline
    /^\s*\|/.test(line) || //                         table row
    /^ {4,}\S/.test(line) //                          indented code block
  );
}

/**
 * Reflow a commit body so that what is RIGHT in the commit is also right on
 * the release page.
 *
 * A commit body is correctly hard-wrapped at ~72 columns. GitHub renders a
 * release body as GFM with hard line breaks enabled, so every one of those
 * newlines becomes a literal `<br>`: the identical text is well-formed in
 * `git log` and ragged on the release page, broken mid-sentence at column 72.
 * This is the only place the fix can live — semantic-release publishes through
 * the GitHub API via @semantic-release/github, so no shell-level guard on
 * `gh release create` ever observes this text.
 *
 * Implemented inline, with no imports and no I/O, deliberately. A reflow that
 * lives in a separate script file is a reflow that can go missing, and the
 * failure mode when it does is a caught exception, a logged warning nobody
 * reads, and a release published with the raw body — the exact defect this
 * function exists to remove, reintroduced through the back door. For the same
 * reason there is no try/catch here: this is pure string handling covered by
 * test/render-release-notes.test.mjs, and it runs during generateNotes, before
 * any tag or release exists. A throw aborts cleanly with nothing published. A
 * catch would convert a covered bug into a silent degradation.
 *
 * WHAT IS JOINED: a run of consecutive prose lines, folded into one line so
 * GFM sees one paragraph and emits no `<br>`.
 *
 * WHAT IS PRESERVED BYTE-FOR-BYTE:
 *   - fenced code blocks, in full, including their `<` characters;
 *   - any structural line (see isStructuralMarkdownLine);
 *   - any run containing a line that is indented, contains a tab, or contains
 *     a run of 3+ internal spaces. That last test is what protects deliberate
 *     column alignment — a timing table, an aligned key/value list, an ASCII
 *     diagram. Flattening one of those destroys the only thing it was for.
 *     Two spaces is NOT enough to trigger preservation, because two spaces
 *     after a full stop is ordinary typography, not alignment.
 *
 * Escaping happens AFTER joining but before emission, and the order matters in
 * both directions. Escaping after the join means a code span that straddles a
 * wrap point is matched as one span rather than as two unclosed runs. Escaping
 * at all means a line that begins with `<` has already stopped looking like a
 * standalone HTML block by the time GFM sees it, so it folds with its
 * paragraph instead of interrupting it.
 */
function reflowCommitBodyForGfm(body) {
  if (!body || typeof body !== "string") return body;

  const lines = body.replace(/\r\n?/g, "\n").split("\n");
  const out = [];
  let paragraph = [];
  let openFenceMarker = null;

  const flushParagraph = () => {
    if (paragraph.length === 0) return;
    const isDeliberatelyLaidOut = paragraph.some(
      (line) => /^\s/.test(line) || /\t/.test(line) || /\S {3,}\S/.test(line),
    );
    if (isDeliberatelyLaidOut) {
      for (const line of paragraph) out.push(escapeAngleBracketsOutsideCodeSpans(line));
    } else {
      out.push(escapeAngleBracketsOutsideCodeSpans(paragraph.join(" ")));
    }
    paragraph = [];
  };

  for (const line of lines) {
    if (openFenceMarker !== null) {
      out.push(line);
      const closer = new RegExp(`^ {0,3}${openFenceMarker[0]}{${openFenceMarker.length},}\\s*$`);
      if (closer.test(line)) openFenceMarker = null;
      continue;
    }

    const fenceOpening = /^ {0,3}(`{3,}|~{3,})/.exec(line);
    if (fenceOpening) {
      flushParagraph();
      out.push(line);
      openFenceMarker = fenceOpening[1];
      continue;
    }

    if (line.trim() === "") {
      flushParagraph();
      out.push("");
      continue;
    }

    if (isStructuralMarkdownLine(line)) {
      flushParagraph();
      out.push(escapeAngleBracketsOutsideCodeSpans(line));
      continue;
    }

    paragraph.push(line);
  }
  flushParagraph();

  return out.join("\n");
}

/**
 * Body-preserving clone of conventional-changelog-angular's writerOpts.transform
 * (node_modules/conventional-changelog-angular/src/writer.js). Reproduced inline
 * — rather than imported — because the preset ships ESM and this config is CJS.
 * The ONLY functional change vs. upstream is the added `body` field on the
 * returned object (marked below); everything else mirrors the preset so grouping
 * (Features / Bug Fixes / …), scope handling, issue/user autolinking, and
 * reference de-duplication stay byte-for-byte identical to the default output.
 */
function transformCommitPreservingBody(commit, context) {
  let discard = true;
  const issues = [];

  const notes = commit.notes.map((note) => {
    discard = false;
    return { ...note, title: "BREAKING CHANGES" };
  });

  let { type } = commit;
  if (commit.type === "feat") type = "Features";
  else if (commit.type === "fix") type = "Bug Fixes";
  else if (commit.type === "perf") type = "Performance Improvements";
  else if (commit.type === "revert" || commit.revert) type = "Reverts";
  else if (discard) return undefined;
  else if (commit.type === "docs") type = "Documentation";
  else if (commit.type === "style") type = "Styles";
  else if (commit.type === "refactor") type = "Code Refactoring";
  else if (commit.type === "test") type = "Tests";
  else if (commit.type === "build") type = "Build System";
  else if (commit.type === "ci") type = "Continuous Integration";

  const scope = commit.scope === "*" ? "" : commit.scope;
  const shortHash =
    typeof commit.hash === "string"
      ? commit.hash.substring(0, COMMIT_HASH_DISPLAY_LENGTH)
      : commit.shortHash;

  let { subject } = commit;
  if (typeof subject === "string") {
    let url = context.repository
      ? `${context.host}/${context.owner}/${context.repository}`
      : context.repoUrl;
    if (url) {
      url = `${url}/issues/`;
      subject = subject.replace(/#([0-9]+)/g, (_, issue) => {
        issues.push(issue);
        return `[#${issue}](${url}${issue})`;
      });
    }
    if (context.host) {
      subject = subject.replace(/\B@([a-z0-9](?:-?[a-z0-9/]){0,38})/g, (_, username) =>
        username.includes("/") ? `@${username}` : `[@${username}](${context.host}/${username})`,
      );
    }
  }

  const references = commit.references.filter((reference) => !issues.includes(reference.issue));

  return {
    notes,
    type,
    scope,
    shortHash,
    subject,
    references,
    // ← the one addition: surface the multi-paragraph body, REFLOWED.
    //
    // Reflowing here is not cosmetic, and it is not optional. Surfacing
    // `commit.body` raw publishes a release page broken mid-sentence at every
    // wrap point, with every `Vec<T>` in the prose silently eaten. See
    // reflowCommitBodyForGfm above for why this expression is the only place
    // the fix can live.
    body: reflowCommitBodyForGfm(commit.body),
  };
}

/**
 * commit partial = the upstream Angular commit.hbs (verbatim, so the subject
 * line, commit link, and "closes #N" references render identically) followed by
 * a body block that prints the full multi-paragraph body underneath the bullet.
 */
const COMMIT_PARTIAL_WITH_BODY = `*{{#if scope}} **{{scope}}:**
{{~/if}} {{#if subject}}
  {{~subject}}
{{~else}}
  {{~header}}
{{~/if}}

{{~!-- commit link --}} {{#if @root.linkReferences~}}
  ([{{shortHash}}](
  {{~#if @root.repository}}
    {{~#if @root.host}}
      {{~@root.host}}/
    {{~/if}}
    {{~#if @root.owner}}
      {{~@root.owner}}/
    {{~/if}}
    {{~@root.repository}}
  {{~else}}
    {{~@root.repoUrl}}
  {{~/if}}/
  {{~@root.commit}}/{{hash}}))
{{~else}}
  {{~shortHash}}
{{~/if}}

{{~!-- commit references --}}
{{~#if references~}}
  , closes
  {{~#each references}} {{#if @root.linkReferences~}}
    [
    {{~#if this.owner}}
      {{~this.owner}}/
    {{~/if}}
    {{~this.repository}}#{{this.issue}}](
    {{~#if @root.repository}}
      {{~#if @root.host}}
        {{~@root.host}}/
      {{~/if}}
      {{~#if this.repository}}
        {{~#if this.owner}}
          {{~this.owner}}/
        {{~/if}}
        {{~this.repository}}
      {{~else}}
        {{~#if @root.owner}}
          {{~@root.owner}}/
        {{~/if}}
          {{~@root.repository}}
        {{~/if}}
    {{~else}}
      {{~@root.repoUrl}}
    {{~/if}}/
    {{~@root.issue}}/{{this.issue}})
  {{~else}}
    {{~#if this.owner}}
      {{~this.owner}}/
    {{~/if}}
    {{~this.repository}}#{{this.issue}}
  {{~/if}}{{/each}}
{{~/if}}
{{~!-- extensive body --}}
{{~!--
  TWO blank lines below, not one, and the count is load-bearing.

  Handlebars treats a block tag alone on its line as "standalone" and strips that
  line's trailing newline. So the obvious one-blank-line form emits only ONE newline,
  the body lands directly under the bullet, and GFM reads it as a lazy continuation --
  rendering the entire body INSIDE the list item. A release published that way is not
  merely hard-wrapped: its body is swallowed by its own bullet.

  With two, one newline survives the standalone strip and the surviving blank line
  makes the body its own paragraph. Verify any change to this block by RENDERING the
  real template against a real commit, never by reasoning about it.

  Keep this comment free of backticks: it lives inside a JS template literal, and a
  backtick here terminates the string rather than quoting anything.
--}}
{{~#if body}}


{{body}}
{{~/if}}

`;

module.exports = {
  branches: ["main"],
  plugins: [
    // Preflight: block the release before anything is written if the working
    // tree is dirty, credentials are missing, or the gates do not pass.
    // The task is the single source of truth for what "ready to release" means;
    // this hook exists so `semantic-release` cannot bypass it.
    ["@semantic-release/exec", { verifyConditionsCmd: "mise run release:preflight" }],

    // A marketplace consumer pinning a version needs a NEW version for ANY
    // change, including a docs-only one — otherwise the pinned tag and the
    // repository content diverge with nothing to point at. So every commit
    // type bumps.
    // Preset defaults: feat=minor, fix=patch, perf=patch, revert=patch.
    // Added below: every other type triggers a patch release.
    [
      "@semantic-release/commit-analyzer",
      {
        // A breaking change must NEVER be able to ship as a minor bump.
        // It silently can, and has: two commits marked `feat(...)!:` with
        // bodies opening `BREAKING:` were both analyzed as ordinary features,
        // cutting a minor where a major was intended. Two independent gaps
        // combined, and each is closed below.
        //
        // Gap 1 — the `!` shorthand. The Angular preset predates it and does
        // not treat `feat!:` / `feat(scope)!:` as breaking; only the
        // conventionalcommits preset does. `{ breaking: true }` below is
        // evaluated by commit-analyzer against the parsed commit AFTER
        // parserOpts run, so pairing it with the noteKeywords fix makes both
        // spellings land on a major.
        //
        // Gap 2 — the footer token. Conventional Commits requires the exact
        // token `BREAKING CHANGE` (or `BREAKING-CHANGE`). A body starting
        // `BREAKING:` is NOT recognized by the default parser and is treated
        // as ordinary prose. Rather than rely on every author remembering the
        // two-word form, the bare `BREAKING` keyword is accepted here too.
        parserOpts: {
          noteKeywords: ["BREAKING CHANGE", "BREAKING-CHANGE", "BREAKING"],
          fieldPattern: NEVER_MATCHES,
        },
        releaseRules: [
          { breaking: true, release: "major" },
          { type: "docs", release: "patch" },
          { type: "chore", release: "patch" },
          { type: "style", release: "patch" },
          { type: "refactor", release: "patch" },
          { type: "test", release: "patch" },
          { type: "build", release: "patch" },
          { type: "ci", release: "patch" },
          { type: "revert", release: "patch" },
        ],
      },
    ],

    // Notes generator with the body-preserving writerOpts (the reason this
    // config exists). transform + commitPartial are merged OVER the Angular
    // preset's writerOpts; all other preset opts (mainTemplate, headerPartial,
    // groupBy, sorts) are inherited unchanged.
    [
      "@semantic-release/release-notes-generator",
      {
        // MUST mirror commit-analyzer's parserOpts above. The two plugins parse
        // the commit range independently, so a noteKeywords list set on only
        // one of them yields the split-brain failure mode where the analyzer
        // correctly bumps major but the published notes carry no "BREAKING
        // CHANGES" section — the bump is right and the changelog silently lies
        // about why. Keep these two lists in lockstep. The same applies to
        // fieldPattern: a NEVER_MATCHES on one side only means the two plugins
        // disagree about where the body ends.
        parserOpts: {
          noteKeywords: ["BREAKING CHANGE", "BREAKING-CHANGE", "BREAKING"],
          fieldPattern: NEVER_MATCHES,
        },
        writerOpts: {
          transform: transformCommitPreservingBody,
          commitPartial: COMMIT_PARTIAL_WITH_BODY,
        },
      },
    ],

    // Version sync only — the notes are generated by
    // @semantic-release/release-notes-generator above. This propagates the
    // version semantic-release picked into every manifest that carries one.
    //
    // NOTE on the command string below, and on every exec command in this
    // file: @semantic-release/exec runs a lodash `template()` over the command
    // BEFORE handing it to the shell. Bash parameter expansion with a default
    // — `${VAR:-default}` — therefore collides with lodash's JS evaluation and
    // fails at release time, when it is most expensive to discover. The rule
    // that follows from it: a command string here may contain exactly one kind
    // of `${...}`, the semantic-release token built by concatenation above. If
    // a step needs real bash semantics, put it in a script file and pass the
    // version as an argument — argv survives lodash untouched.
    [
      "@semantic-release/exec",
      { prepareCmd: `node scripts/sync-versions.mjs ${RELEASE_VERSION_PLACEHOLDER}` },
    ],

    "@semantic-release/changelog",

    // Files the release commit must carry. Every entry is a file this
    // repository actually has: a listed path that does not exist makes
    // @semantic-release/git fail the release, and a path that exists but is
    // NOT listed silently ships out of sync with its tag.
    //
    // There is no root-level plugin.json here — the manifests live under
    // .claude-plugin/. When the first plugin lands, add its
    // plugins/<name>/plugin.json (and any hooks.json it registers) here in the
    // same commit that adds the plugin.
    [
      "@semantic-release/git",
      {
        assets: [
          "CHANGELOG.md",
          "package.json",
          ".claude-plugin/plugin.json",
          ".claude-plugin/marketplace.json",
        ],
        message: `chore(release): ${RELEASE_VERSION_PLACEHOLDER} [skip ci]`,
      },
    ],

    // Push commit and tags after @semantic-release/git creates them.
    // Belt-and-suspenders: ensures the push happens even in --no-ci mode.
    [
      "@semantic-release/exec",
      {
        successCmd:
          "/usr/bin/env bash -c 'git push --follow-tags origin main && git update-index --refresh && echo ✓ Git index refreshed'",
      },
    ],

    // Explicit @semantic-release/github config disabling four features that
    // cost GitHub API calls and deliver nothing to a tag-driven release flow.
    // ALL FOUR flags are LOAD-BEARING for release wall-time; reintroducing any
    // of them re-adds the cost.
    //
    //   1. successComment:false — disables the per-resolved-commit
    //      `GET /search/issues` API storm (semantic-release/github#542, #867,
    //      #2204). Releases here are tag-driven, not PR-driven, so there are
    //      no resolved PRs/issues to comment on.
    //   2. failComment:false — no auto-opened GitHub issue on release failure;
    //      failures surface in the local release-pipeline output instead.
    //   3. releasedLabels:false — no `released` label on resolved PRs/issues;
    //      the tag plus the GitHub release page is the single source of truth.
    //   4. addReleases:false — no "previous releases" back-reference block;
    //      CHANGELOG.md already links inter-version diffs.
    [
      "@semantic-release/github",
      {
        successComment: false,
        failComment: false,
        releasedLabels: false,
        addReleases: false,
      },
    ],
  ],
};
