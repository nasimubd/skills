---
description: "Execute the complete release pipeline: preflight validation, then semantic-release version bump plus changelog plus git tag plus GitHub release, then marketplace sync and cache population, then artifact verification, then postflight git state validation. Primary entry point for cutting a release. Requires GH_TOKEN and a clean working directory. Set RELEASE_TIMING_PROFILE=1 for per-phase wall-clock instrumentation."
---

!mise run release:full
