---
description: "Phase 2 of 5: run semantic-release to analyse conventional commits, determine the version bump, update the changelog, sync the version across package.json and every plugin manifest and the marketplace manifest, create the git tag, publish the GitHub release, and push. Depends on preflight passing. Driven by release.config.cjs."
---

!mise run release:version
