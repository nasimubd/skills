# teams-commander

Draft Microsoft Teams messages for a named person, with **evidence for every fact**,
then open them in Teams for you to send.

Category: `productivity` · Keywords: developer productivity, Teams, messaging

## Why

A message you send under your name has to be true. This plugin makes the drafting
session prove each factual sentence (the command output, file line, execution, Teams
message or task it came from) and shows you that evidence before anything reaches
Teams. Unchecked claims block the send.

## Skills

| Command | What it does |
|---|---|
| `/teams-commander:draft` | Gathers evidence, writes a short Teams-style message, shows the message with its evidence table |
| `/teams-commander:reply` | Reads the latest messages in a chat (read-only) and drafts an evidenced reply |
| `/teams-commander:send` | Opens Teams with the verified message pre-filled and on your clipboard; you press Send |
| `/teams-commander:setup` | Adds contacts (alias → work email) to a local file that is never committed |
| `/teams-commander:health` | Checks the dependencies and local configuration |

## How sending works

Tier 1 only: a [Teams chat deep link](./references/deep-link.md) opens the chat with
the text in the compose box. Nothing is posted automatically, and no extra Microsoft
permission is needed. Scripted sending (Graph or Power Automate) is documented as a
higher tier and not built.

## How reading works

For now, replies are read through the claude.ai Microsoft 365 connector, read-only.
A direct Microsoft Graph reader (no MCP) is planned and kept out of this release.

## Install

```
/plugin marketplace add nasimubd/skills
/plugin install teams-commander@skills
```

Then run `/teams-commander:setup` and `/teams-commander:health`.

## Requirements

macOS (`open`, `pbcopy`, `shasum`), `jq`, and Microsoft Teams or a browser. The `reply`
skill reads chats through the claude.ai Microsoft 365 connector when it is connected.

## Local files

| Path | Contents |
|---|---|
| `~/.config/teams-commander/contacts.json` | Contacts and optional tenant id |
| `~/.local/state/teams-commander/drafts/<id>/` | Each draft's message and evidence ledger |
