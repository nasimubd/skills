# Add Norn integrations for Claude Code and Codex

## Summary

This pull request adds the user-facing integration layer for Norn, the separate local-first runtime that routes natural-language tasks across deterministic tools, local decision models, Argus-routed models, Agent-S, and human approval.

Argus remains unchanged and remains the high-throughput model gateway. The marketplace plugin does not duplicate account management, provider credentials, model weights, or desktop-automation source. It installs and verifies the external runtime and preserves a clear boundary between user experience and execution implementation.

## Claude Code integration

The new `norn-agent` marketplace plugin provides:

- `setup` for an isolated runtime installation under the user data directory.
- `doctor` for a non-destructive readiness check.
- `run` for dry-run task routing through Norn.
- References covering permissions, rollback, approval, verification, and operations.
- Explicit safety guidance for Argus credentials and Agent-S desktop permissions.

The setup path is idempotent and configurable through `NORN_RUNTIME_DIR` and `NORN_RUNTIME_REPO`. It does not silently install Argus, download model weights, or grant GUI permissions.

## Codex integration

`codex-plugins/norn-agent` provides a Codex-compatible package with matching runtime boundaries and documentation. It is deliberately kept beside, rather than mixed into, Claude marketplace metadata so each host can use its native plugin format.

## Terminology and documentation

The repository now records Norn, Argus, Jev, and Agent-S in the root terminology contract. Vale is configured with the accepted `Norn` vocabulary. Documentation covers installation, approvals, model policy, dry runs, updates, rollback, licensing, support, and compatibility.

## Safety model

- The marketplace layer never stores provider credentials.
- Agent-S remains optional and approval-gated.
- Low-confidence or privileged work is escalated by the runtime.
- Doctor and validation commands do not execute user tasks.
- Uninstall guidance avoids deleting a path implicitly.

## Validation

```text
node scripts/validate-plugins.mjs: passed
node scripts/check-version-equality.mjs: passed
node scripts/validate-skill-body.mjs: passed
git diff --check: passed
Vale CLAUDE.md: passed with 0 errors, warnings, or suggestions
```

## Review notes

This PR intentionally does not modify Argus or vendor Norn, Agent-S, or any decision-model implementation. After review, the next step is to publish a tagged Norn runtime and replace the setup checkout path with a pinned release when that release is available.
