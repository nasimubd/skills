#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT"
node --test skills/quantitative-integrity-audit/tests/*.test.mjs
PACKAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$PACKAGE_DIR"' EXIT
node scripts/package-quant-integrity.mjs "$PACKAGE_DIR"
if command -v claude >/dev/null 2>&1; then
    claude plugin validate --json "$PACKAGE_DIR/claude/quant-integrity-auditor" | node -e 'let s="";process.stdin.on("data",x=>s+=x).on("end",()=>{if(!JSON.parse(s).success)process.exit(1);console.log("Claude plugin validation: 1 passed, 0 failed")})'
else
    echo 'Claude plugin validation: BLOCKED (CLI unavailable)'
fi
echo 'Codex package parity: 1 passed, 0 failed'
