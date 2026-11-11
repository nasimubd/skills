#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
expect_fail_fixture() { local label="$1"; shift; local tmp; tmp=$(mktemp -d); cp -R "$ROOT/.claude-plugin" "$ROOT/plugins" "$ROOT/README.md" "$tmp/"; "$@" "$tmp"; if SKILLS_ROOT="$tmp" node "$ROOT/scripts/validate-readme-sync.mjs" >/dev/null 2>&1; then echo "$label unexpectedly passed" >&2; rm -rf "$tmp"; exit 1; fi; rm -rf "$tmp"; }
expect_fail_fixture missing_readme bash -c 'rm "$1/plugins/custom-statusline/README.md"' _
expect_fail_fixture stale_description python3 -c 'from pathlib import Path; p=Path(__import__("sys").argv[1]) / "plugins/custom-statusline/README.md"; p.write_text(p.read_text().replace("Multi-line Claude Code status line","Changed description"))'
expect_fail_fixture missing_table_row python3 -c 'from pathlib import Path; p=Path(__import__("sys").argv[1]) / "README.md"; p.write_text("\n".join(x for x in p.read_text().splitlines() if "typeless-migrate" not in x)+"\n")'
expect_fail_fixture missing_root_link python3 -c 'from pathlib import Path; p=Path(__import__("sys").argv[1]) / "README.md"; p.write_text("\n".join(x for x in p.read_text().splitlines() if "custom-statusline" not in x)+"\n")'
expect_fail_fixture unregistered_plugin bash -c 'mkdir "$1/plugins/rogue"; printf "%s\n" "{}" > "$1/plugins/rogue/plugin.json"' _
SKILLS_ROOT="$ROOT" node "$ROOT/scripts/validate-readme-sync.mjs" >/dev/null
echo "readme sync adversarial tests: passed"
