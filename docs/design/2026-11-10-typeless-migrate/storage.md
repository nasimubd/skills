# Storage and migration boundaries

## Profile files observed

The profile is under the platform's application-support directory and was inspected
by name, schema and aggregate metadata only. The actual path is intentionally absent
from tracked documentation.

| Store | Contents | Portability |
|---|---|---|
| `app-settings.json` | Shortcuts, microphone selection, languages, startup/floating-bar/audio/theme and local retention choices | **Portable by value** after filtering device/display-specific fields |
| `app-onboarding.json` | Onboarding progress, feature notices and per-user history-migration marker | Optional UX state; do not copy source user IDs |
| `app-storage.json` | Cached user profile, plan/team fields, dictation/translation settings, personalization toggles, locale, sync state | **Reference only**; contains employer identity/entitlement and server-owned settings |
| `user-data.json` | Encrypted access/refresh session data | **Never migrate**; authentication and source identity |
| `typeless.db` | SQLite `history` and `history_v2` tables plus Drizzle migration table | Export records to a neutral archive; do not transplant the database wholesale |
| `Recordings/` | Ogg/Opus files referenced by history | Copy only files referenced by exported records and hash-verify |
| `transcription-history-sync-*.json` | Sync state/cursor per user | Do not copy; destination must establish its own sync state |
| Chromium stores | Cookies, local storage, caches, partitions, shared storage | Do not copy; may contain account/session material and unrelated web state |
| Logs/crash/update stores | Diagnostics and update state | Do not migrate |

`electron-store` uses AES-256-CBC when an encryption key is configured. The user
session key is derived from platform/architecture and app name, then used with a
per-file IV and PBKDF2. This makes direct copying of encrypted `user-data.json`
particularly wrong: it carries credentials, and portability depends on implementation
keys rather than account ownership.

## History schema and observed data

`history_v2` contains `id`, `user_id`, status/mode, refined text, duration and
timestamps, app/microphone metadata, `audio_local_path`, audio metadata/context,
client/mode metadata, server sync timestamps/status/attempt counters and a
cloud-origin marker. The older `history` table overlaps the current table and is
not a second independent archive.

The inspected profile contained 18,215 `history_v2` rows: 18,132 voice transcripts,
24 voice commands and 59 voice translations. Statuses were 16,835 completed, 1,338
dismissed, 21 error and 21 null. There were 18,213 Ogg references and 18,213 local
recording files (about 1.19 GB); every observed reference resolved to an existing
file. The local database had one distinct user ID. All rows were marked
`pending_upload` because cloud sync was disabled in the cached account state; this
is a local application detail, not a safe destination import marker.

History records include encrypted audio context envelopes. The client can normalize
legacy/plain context for the current source account using a server RSA key, but a
migration tool cannot re-encrypt opaque context for the destination without the
destination's server key and an official API. Preserve it as opaque metadata or
omit it explicitly; never decrypt or publish it.

## Account-backed data

The renderer implements these service operations:

- Dictionary list/add/update/delete/batch-delete and bulk-import preview/submit.
- Dictation-settings read/write and general user-settings updates.
- Personal-stats read plus `personal_auto_style_on` update.
- User info, traits, usage, insights and history sync/pull/push/wipe.

The dictionary bulk importer sends newline-joined terms to the service; the desktop
CSV parser trims entries, requires one non-empty column, rejects NULs, duplicates,
terms longer than 100 UTF-16 code units, more than 3,000 terms and files over 5 MiB.
Those limits are observed client behavior, not a promise that the service will keep
accepting them. Auto-added words are server-linked dictionary entries with IDs and
metadata; they are not recoverable from the local history database alone.

Personalization is server-backed. The client receives aggregate stats (including
`total_learning_ratio` and category stats) and can enable/disable it, but no export,
import, model-file, or learned-example endpoint was found. `personal_auto_dictionary_on`
and `personal_auto_style_on` in cached user data are switches, not the learned model.

## Safe migration boundary

A robust archive should contain a versioned manifest, filtered local settings,
neutral history records, referenced audio and hashes, and an optional dictionary
term file. It must exclude tokens, cookies, user IDs when creating a destination
archive, subscription/team fields, opaque destination-incompatible sync cursors,
and machine-specific paths. Restore should generate new record IDs, bind records to
the destination account only through a supported app/API flow, and leave cloud sync
quarantined until the destination has accepted the records.

Directly replacing `typeless.db`, `app-storage.json` or `user-data.json` is unsafe:
those files embed identity, server synchronization state, paths and/or credentials.
The PoC therefore uses a synthetic destination identity and a research-only
`poc_quarantined` marker; Typeless does not document that marker as importable.
