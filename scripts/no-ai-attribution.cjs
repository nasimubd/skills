#!/usr/bin/env node
// The one definition of "AI attribution" for this repository, used by commitlint (every
// commit message, commitlint.config.cjs) and by `mise run pr:check` (the PR title and body).
// Run directly, it reads text on stdin and exits 1 naming the offending line.

'use strict';

const PATTERNS = [
  /co-authored-by:.*\b(claude|anthropic|copilot|chatgpt|openai|gemini|cursor)\b/i,
  /co-authored-by:.*noreply@anthropic\.com/i,
  /generated (with|by) .*(claude|chatgpt|copilot|gemini|\bai\b)/i,
  /🤖\s*generated/i,
  /claude\.com\/claude-code|claude\.ai\/code/i,
];

function findAttribution(text) {
  for (const line of String(text ?? '').split('\n')) {
    if (PATTERNS.some((re) => re.test(line))) return line.trim();
  }
  return null;
}

if (require.main === module) {
  let input = '';
  process.stdin.on('data', (d) => { input += d; });
  process.stdin.on('end', () => {
    const hit = findAttribution(input);
    if (hit) {
      console.error(`✗ AI attribution is not allowed (CLAUDE.md, .claude/rules/git.md): "${hit}"`);
      process.exit(1);
    }
  });
}

module.exports = { findAttribution };
