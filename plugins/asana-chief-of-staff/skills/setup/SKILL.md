---
name: setup
description: Use when configuring Asana Chief of Staff for a workspace and project.
allowed-tools: Read, Bash
---
# Setup

Set `ASANA_TOKEN`, `ASANA_WORKSPACE_GID`, and `ASANA_PROJECT_GID` in the runtime secret store. Run `asana-chief-of-staff health` and `project`, then confirm the project is reachable before creating any task.

## Post-Execution Reflection

Record only real setup failures and their fixes.
