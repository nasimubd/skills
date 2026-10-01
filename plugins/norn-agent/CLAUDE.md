# Norn Agent plugin

The plugin is a user-facing adapter to the independently released Norn runtime.

## Invariants

- Never store Argus or provider credentials in the plugin.
- Never install model weights without an explicit user action.
- Keep Agent-S optional and approval-gated.
- Prefer the runtime's pinned release over a mutable checkout when a release exists.
- Keep setup idempotent and provide a doctor command after every installation change.
