#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$PLUGIN_ROOT/lib/segment-package.sh"

export CUSTOM_STATUSLINE_CACHE_DIR="$(mktemp -d)"
trap 'rm -rf "$CUSTOM_STATUSLINE_CACHE_DIR"' EXIT

PASS=0
FAIL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    echo "  ✗ $desc: expected '$expected', got '$actual'"
  fi
}

assert_eq "in-sync when versions match" "in-sync" \
  "$(compare_release_to_manifest "v1.0.0" "1.0.0")"

assert_eq "ahead when manifest is newer" "ahead" \
  "$(compare_release_to_manifest "v1.0.0" "1.1.0")"
assert_eq "behind when release is newer" "behind" \
  "$(compare_release_to_manifest "v1.1.0" "1.0.0")"

MANIFEST_SCRATCH="$(mktemp -d)"
trap 'rm -rf "$CUSTOM_STATUSLINE_CACHE_DIR" "$MANIFEST_SCRATCH"' EXIT
echo '{"name":"x","version":"5.6.7"}' >"$MANIFEST_SCRATCH/package.json"
assert_eq "detects package.json version" "5.6.7" "$(detect_manifest_version "$MANIFEST_SCRATCH")"

rm -f "$MANIFEST_SCRATCH/package.json"
cat >"$MANIFEST_SCRATCH/Cargo.toml" <<'CARGO_EOF'
[package]
name = "x"
version = "2.3.4"
CARGO_EOF
assert_eq "detects Cargo.toml version" "2.3.4" "$(detect_manifest_version "$MANIFEST_SCRATCH")"

rm -f "$MANIFEST_SCRATCH/Cargo.toml"
cat >"$MANIFEST_SCRATCH/pyproject.toml" <<'PYPROJECT_EOF'
[project]
name = "x"
version = "0.9.1"
PYPROJECT_EOF
assert_eq "detects pyproject.toml version" "0.9.1" "$(detect_manifest_version "$MANIFEST_SCRATCH")"

rm -f "$MANIFEST_SCRATCH/pyproject.toml"
echo "3.2.1" >"$MANIFEST_SCRATCH/VERSION"
assert_eq "detects bare VERSION file" "3.2.1" "$(detect_manifest_version "$MANIFEST_SCRATCH")"

rm -f "$MANIFEST_SCRATCH/VERSION"
assert_eq "no manifest yields empty" "" "$(detect_manifest_version "$MANIFEST_SCRATCH")"

fetch_owner_packages() {
  echo '[
    {"name":"other-pkg","repository":{"full_name":"nasimubd/other-repo"},"updated_at":"2026-01-01T00:00:00Z","version_count":3},
    {"name":"skills-pkg","repository":{"full_name":"nasimubd/skills"},"updated_at":"2026-02-01T00:00:00Z","version_count":5}
  ]'
}
assert_eq "filters owner packages down to this repository" "skills-pkg:5v" \
  "$(fetch_repo_package_summary nasimubd skills)"
unset -f fetch_owner_packages

assert_eq "missing repo info yields empty" "" "$(segment_package '{}')"

assert_eq "real repo, manifest in sync with release" "in-sync" \
  "$(segment_package "{\"workspace\":{\"repo\":{\"owner\":\"nasimubd\",\"name\":\"skills\"},\"current_dir\":\"$PLUGIN_ROOT/../..\"}}")"

# Both sources present: a cache-seeded package summary for a repo that
# can't exist, plus a manifest ahead of its (also seeded) latest release.
cache_set "owner-zzz/repo-zzz/package" "widget:2v"
cache_set "owner-zzz/repo-zzz/release" "v1.0.0"
echo '{"version":"1.1.0"}' >"$MANIFEST_SCRATCH/package.json"
assert_eq "both package sources render together" "widget:2v ahead" \
  "$(segment_package "{\"workspace\":{\"repo\":{\"owner\":\"owner-zzz\",\"name\":\"repo-zzz\"},\"current_dir\":\"$MANIFEST_SCRATCH\"}}")"

echo "test-segment-package.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
