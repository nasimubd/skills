---
description: "Phase 3 of 5: sync the released version into the local Claude Code environment. Updates the marketplace clone to the new tag, populates the plugin cache with the new version while preserving older versions that live sessions still hold open, and refreshes the installed-plugins record. Run release:clean separately to prune old cache versions."
---

!mise run release:sync
