# Teams message style

Rules the user has set for messages drafted on their behalf, with where each came
from. Add to this file when the user corrects a draft; keep the date and the reason.

| Rule | Why / provenance |
|---|---|
| It is a **Teams chat message, never an email**: no subject line, no "Re:", no sign-off block, no long sections | User, 2026-10-23: "Whenever you are writing a message, it is for Teams, not for emailing." |
| **Short and to the point.** One-line greeting, a few bullets, the ask | Repeated user requests ("make it short", "to the point") across October 2026 sessions |
| **Detail lives in an attached document**, not the message. Name the file and its path | User, 2026-10-22 and 2026-10-28: "tell me which file I have to attach" |
| **Plain text that pastes cleanly**: no `>` quote bar, plain bullets (`-` or `•`), bold only where it survives a paste | User screenshot, 2026-10-28: "do not use this when you are drafting the replies" (the quote bar) |
| **No extra information** the recipient did not need for the decision | User, 2026-10-27: "I don't want you to include any extra information" |
| **The user decides releases and go-lives**; a message asks for approval, it never announces a decision the user has not made | User, 2026-10-27: "I am the one who is going to decide on the release" |
| **End-of-day report**: at most two sentences, with the numbers before and after | User, 2026-10-21 |
| **Never include credentials**, and never quote a message that contained one | Standing rule, 2026-10-21 |
| **Recommendations are worded as recommendations** ("I'd suggest…"), never as facts | Evidence rule, 2026-10-28 |

## Shape

```
Hi <first name>, <one line: what this is and the state of production>.

- <fact the recipient needs>
- <fact the recipient needs>

<the ask, as a question>
```

Use the recipient's first name as they write it. Times carry a timezone (UTC, or MYT
when the recipient works in it).
