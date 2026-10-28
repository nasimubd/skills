# Teams chat deep link

## Documented behaviour

Source: Microsoft Learn, "Deep link to a Teams chat",
<https://learn.microsoft.com/en-us/microsoftteams/platform/concepts/build-and-test/deep-link-teams>
(page dated 2026-03-26, docs commit `5751bb46`, read 2026-10-28).

```
https://teams.microsoft.com/l/chat/0/0?tenantId=<tenantId>&users=<user1>,<user2>,...&topicName=<chat name>&message=<precanned text>
```

- `users`: comma-separated; "supports the Microsoft Entra `UserPrincipalName`, such as
  an email address only". The person opening the link is always a participant.
- `topicName`: optional; the chat's display name "if a chat has three or more users".
- `message`: optional; text inserted "into the current app user's compose box while
  the chat is in the draft state".
- If no chat exists with those participants, Teams opens an empty new chat.
- The link only fills the compose box. The person must select **Send** or press Enter.

## Not documented (treat as unverified)

- A maximum length for `message` or for the whole URL.
- Whether `%0A` line breaks are kept in the compose box.
- Whether the pre-filled text is applied when the chat **already exists** (the doc says
  the TeamsJS equivalent opens the existing chat; the manual link is not explicit).

## Protocol handler

Source: Microsoft Learn, "Configure deep links", section "Protocol handlers in deep links"
<https://learn.microsoft.com/microsoftteams/platform/concepts/build-and-test/deep-links#protocol-handlers-in-deep-links>
(read 2026-10-28): "The `msteams://` protocol handler skips the client selection screen in
the browser and opens the deep link directly in the Teams desktop client." Users without
the desktop client might not be able to open it. Do not prefix an `https://` link with
`msteams:`; replace the scheme.

## What teams-commander does

`teams.sh open` opens `msteams://teams.microsoft.com/l/chat/0/0?users=...` (no `message=`)
and puts the message on the clipboard once; the user pastes it with ⌘V and presses Enter.
See the observations below for why the text is not in the link.

## Observations

Record real behaviour here as it is seen, with the date, Teams version and what
happened, so the unverified items above can be settled.

| Date | Teams version | Observation |
|---|---|---|
| 2026-10-28 | macOS 26289.203.5259.2574 | `msteams://` opened the desktop app directly, no browser, in all five tests (self-chat). |
| 2026-10-28 | same | `message=` with no saved draft and another chat on screen: applied once (2 tests). |
| 2026-10-28 | same | Self-chat on screen with a saved draft, two-line `message=`: draft replaced by the new text **twice**, line break dropped (`test 2second linetest 2second line`). |
| 2026-10-28 | same | Self-chat on screen with a saved draft, one-line `message=`: **ignored**. |
| 2026-10-28 | same | Compose box cleared, another chat on screen, two-line `message=`: **ignored**; Teams showed the earlier draft (`test 4`) instead. |
| 2026-10-28 | https link + clipboard (before this change) | The user reported two copies of the message in the compose box. |
| 2026-10-28 | macOS 26289.203.5259.2574 | End to end with this change, first run: the user later reported seeing nothing; the run was not observed step by step, so its result is unknown. |
| 2026-10-28 | same | End to end, second run (`teams-commander open`, self-chat, two-line verified draft, link without `message=`; compose box cleared and another chat on screen first): Teams came to the front on the self-chat with no browser (confirmed by the user), and one ⌘V gave exactly one copy with both lines (confirmed separately). |