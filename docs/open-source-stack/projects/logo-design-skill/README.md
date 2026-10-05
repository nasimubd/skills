# Logo Design Skill — agency review

## Decision

**Reviewed; suitable for a controlled Codex pilot for logo discovery, concept exploration, SVG quality checks, presentation boards, and export preparation.** Do not represent generated work as trademark-cleared or final human art direction. A designer remains accountable for originality, client decisions, licensing, and clearance.

## What we can use

The upstream skill provides a strong seven-phase workflow: brief, research, concepts, black-first SVG construction, testing, a concept checkpoint, then a selected-direction kit. Its dependency-free Python tools cover SVG auditing, preview/test sheets, rendering, presentation boards, and favicon/web-icon exports. This maps well to agency work across brand identities, websites, SaaS products, AI automation products, and internal product families.

Use the concept checkpoint as the client approval gate. Keep each client asset in its own project directory and preserve the upstream commit in the project manifest. Use the library for category research and construction study only; never trace or ship reference marks.

## Codex adoption

Codex can load the upstream `skills/logo-design/SKILL.md` directly because it uses the open Agent Skills format. The upstream `.claude-plugin` directory is optional and must not be required. The scripts should be invoked by absolute path relative to the loaded skill directory. The agency wrapper in `skills/logo-design-agency/` adds client confidentiality, provenance, accessibility, trademark, and delivery controls while preserving the upstream workflow.

## Agency controls

- Ask for business, audience, adjectives, competitors, constraints, decision-maker, and usage contexts.
- Record assumptions when the client cannot answer.
- Keep client inputs and generated assets segregated by project.
- Do not upload confidential briefs or unpublished marks to external services without permission.
- Run black/white, one-colour, reversed, 16 px, favicon, contrast, and context tests.
- Record fonts and licences; outline final wordmarks.
- Request professional trademark and similarity searches before claiming availability.
- Deliver source SVG plus documented PNG, favicon, web-manifest, lockups, palette, and usage guidance.
- Preserve review evidence, tool versions, upstream commit, and asset hashes.

## Limitations and risks

The skill is optimized for visual identity work and its included reference library is large. Its examples and library marks are not client-safe assets. Rendering quality depends on optional local renderers. AI-generated concepts can converge on familiar category forms, so similarity review and human art direction are mandatory. The repository's MIT licence does not grant rights to the third-party trademark logos in its library.
