---
paths:
  - "workflows/**"
  - "reports/**"
---

# n8n workflows (on demand)

{{N8N_LINE}}

1. Never edit a production workflow directly. Duplicate it as `[OPT] <name>` and work on the copy.
2. Always fetch the latest version before editing; the workflow may have changed in the UI.
3. One change per cycle: edit, validate, test-run, read the execution, commit.
4. Promoting an `[OPT]` copy (activating it, moving triggers, deactivating the original)
   needs explicit approval.
5. Executions may contain client data. Read only what a diagnosis needs: status, timings,
   error messages, node names. `workflows/**/workflow.json` never contains `pinData`;
   `mise run export` strips it and redacts secrets.
6. After an approved change in production: `mise run export -- <id>`, then
   `mise run release:pin <id>`.
