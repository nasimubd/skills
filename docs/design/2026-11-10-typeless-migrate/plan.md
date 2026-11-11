# Proposed implementation plan: `typeless-migrate`

This plan is presented for approval. No production plugin implementation, live
account import, private-endpoint integration or destination-profile mutation is
included in the research branch.

## Goal

Provide a local-first tool that helps an operator move transferable Typeless data
from an employer account to a separately purchased personal account while preserving
the source account's email, billing, credentials and server identity. It must make
clear which parts are backed up, which are restored through supported product flows,
and which remain unavailable.

## Proposed phases

### 1. Product-safe discovery

Add `typeless-migrate` as a marketplace plugin following the repository's plugin
contract. Its setup/health flow checks supported macOS version, Typeless version,
available profile paths, free disk space, permissions and whether Typeless is closed
before any file operation. It never stores credentials in plugin state.

### 2. Source archive

Create a versioned, encrypted-at-rest local archive outside the repository containing:

- filtered local settings with device/display paths removed or marked for review;
- history records and referenced audio with content hashes;
- dictionary terms only through an operator-visible supported export/import path;
- a manifest of source build, schema, counts and omissions.

Exclude `user-data.json`, cookies, tokens, subscription/team fields, sync cursors,
absolute paths in the portable record, and any source user ID in the destination
payload. Require a new output directory and retain the source unchanged.

### 3. Supported destination workflow

The tool logs out/signs into the personal account only when the operator explicitly
chooses the normal Typeless UI flow. It offers:

- a generated CSV for the documented dictionary importer, with preview, dedupe,
  Unicode/CSV validation and post-import count verification;
- settings as a reviewable checklist or safe local configuration file, with
  device-specific values excluded by default;
- history/audio as an archive and report until Typeless provides a documented
  destination import. If an official import or cloud-sync flow is available, use it
  only after capability detection and show the exact record count before submission.

No private API request signing or direct database replacement is planned.

### 4. Personalization handling

Report the source personalization toggle and stats only as informational. Offer to
turn personalization on in the destination through the normal UI, but state that the
learned model and category history cannot be transferred unless Typeless adds an
export/import facility. Do not copy `personal_auto_style_on` as if it were the model.

### 5. Verification and rollback

Produce a manifest showing source/destination identities only as redacted hashes,
counts, hashes and omissions. Verify source hash and archive hash, dictionary import
result, settings selected by the operator and audio checksums. Preserve the archive
for rollback; never delete source data automatically.

### 6. Repository delivery

Implement the plugin under `plugins/typeless-migrate/`, add its platform-neutral
skill and `.agents/skills/` link if applicable, update marketplace/README/CLAUDE
files in the same commit, add meaningful regression tests, run all repository gates,
and use the current protocol: `docs/typeless-migrate-research` branch, Conventional
Commits, `mise run pr:check`, then rebase-and-merge through a PR.

## Acceptance criteria

- Source account email, billing, tokens and service identity are never changed or
  copied.
- A dry run reports every source, destination, file, count and omission before writes.
- The archive is reproducible and integrity-checked; reruns cannot overwrite an
  existing archive accidentally.
- Dictionary CSV output follows observed Typeless parser constraints and handles
  commas, quotes, Unicode, duplicates and invalid terms safely.
- Local settings and history/audio backup pass the PoC invariants without touching
  the live profile.
- Unsupported history/personalization transfer is surfaced as an explicit limitation,
  not silently claimed as complete.
- All repository gates and plugin tests pass.

## Approval decision needed

Please approve or change the scope before implementation begins. The key choice is
whether to ship a **safe archive + supported dictionary/settings workflow** while
history and learned personalization remain export-only/informational, or to defer
plugin delivery until Typeless documents an official cross-account history and
personalization import. The research evidence does not justify an unsupported
private-endpoint or direct-database migration.
