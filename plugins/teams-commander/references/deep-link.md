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

`teams.sh open` therefore always copies the message to the clipboard as well, and the
send skill tells the user to check the compose box before sending.

## Observations

Record real behaviour here as it is seen, with the date, Teams version and what
happened, so the unverified items above can be settled.

| Date | Teams version | Observation |
|---|---|---|
