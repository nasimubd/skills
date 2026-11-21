# Private research harness

The files in this directory are intentionally small and self-contained. They do not
include the app, a profile, credentials, extracted bundles or employer content.

- `poc.py` performs the offline archive/restore PoC against paths supplied by the
  operator. It requires a new output directory, refuses path escapes, does not make
  requests, excludes session/account files, and labels restored sync state as
  `poc_quarantined`.
- `test_poc.py` runs synthetic tests without reading the installed app profile.
- `artifact-manifest.json` records version/hash provenance for the inspected build.

The live PoC output and source snapshot live under a private application-data
research directory outside Git. Do not point scripts at a destination profile until
a separately approved implementation exists; a successful SQLite restore is not an
official Typeless import.
