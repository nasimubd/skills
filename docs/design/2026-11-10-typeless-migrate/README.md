# Typeless Migrate: desktop investigation and migration PoC

Status: research completed to the boundaries recorded below; production plugin and
live destination-account import await approval of [the plan](plan.md).

The investigation examined the installed **macOS arm64 Typeless 2.10.0**, build
**2.10.0.137**, on 2026-11-10. It recovered the desktop application's architecture,
feature surfaces, persistence schema, account boundaries, and the migration paths
visible in this build. The offline PoC preserves local history, audio and selected
settings. It does **not** establish a complete account migration: real dictionary
extraction, destination-app acceptance, cloud import and learned personalization
remain unproven.

| Document | What it establishes |
|---|---|
| [Architecture and feature inventory](architecture.md) | How the desktop app works; features evidenced by code, bundled resources and native exports |
| [Storage and migration boundaries](storage.md) | Local files, history schema, account identity, sync, encrypted context and portability |
| [Feasibility and PoC results](poc-results.md) | What was actually tested, what failed, and the exact limits of the evidence |
| [Implementation plan for approval](plan.md) | Proposed phases, acceptance criteria and unresolved choices |
| [Research scripts](research/README.md) | Reproduce the isolated PoC using a private snapshot and synthetic tests |
| [Artifact manifest](research/artifact-manifest.json) | Version-specific hashes for provenance without redistributing the app |

## Method and evidence levels

The primary executable is an Electron launcher. Investigation therefore focused on
`Resources/app.asar`, the first-party main/renderer bundles, the bundled Drizzle SQL
migrations, and exported symbols/imports of the native helpers. A private ASAR
reader enumerated 10,914 files and extracted first-party resources outside Git.
The main bundle's string-table rotation and lookup functions were evaluated in a
restricted VM with a one-second timeout, without importing or starting the app's
application code; 9,622 lookup calls were resolved for static inspection. This is
source recovery from a shipped executable package, not a claim to have recovered
Typeless's backend source or every machine instruction in Electron and its codecs.
Native helpers were inspected at their ABI and dependency boundaries; their full
Swift/C implementation was not decompiled.

Evidence labels used in these documents:

- **Observed:** app metadata, local schema/file inventories, native exports, or a
  result actually measured on the installed build.
- **Code-backed:** reachable client code implements an operation, but its remote
  behavior or every UI state has not been exercised.
- **Inferred:** a conclusion from the client boundary that needs further validation.
- **Unproven:** a capability for which no successful transfer has been demonstrated.

The backend speech/model implementation, account entitlements, proprietary learned
style representation and server authorization rules are not present in this binary.
No claim of “understanding everything” or a guaranteed full migration follows from
this investigation.

## Scope and handling

The source account's email, billing, subscription, membership and authentication
were not changed. The live database was opened read-only and snapshotted through
SQLite's backup API. Restore writes went only to an isolated private workspace,
using a synthetic destination identity. No account-mutating endpoint was called,
no production app binary was patched, and no destination profile was launched.
One authenticated read-only dictionary request was attempted and rejected; no
request-signature emulation or retry around the rejection was performed.

Normal desktop UI navigation was attempted for inspection. The app's accessible
window exposed no usable dictionary controls in this session, even with Electron
manual accessibility enabled. That temporary runtime accessibility setting is
separate from Typeless's preferences; it was disabled after inspection.

Private extracted source, raw profiles, credentials, transcripts, audio, actual
account IDs and API bodies stay outside the repository. Only independently written
research code, hashes, schema descriptions and aggregate results belong here. The
bundle's package metadata is not treated as a redistribution license for its full
contents. The snapshot may include sensitive employer-related content; this PoC
keeps it local and does not select which records should move to a personal account.
