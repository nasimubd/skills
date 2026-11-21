# Blameless wording

A root-cause note explains what the system and the process allowed. It does not say who failed.
People act reasonably on what they can see; the question is why the situation made the failure
possible and easy.

| Instead of | Write |
|---|---|
| "Human error caused the outage" | "The deploy step accepted a mapping that referenced a column that no longer existed" |
| "The engineer should have checked the schema" | "No check compared the mapping with the schema before the run" |
| "Someone forgot to renew the connection" | "Connection renewal depended on a calendar reminder; nothing alerted when it lapsed" |
| "Careless edit broke the flow" | "The flow could be edited and published without a test run" |

The lint (`rca lint`) flags: human/operator/user error, careless(ly), negligent/negligence,
incompetent/incompetence, blame/blamed, at fault, fault of, should have known/checked/noticed/caught/
tested/read, forgot to, failed to notice/check/read/test/review/verify. It is a pattern list: a
sentence can pass and still assign blame, and a sentence about a system can be flagged. Read the
note for blame yourself.

One prevention step, not a list: pick the single change that most reduces the chance of a repeat.
Everything else goes under "Deferred work", which is where optimisation belongs: during an incident
the order is contain and fix first, improve later.
