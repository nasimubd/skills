---
description: "Phase 1 of 5: validate every release prerequisite before the version bump. Gating checks: clean working directory, GH_TOKEN presence and shape, marketplace manifest validation, plugin-versus-marketplace version equality, skill body validation, the marketplace regression suite, and releasable conventional commits since the last tag. Informational checks: expected GitHub account. Missing evidence counts as a failure, never as a pass. Exits non-zero on any gating failure."
---

!mise run release:preflight
