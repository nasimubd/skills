# Asana Chief of Staff

Autonomous Asana project management through the direct REST API, with free-plan workflows and guarded destructive actions.

Turn a goal into coherent Asana work. The plugin inspects the configured project, follows its conventions, performs routine edits autonomously, and records context in task notes and comments.

## Configuration

Set `ASANA_TOKEN`, `ASANA_WORKSPACE_GID`, and `ASANA_PROJECT_GID`. The client uses `https://app.asana.com/api/1.0` and never logs the token.

## Commands

`asana-chief-of-staff health`, `asana-chief-of-staff project`, `asana-chief-of-staff tasks`, `asana-chief-of-staff create --name ...`, `asana-chief-of-staff comment --task ... --text ...`.
