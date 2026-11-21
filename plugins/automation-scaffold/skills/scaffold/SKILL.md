---
name: scaffold
description: Use when the user wants a new repository for a Power Platform, n8n, Make or Zapier automation, scaffolded from production with the release convention. TRIGGERS - scaffold a repo, new automation repo
allowed-tools: Bash, Read, AskUserQuestion
argument-hint: <app, flow or workflow name> [--name repo-name]
---

# Scaffold an automation repository

> **Self-Evolving Skill**: This skill improves through use. If instructions are wrong,
> parameters drifted, or a workaround was needed — fix this file immediately, don't
> defer. Only update for real, reproducible issues.

One command takes a named artifact in production (for example the app "Contoso New Client
Intake") to a merged, released repository: discovery of everything related, the standard
layout, the git protocol, a rebase-merged PR, the first release, and verification. The
convention it installs is in [references/convention.md](../../references/convention.md).

## Execution

### 1. Health

```bash
automation-scaffold health
```

Any ✗ stops the run: report the fix it prints (run the `setup` skill for configuration,
`az login` for Power Platform). Optional lines (!) only limit what discovery can see.

### 2. Discover (read-only)

```bash
automation-scaffold discover --seed "<name or id>" [--seed ...] [--exclude <name or id>] \
  [--include-copies] --out /tmp/<name>-discovery.json
```

- Platforms queried: Power Apps, Power Automate and n8n only.
- Scope is the event chain (depth 4): the lists the seed uses, the flows triggered by lists it
  **writes**, and what those flows call. Read-only lists are listed, not followed. `[OPT]` and
  `TEST -` copies are out unless `--include-copies`; `--exclude` drops anything the user names.
- An ambiguous or missing seed fails with the candidates; ask the user which one.
- `Not followed:` lists artifacts that write or touch a list in scope (for example the n8n
  workflows that fill a list a viewer app reads). Show each with its evidence and ask the user,
  with AskUserQuestion, which to include; re-run discovery with those as extra `--seed`s.
- Show the user the artifacts found and, for each link, its evidence (artifact, JSON path,
  value). Say which platforms were **not examined** (the `skipped` lines). Never add an
  artifact the discovery did not find.

### 3. Agree the plan, once, before anything is written

Work out:

- **Repository (upstream)**: never inferred. Not from configuration, git history, other
  repositories, the GitHub login, or the seed's name.
  - If the user shared the repository (URL or `owner/name`), confirm it read-only with
    `gh repo view <owner/name>`; an existing repository is used as is.
  - If the user did not share it, **stop and ask with the AskUserQuestion tool** before
    anything else: does the repository exist (and which one), or should one be created (with
    which owner and name). You may offer the seed's name in kebab-case, without organisation
    prefixes or `[OPT]`/`TEST -`, as a suggested *name*; the owner always comes from the user.
  - If `gh repo view` cannot find what the user named, ask again; do not guess a variant.
- **Folder**: `<workspaceDir>/<name>`, with `workspaceDir` from `automation-scaffold setup show`.

Then ask the user to approve, in one question, every action the run will take: create the
repository (only if missing), clone it, write the scaffold, install dev dependencies, commit,
push, open the PR, **rebase and merge** it, set the repository's About (description and
topics), run `mise run release`, and verify. Nothing past
this point runs without that approval.

### 4. Run

```bash
D="<workspaceDir>/<name>"
automation-scaffold publish repo --repo "<owner>/<name>" --dir "$D" --description "<one line>" --yes
automation-scaffold scaffold --dir "$D" --name "<name>" --repo "<owner>/<name>" --title "<Title>" --description "<one line>" \
  --discovery /tmp/<name>-discovery.json
automation-scaffold publish pr --dir "$D" --yes
automation-scaffold publish release --dir "$D" --yes
```

- `scaffold` exports every component read-only and pins it; a failed export is reported
  and stops the run. Never hand-edit an export to make it pass.
- `publish pr` commits in convention order (scaffold, one `feat(<id>)` per component,
  docs), runs `mise run pr:check` on the commits, PR title and body, then rebase-merges.
  It then sets the GitHub About from `project.json` `github`: the description (only if GitHub's
  is empty; an existing one is kept and reported) and the topics (added, never removed).
  `publish about --dir "$D" --yes` applies it alone, for a repository scaffolded earlier.
- `publish release` cuts `v1.0.0` for every pinned component and verifies tags, GitHub
  Releases, the About (description and topics), production against the pins, and that no
  commit carries AI attribution.

### 5. Report

Give the repository URL, the PR number, each component's tag, and the verification lines
as printed. Report any failure with its output; never describe a step as done that did not
print success.

## Rules

- **No AI attribution** in any commit, PR title, PR body or release. Do not add the
  Co-Authored-By trailer or "Generated with" line an AI tool would normally append; the
  scaffolded repo's hook and `pr:check` reject them.
- Production is read-only throughout: discovery, export and pin only read.
- An existing repository is never recreated, and existing files in it are kept.

## Troubleshooting

| Issue | Cause | Solution |
|---|---|---|
| `seed ... is ambiguous` | Several artifacts share the name | Re-run with the id from the list |
| Export fails `no live (published) version` | The app was never published | Publish it (user's decision), or leave that component out |
| `pr:check` fails | A commit or the title breaks the convention | Fix the message (`git commit --amend` on the branch), re-run `publish pr` |
| `release` skips a component | Its source differs from its pin | Production changed during the run: `mise run export -- <id>` and `mise run release:pin <id>` in a follow-up PR |
| `automation-scaffold: command not found` | Plugin installed mid-session | `/reload-plugins` or a new session |

## Post-Execution Reflection

After this skill completes, check before closing:

1. **Did the command succeed?** If not, fix the instruction that caused the failure.
2. **Did parameters or output change?** If a platform API or tool drifted, update the
   scripts, `references/platform-apis.md` and this file.
3. **Was a workaround needed?** If you improvised, record it so the next invocation
   doesn't need the same improvisation.

Only update if the issue is real and reproducible — not speculative.
