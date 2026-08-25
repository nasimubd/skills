---
description: "Phase 5 of 5: post-release git state validation. Resets lockfile drift (a build artifact, not a change), then verifies that no uncommitted changes and no unpushed commits remain. Catches release side effects that would otherwise accumulate silently. Exits non-zero on any failure."
---

!mise run release:postflight
