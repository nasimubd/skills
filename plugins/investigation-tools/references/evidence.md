# Evidence tags

Every factual statement in a brief or a root-cause note carries a tag the reader can check:

```
[source: <where it came from>; "<the exact excerpt>"; captured <when you read it>; repro: <how to see it again>]
```

Example:

```
- The run failed with an HTTP 500 error. [source: run history, run 41 log line 14; "HTTP 500"; captured 2026-11-12T14:00Z; repro: open run 41 in the run history]
```

The lint checks that a tag is present and has some content; it cannot check that the excerpt is
real. Reading the excerpt against the source is the reader's job, which is why it is quoted.

A statement you cannot evidence is a question, an opinion, or removed:

- "What is not known" holds questions.
- Opinion is labelled as opinion ("My reading, not evidenced: …").
- A timeline entry that comes from the person's own account says so: `[source: reported by the requester]`.

Never put a secret in a tag or an excerpt. Run `investigation-tools scan <file>`; use
`redact` output for anything quoted from a source that contained one.
