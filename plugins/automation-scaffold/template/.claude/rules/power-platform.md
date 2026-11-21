---
paths:
  - "src/**"
  - "scripts/**"
---

# Power Platform (on demand)

Applies alongside `CLAUDE.md`. Where two rules apply, the stricter one wins.

## Environment

{{POWER_PLATFORM_LINE}}

## Layout

- `src/CanvasApps/<App>/src/Src/*.pa.yaml`: canvas app source, exported from the **live**
  (published) version by `mise run export -- <id>`.
- `src/Flows/<slug>/definition.json`: the flow definition with secrets redacted;
  `manifest.json`: display name, state, triggers and connections.
- `src/Solutions/<Name>/`: a whole solution, when the work lives in one.
- Each component folder has `package.json` (release config), `release.lock.json` (production
  pin) and, after the first release, `CHANGELOG.md`.

## Rules

1. Reads are fine: listing, exporting, downloading, reading run history (status, timings and
   errors only, no payloads).
2. Anything that writes to an environment (save, publish, import, turn on or off, run,
   share, delete) needs the user's explicit approval for that action.
3. Build new flows inside a solution: flows outside a solution have no version history.
4. After an approved change in production: `mise run export -- <id>`, then
   `mise run release:pin <id>`, and commit both in the same PR.
