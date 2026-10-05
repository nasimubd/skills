---
name: custom-statusline
description: Configure the repository's custom status line for Claude Code or Codex. Use when the user wants session, model, context, token, git, project, or rate-limit information in the agent interface.
---

# Configure the custom status line

> **Self-Evolving Skill**: Update this skill when a platform's configuration
> contract changes and the change is reproducible.

This is the platform-neutral entry point. Keep the workflow portable: the
status-line renderer is shared conceptually, while each host's configuration
adapter is selected at execution time.

## Select the host

- For Claude Code, use the existing Claude adapter in
  `plugins/custom-statusline/skills/install/SKILL.md` and its
  `scripts/install.sh`.
- For Codex CLI, use the Codex adapter in
  `scripts/configure-codex-statusline.sh`.

The Codex adapter configures Codex's native TUI footer through
`~/.codex/config.toml`. Codex does not accept Claude Code's arbitrary
`statusLine` command, so do not copy the Claude settings shape into Codex.

## Codex commands

From this skill directory:

```bash
bash scripts/configure-codex-statusline.sh install --dry-run
bash scripts/configure-codex-statusline.sh install
bash scripts/configure-codex-statusline.sh status
```

The installer backs up the existing Codex configuration before changing it.
Restart Codex after installation if the running session does not refresh its
footer automatically. Use `uninstall` to restore the latest backup.

Read [references/codex-statusline.md](./references/codex-statusline.md) when
changing the item set or diagnosing a Codex version that supports different
footer identifiers.

## Post-Execution Reflection

After this skill completes, verify that the selected host accepted its
configuration and that an existing configuration was preserved. Record only
reproducible host-specific drift in this skill or its references.
