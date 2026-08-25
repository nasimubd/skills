---
description: "Prune old plugin cache versions for this marketplace, keeping the N most recent (default 3, override with KEEP_VERSIONS). Safe for live sessions: recent versions are retained so a session started under an older release does not break when its cache directory is removed. Run periodically to reclaim disk space."
---

!mise run release:clean
