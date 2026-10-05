---
name: logo-design-agency
description: Use when delivering logo or identity work for an agency client with Codex. Wrap the logo-design skill with provenance, confidentiality, trademark, accessibility, and handoff controls.
allowed-tools: Read, Write, Bash, WebFetch
---

# Agency logo design

> **Self-Evolving Skill**: Improve this skill when a real, reproducible client workflow issue is found.

Use the reviewed upstream logo-design skill at the pinned commit recorded in `docs/open-source-stack/projects/logo-design-skill/project.yaml`. If it is installed separately, locate its `SKILL.md` and scripts; the Claude plugin metadata is optional. Keep client work in a dedicated project directory.

## Agency workflow

1. Create a client brief with name, audience, offer, adjectives, competitors, constraints, decision-maker, use contexts, confidentiality level, and assumptions.
2. Record the upstream skill commit, runtime/tool versions, and project asset manifest before generating work.
3. Run discovery, category research, word mapping, and at least two mark-type directions.
4. Build and test three distinct black-first SVG concepts. Do not use reference-library marks as source artwork.
5. Run SVG audit, 16/32/64 px tests, one-colour, reversed, contrast, context, and competitor-shelf checks. Render and inspect the outputs.
6. Stop at the concept checkpoint. Obtain the client's direction before building the kit unless the client explicitly asks to skip the checkpoint.
7. For the selected direction, produce lockups, small-size artwork, palette, typography, guidelines, presentation boards, favicons, web icons, and delivery notes.
8. Record fonts and licences, hash deliverables, and flag that trademark clearance requires professional searches.
9. Store the review event and evidence path beside the project; do not send confidential assets to external services without authorization.

## Codex constraints

Prefer local Python scripts and local rendering. Ask before network uploads or external image generation. Keep source SVG editable, avoid live text in final marks, and disclose when rendering or inspection could not be completed.

## Post-Execution Reflection

Verify the client checkpoint, asset hashes, upstream commit, licence notes, rendering evidence, and confidentiality handling before delivery.
