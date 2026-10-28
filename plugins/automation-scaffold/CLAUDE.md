# automation-scaffold — maintainer notes

**Hub**: [Root CLAUDE.md](../../CLAUDE.md) | **Sibling**: [plugins/CLAUDE.md](../CLAUDE.md)

## Decisions (2026-10-28, user-approved)

- Three skills, per the repository convention: `setup`, `health`, and **one** scaffolding
  command, `scaffold`. Everything inside a scaffolded repo is a `mise` task, not a slash
  command.
- Category `devops`.
- The scaffolded convention (layout, per-component releases, production pins, git protocol)
  is that of the user's reference automation repository. A scaffold run ends merged and released:
  PR, rebase and merge, `mise run release`, verification.
- **No AI attribution** in scaffolded repos' commits and PRs, stated in their `CLAUDE.md`
  and `.claude/rules/git.md` and enforced by commitlint and `pr:check`.
- An existing repository is used, never recreated; otherwise it is created private with the
  user's name or the most contextual one.

## Things that look wrong but are deliberate

- **The template is written from scratch, not copied.** The reference repository is
  private and this marketplace is public. The template implements the
  same documented behaviour and contains no organisation IDs: every environment, URL and
  Keychain name comes from the user's local config at run time.
- **`discover.js` reuses `template/scripts/lib/platform.js`.** One implementation of tokens,
  redaction and digests, so a scaffolded repo's pins equal what discovery and export saw.
- **Lists are documented, not components.** They have no export or pin yet.
- **Scope is the event chain, not every shared reference** (production dry run, 2026-10-28):
  following every link from an intake app pulled in a second, unrelated app and
  its flows through a list the app only reads. Discovery now follows app → lists it uses,
  list → flows it triggers *only when the list is written* (Patch/Collect/Remove/RemoveIf/
  UpdateIf/form in the live `.pa.yaml`, or a write `operationId`), and flow → what it calls.
  Never list → app. `[OPT]` and `TEST -` copies are left out unless `--include-copies`.
- **Package entries use backslashes** (`Src\App.pa.yaml`); extraction passes the archive's own
  name with backslashes doubled for `unzip`. The app list API has only data source titles;
  list ids come from the live package's `References/DataSources.json`.
- **Only Power Apps, Power Automate and n8n are queried** (user decision, 2026-10-28). Make is
  queried only if `config.platforms` lists it; Make and Zapier URLs inside flows are recorded as
  external endpoints, not examined.
- **The upstream repository is never inferred** (user decision, 2026-10-28). There is no GitHub
  owner setting. The user shares the repository, or the scaffold skill asks with AskUserQuestion;
  it never derives an owner from config, git history, other repos or the `gh` login.
- **`security -w` can print the Keychain value hex-encoded** when it holds a non-printable byte
  (a newline pasted with the key). `keychainSecret` decodes it, with the same condition the
  n8n export scripts in use apply. Missing this made a valid n8n key look revoked (HTTP 401).
- **Secrets are removed wherever they recur.** `redactEverywhere` redacts literal values under
  secret-looking names, then removes the same values anywhere else in the export.
- **No working directory is hard-coded.** `workspaceDir` is required configuration with no
  default; the only fixed path is the per-user config folder `~/.config/automation-scaffold`.
- **Zapier is documented only.** There is no general public API to export a Zap.
- **`PLATFORM_FIXTURES`** replaces every network call with files; it exists for the offline
  test and must never be set in real use.
- **`publish.sh` refuses to write without `--yes`.** The skill asks the user once for the
  whole plan, then passes `--yes`; without it every phase prints its plan.

## Tests

`tests/test-scaffold.sh`: setup → discover → scaffold → export and pin → the scaffolded repo's
own checks (registry, release gate, pins, commitlint config, AI-attribution rejection) →
publish dry run. Fully offline. Not covered: the live GitHub steps and `semantic-release`
itself, which run only in a real scaffold.
