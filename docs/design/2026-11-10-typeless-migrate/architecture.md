# Desktop architecture and feature inventory

See [scope and evidence levels](README.md). All findings describe desktop build
2.10.0.137; platform branches and UI strings do not prove another platform behaves
identically.

## Components

| Layer | Evidence | Responsibility |
|---|---|---|
| Launcher | Mach-O arm64 executable; linked Electron framework | Start the desktop runtime; app bundle identity `now.typeless.desktop` |
| Runtime | Electron framework bundle version `43.8.4` | Chromium windows, process isolation, IPC, native integration |
| Main process | `dist/main/index.js` | Auth/session, settings, history, recording workers, native helper loading, network requests, tray, updates |
| Renderer | React bundles and hub/login/onboarding/floating-bar/sidebar/interactive-card HTML entry points | User interface, state stores, dictionary operations, reports, settings and account surfaces |
| Persistence | `electron-store`, `better-sqlite3`, Drizzle | JSON preferences and onboarding; encrypted session store; SQLite history with migrations |
| Native bridge | `koffi` and bundled dylibs | Accessibility context, key monitoring, text insertion, audio device/OS utilities |
| Audio workers | `chunkSessionWorker.js`, `opusWorker.js`, Opus dylibs | Off-main-thread audio encoding and chunk-session lifecycle |
| Service | HTTPS requests to `api.typeless.com`; login on `www.typeless.com` | Speech/AI processing, dictionary, user information/settings, learned-style reports, optional history synchronization |
| Operations | `electron-updater`, Sentry, diagnostic/metrics calls | App updates, error reporting and usage/diagnostic operations |

The app is signed with a Developer ID, hardened runtime and a stapled notarization
ticket. The bundle declares microphone, accessibility-related integration, screen
capture and other OS usage descriptions. A usage-description string alone does
not establish that a feature is active or permission has been granted.

Main-window constructors inspected use `nodeIntegration: false` and
`contextIsolation: true`. Renderer/main communication includes auth, store, audio,
file, history, appearance, permissions, keyboard and sync IPC families. The app
contains developer-tool handlers; these are not a supported migration extension API.

## Dictation flow

1. A configured shortcut activates dictation, hands-free dictation, translation or
   Ask anything. Native keyboard monitoring identifies shortcut/device state.
2. Microphone capture and recording sessions collect audio. Native context helpers
   can collect the focused app, editable element, selected text and surrounding
   context. The build includes app/domain policy lists and compatibility handling.
3. Audio is encoded as Ogg/Opus, using worker and chunk-session operations, and
   associated with a local history record and recording file.
4. `/ai/voice_flow` receives multipart audio, mode, audio metadata, encrypted
   context, and mode-specific parameters. The client applies a timeout and exposes
   retry/abort paths. Server-side model choice and inference code are unavailable.
5. The response can include refined text, an answer, web metadata or an external
   action. The client inserts or displays the result and updates history. Merely
   seeing an external-action field does not establish every possible integration.
6. After insertion, edit tracking can send a `/user/traits` request containing
   encrypted edit/context information. An auto-added dictionary response triggers
   a UI notification. This is the client-visible learning feedback path.

## Feature surfaces

| Feature | Behavior visible in this build | Evidence level |
|---|---|---|
| Voice dictation | Hold/release and hands-free flows; insert refined text into active input | Code-backed; history mode observed |
| Ask anything | Voice commands, selected-text context, sidebar/interactive answer cards, copy and external delivery | Code-backed; `voice_command` rows observed |
| Translation | Voice translation, target language selection, output-language parameter | Code-backed; `voice_translation` rows observed |
| Shortcuts | Multiple bindings per feature; dictation, Ask anything, translation and paste last transcript | Code-backed and settings observed |
| Default macOS bindings | Fn; Fn+Space; Fn+LeftShift; Ctrl+Cmd+V respectively | Code-backed defaults, not a statement of current user choices |
| Input languages | Automatic detection or selected languages; output-language mapping | Code-backed and local/cached fields observed |
| Interface language | Locale selection and bundled localized resources | Observed resources and settings |
| Microphone | Enumerate/select devices, preferred built-in microphone, degradation/fallback logic | Code-backed and local fields observed |
| Audio behavior | Interaction sounds, background-audio muting, compression/chunking | Code-backed and local fields observed |
| Desktop appearance | System/light/dark theme, dock visibility, floating bar, launch on startup | Code-backed and local fields observed |
| History | User-filtered list/pagination; All/Dictations/Ask anything tabs; transcript copy, answer viewing, retry, audio download, feedback, individual/all deletion | Code-backed; local records/audio observed |
| Local retention | Configured retention period; cleanup; organization cap handling | Code-backed |
| Cloud history sync | Opt-in controls, upload/download/backfill, progress/errors, retention, quota/tier/org restrictions, tombstones and cloud wipe | Code-backed; cached sync disabled in inspected profile |
| Dictionary | List/search, All/Auto-added/Manually-added views, add/edit/delete, multi-select delete, paginated loading | Code-backed; real export unproven |
| Dictionary CSV import | File validation, local parsing, server preview, server submission | Code-backed; parser exercised offline in research |
| Personalization | Overall/category learning ratios, charts/table, enable/disable control | Code-backed reports; actual learned representation unavailable |
| Usage and insights | Usage reports, personal stats, insights, shareable report surfaces | Code-backed; server aggregates are not local counters to migrate |
| Account | Email display, sign-in/out, browser-based login including SSO routing, subscription/manage/upgrade, team/member and gift/referral surfaces, account deletion | Code-backed; availability depends on service/account |
| Permissions/help | Permission checks, microphone diagnosis, OS settings links, help, surveys, feedback and diagnostics | Code-backed |
| Updates | Update checking/download, release notices, auto-update support | Code-backed |

Product claims such as exact recognition quality, filler removal accuracy or how
well tone is learned require behavioral trials; UI copy and response plumbing do
not independently verify those claims. This research did not run transcription
benchmarks or execute outward actions from Ask anything.

## Native helper boundaries

`nm -gU` found 47 exports in the context helper, 34 in the input helper, 100 in the
keyboard helper and 24 in the utility helper. These totals include runtime symbols.
Meaningful boundaries include:

- Context: focused app identity/info, focused element, related content, visible text.
- Input: selected text, simulated-copy fallback, current input state, insertion/edit support.
- Keyboard: start/stop monitoring and keyboard-device enumeration.
- Utilities: accessibility checks, audio-device enumeration, mute status, device ID,
  lid-state monitoring and application/system integration.
- Opus libraries: audio encoding and chunk processing; third-party codec internals
  are unrelated to portable account state.

## Network and identity

Browser-based app login uses state and a code challenge/verifier exchange. Access
and refresh tokens belong to the logged-in identity; normal logout revokes the
refresh token and clears account/session caches. Settings and history are separate
from that session store, but history queries still filter by the current user ID.

Requests add bearer authentication and client metadata/security headers. A generic
HTTP client was rejected on the read-only dictionary probe with HTTP 418. The
reported response category referred to TLS/request checks. No conclusion about the
validity of an official in-app request follows from that rejection.

Context encryption uses a server-provided RSA public key to wrap a random AES key
and AES-256-GCM for payloads. Legacy fallback code also exists. The client does not
contain the corresponding server private key. See [storage](storage.md) for why an
opaque encrypted context can be archived without proving it works under a new
account.
