# Feasibility and proof-of-concept results

## What was tested

A read-only SQLite backup of the live database was created in a private workspace.
The PoC then exported every `history_v2` row to JSONL, copied only referenced audio,
hashed source/archive/restored audio, filtered local settings, created a separate
SQLite database and restored from the serialized archive under a synthetic user ID.
The source database hash was checked before and after. No network mutation was
performed and the destination was never launched in Typeless.

The synthetic test suite covers Unicode/transcript metadata, binary blobs, duplicate
CSV terms, commas and quotes in dictionary terms, missing audio, symlink/path escape,
existing-workspace refusal, identity exclusion and source immutability.

## Results

| Check | Result |
|---|---|
| History rows exported | 18,215 |
| History rows restored from archive | 18,215 |
| Audio files copied and verified twice | 18,213 |
| Missing referenced audio | 0 |
| Local settings round-tripped | 13 selected fields |
| Source DB unchanged | Yes; SHA-256 unchanged |
| Destination SQLite integrity | `ok` |
| Credentials copied | No |
| Network requests | 0 during PoC |
| Learned personalization transferred | No |
| Destination accepted by Typeless | Not tested |

A separate authenticated request to the dictionary list endpoint was intentionally
limited to one item and rejected with HTTP 418/request-check failure. The client
uses bearer auth plus generated request security metadata; the PoC did not emulate
or bypass it. The result proves only that an ordinary external request is not an
acceptable extraction mechanism.

## What the PoC proves

- Local history/audio can be serialized and restored without modifying the source.
- A neutral archive can preserve rich metadata and binary values without copying
  credentials or account stores.
- IDs and `user_id` must be rewritten for a destination.
- Audio paths must be validated against the expected recordings directory and copied
  by content, not trusted as portable absolute paths.
- A destination DB can be made internally consistent, but that is not equivalent to
  Typeless accepting it.

## What it does not prove

- That history can be imported into a different Typeless account through supported UI
  or API. The observed sync API is account-bound and would require destination auth,
  server encryption keys and service authorization.
- That auto-added dictionary entries can be exported without the normal app session,
  or that their metadata can be recreated from terms alone.
- That the learned personalization model can be exported, imported or reassigned.
- That copied encrypted context remains meaningful under another account.
- That every local setting is safe to carry to another Mac, OS, display or microphone.
- That a production plugin may rely on private endpoints or reverse-engineered request
  signatures. Those are brittle and could violate account/service expectations.
