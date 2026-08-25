---
description: "Phase 4 of 5: verify the artifacts the release claims to have produced. Checks that the git tag exists, the GitHub release is published, the marketplace clone is at the released version, every registered plugin has a cache directory, and each plugin hooks manifest is valid JSON. Exits non-zero when a required artifact is missing."
---

!mise run release:verify
