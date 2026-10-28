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
| `/teams-commander:message` | One command for the message: **draft** it (evidence shown for every fact), **reply** to a chat (read-only), or **send** it (opens the chat in the Teams app with the message on your clipboard; you paste once and press Enter) |
| `/teams-commander:setup` | Adds contacts (alias → work email) to a local file that is never committed |
| `/teams-commander:health` | Checks the dependencies and local configuration |

## How sending works

Tier 1 only: an `msteams://` [chat link](./references/deep-link.md) opens the chat in
the Teams desktop app, without the browser, and the message goes on your clipboard: one
copy, line breaks kept. You press ⌘V and Enter. The link deliberately carries no text:
in live tests Teams doubled pre-filled text or ignored it when the chat had a saved
draft. Nothing is posted automatically, and no extra Microsoft permission is needed. Scripted sending (Graph or Power Automate) is documented as a
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

macOS (`open`, `pbcopy`, `shasum`), `jq`, and the Microsoft Teams desktop app. Replies
read chats through the claude.ai Microsoft 365 connector when it is connected.

## Local files

| Path | Contents |
|---|---|
| `~/.config/teams-commander/contacts.json` | Contacts and optional tenant id |
| `~/.local/state/teams-commander/drafts/<id>/` | Each draft's message and evidence ledger |
