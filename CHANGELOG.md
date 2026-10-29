# [1.4.0](https://github.com/nasimubd/skills/compare/v1.3.0...v1.4.0) (2026-10-29)


### Bug Fixes

* **agent-skills:** register every shared skill for Codex and enforce it ([c2433ba](https://github.com/nasimubd/skills/commit/c2433ba8f067a55cf72e0985e81ed31a12a93ff9))

Codex discovers repository skills through .agents/skills/. Only custom-statusline was linked there, so logo-design-agency and open-source-stack-catalog passed every gate while staying invisible to Codex.

Add the two missing links, and make validate-agent-skills.mjs fail when a skills/&lt;name> has no .agents/skills/&lt;name> resolving to it, or when a link there points at no shared skill.
* **automation-scaffold:** download live app packages by a fresh link and report list writers ([3401689](https://github.com/nasimubd/skills/commit/3401689ce6cbb65d633a875b735f57d4a5cd03ac))

The versions API returns the package link signed at publish time, which expires seven days later, so any app not republished that week failed with HTTP 403. Download from the app endpoint's freshly signed link instead, after checking its blob is the live version's.

Discovery never follows a list back to what writes it, which hid the n8n workflows that fill a read-only viewer app's list. They are now reported under notFollowed with evidence, and the scaffold skill asks the user which to add as seeds.
* **automation-scaffold:** fit commit headers and set the repository About ([#11](https://github.com/nasimubd/skills/issues/11)) ([ffedeba](https://github.com/nasimubd/skills/commit/ffedeba3215e7297c5cb8d74af3f2357eca0053b))

The first real scaffold stopped at commitlint: component ids repeated the project name (n8n-aegis-matter-status-asana-to-microsoft-list), giving a 120-character header against a 72-character limit. Ids now drop the project name and stop at 36 characters on a word boundary, and a display name that would still overflow moves to the commit body.

The same run left the GitHub repository with no description and no topics. The scaffold now records both in project.json (a factual sentence counted from the components; topics from the component kinds and the release convention), and the new `publish about` phase applies them after the merge: an empty description is set, an existing one is kept, and topics are only added. `about --check` and release verification fail while either is missing.
* **automation-scaffold:** pin the commit author over git env variables ([da4f737](https://github.com/nasimubd/skills/commit/da4f737443719092c8b35deca1625c0e2ed4ae70))

semantic-release exports GIT_AUTHOR_* and GIT_COMMITTER_*, which override git -c user.name/user.email. publish.sh now sets them explicitly, so the configured author is used for every commit even when it runs under such a caller. Found when the marketplace release preflight ran the scaffold tests inside semantic-release.
* **custom-statusline:** expect the test's own path, not ~/skills ([e7ee153](https://github.com/nasimubd/skills/commit/e7ee153ccdd7a250b417bbb1f20553b58d579690))

The integration test expected the literal ~/skills in the rendered status line, which holds only on a machine where the repository is checked out there. statusline.sh shows the working directory with $HOME as ~, so the test now expects exactly that for wherever it runs. It was failing the release preflight on a checkout at ~/AegisLaw/skills.
* repair cross-platform custom statusline ([dffc4c8](https://github.com/nasimubd/skills/commit/dffc4c8e6f1e37e03b7202099440a4a8f8f9daf2))

Copy the Ligo reference renderer for Claude Code with its colors, context bar, directory, Git data, and session identifier. Add the reproducible shared skill and native Codex footer configuration.
* **repo:** enforce the git protocol with commitlint and pr:check ([#13](https://github.com/nasimubd/skills/issues/13)) ([9c28f05](https://github.com/nasimubd/skills/commit/9c28f05dfcb987764d50d4fce5602301b03949f6))

The convention in use (Conventional Commits, &lt;type>/&lt;slug> branches, rebase and merge, no AI attribution) was only written down, and the documents still said squash. Nothing checked it, so a bad message or an attribution line could reach main.

commitlint.config.cjs enforces Conventional Commits with a 72-character header, scopes read from plugins/, skills/ and codex-plugins/ plus repo scopes, and a no-ai-attribution rule (scripts/no-ai-attribution.cjs). The commit-msg hook runs it on every commit; `mise run hooks:install` sets it up. `mise run pr:check` checks the branch name, every commit since origin/main, the PR title and the PR body. CONTRIBUTING, the PR template, the root CLAUDE.md and .claude/rules/git.md (now tracked) say rebase and merge; the decision is docs/adr/2026-10-28-git-protocol.md. test-git-protocol.sh covers it.
* **teams-commander:** one message command, opened in the Teams app with one copy ([#12](https://github.com/nasimubd/skills/issues/12)) ([c8a55f9](https://github.com/nasimubd/skills/commit/c8a55f9bcdee69652411d44fa6f6abdc441977a9))

The user found five commands too complex and got two copies of each message. draft, reply and send are now one skill, `message`, which picks the action from the request; setup and health stay separate.

The chat now opens in the Teams desktop app through msteams://, which Microsoft documents as skipping the browser. The link no longer carries message=: the text was both pre-filled and on the clipboard, and in live tests Teams also doubled pre-filled text, ignored it when the chat had a saved draft and dropped line breaks. The clipboard is the only copy; the user pastes once and presses Enter. Verified end to end on the user's self-chat. Health also prints its summary line again.
* **tests:** run the git protocol test from main as well ([a69f9a5](https://github.com/nasimubd/skills/commit/a69f9a557b1099bda5be3089217a01d318e3c308))

The test's throwaway clone checks out whatever branch this repository is on. From main, `git branch -f main HEAD` refused to move the checked-out branch, so the test failed in the release preflight while passing on a feature branch. `checkout -B main` works from either.


### Features

* add provenance-pinned open-source registry ([#5](https://github.com/nasimubd/skills/issues/5)) ([3d15679](https://github.com/nasimubd/skills/commit/3d15679db66fa858f39e0b792b25e340eb5d228e))
* **automation-scaffold:** add the scaffolded repository template ([4ece92a](https://github.com/nasimubd/skills/commit/4ece92a93dfe67d6c1d3ea7327b3bdf80bace96b))

The layout, version control and git protocol every scaffolded automation repository gets: per-component releases (semantic-release-monorepo) with production pins, Conventional Commits checked by commitlint and a commit-msg hook, mise tasks, rebase-and-merge PRs, and no AI attribution, stated in CLAUDE.md and .claude/rules/git.md and enforced by commitlint and pr:check.

scripts/lib/platform.js is the single read-only platform layer for Power Apps, Power Automate, n8n and Make: tokens, digests and redaction. Secrets are redacted where they appear and wherever the same value recurs; a Keychain value returned hex-encoded by security -w is decoded.

Written from the documented behaviour of a private reference repository; no code or organisation identifiers were copied.
* **automation-scaffold:** scaffold, release and verify automation repos ([b0ae10a](https://github.com/nasimubd/skills/commit/b0ae10afbfe35321534fd7dc34abbd094622af4d))

Three skills: setup, health and one scaffolding command.

- discover: read-only, Power Apps, Power Automate and n8n only. Follows
  the event chain with evidence for every link: lists an app writes
  (Patch/Remove/form in the live .pa.yaml), the flows those writes
  trigger, the n8n webhooks and sub-workflows they call. Read-only lists
  are documented, not followed; [OPT]/TEST copies are left out.
- scaffold: renders the template, exports and pins each component.
- publish: uses the repository the user names, or creates it; commits in
  convention order, runs pr:check, rebase-merges the PR, releases v1.0.0
  and verifies tags, releases, pins and history.

The upstream repository is never inferred: the user shares it or the skill asks. No working directory is hard-coded.

Production dry run (2026-10-28, read-only, output kept local) found and fixed: list ids only in the app package, backslash package entries, over-broad scope through shared lists, a stub README kept over the real one, and the hex-encoded Keychain value. Registered under devops.
* **teams-commander:** evidence-gated Teams message drafts sent by deep link ([3aff456](https://github.com/nasimubd/skills/commit/3aff456e691519f9ce48959fbaa9f5f2fe77db58))

A plugin (not an MCP server) for drafting Microsoft Teams messages that the user sends under their own name. Every factual claim is recorded with its source, exact excerpt, capture time and how to reproduce it, and is shown to the user next to the message.

- bin/teams-commander: the plugin command, on the Bash PATH while the
  plugin is enabled (Claude Code v2.1.91+)
- scripts/teams.sh: draft ledger; verify refuses unverified or stale
  facts (6 h); link/open refuse a message edited after verify; excerpts
  shaped like credentials are rejected
- hooks/evidence-gate.sh: denies opening a Teams chat link outside
  teams-commander open; escape TEAMS-SEND-OK with a written reason;
  fails open
- skills: draft, reply (reads via the Microsoft 365 connector), send
  (tier 1 deep link, the user presses Send), setup, health
- references: style rules with provenance, evidence rules, templates,
  documented deep-link behaviour

Registered in the marketplace under the existing productivity category.

# [1.3.0](https://github.com/nasimubd/skills/compare/v1.2.0...v1.3.0) (2026-10-01)


### Bug Fixes

* **custom-statusline:** resolve gh under a minimal PATH ([1eaa747](https://github.com/nasimubd/skills/commit/1eaa747c4490760ec25b5cff4a3500f67ad3816c)), closes [#backed](https://github.com/nasimubd/skills/issues/backed)

Claude Code spawns the statusLine command with a minimal PATH, not the interactive shell's. jq and git survive this (macOS ships them system-wide); gh does not, since it lives only wherever Homebrew put
* shorten norn setup skill description ([6b251f0](https://github.com/nasimubd/skills/commit/6b251f0099e7e00d9933f8ee5192ba02d846d703))

Keep the user-facing trigger description within the marketplace skill contract while preserving discovery terms.


### Features

* add .vale integration surface ([962e86d](https://github.com/nasimubd/skills/commit/962e86de866f5ac94f5f044277e913db2984c069))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add accept integration surface ([40e8870](https://github.com/nasimubd/skills/commit/40e88706332df815e0e1ac9f6e41c8f9c8c51bce))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add CLAUDE integration surface ([e9100cc](https://github.com/nasimubd/skills/commit/e9100cc3a470addc42e14da76aa307ca493812d3))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add CLAUDE integration surface ([f1fe209](https://github.com/nasimubd/skills/commit/f1fe209930ef7d973361eea544b8a6b1856e8f98))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add doctor integration surface ([0c502ba](https://github.com/nasimubd/skills/commit/0c502ba6deacfcb2328d60cea74d46e29ca7e916))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add marketplace integration surface ([223ae87](https://github.com/nasimubd/skills/commit/223ae878cba24de51f851ea543864fe79fbd265a))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add plugin integration surface ([158ee5d](https://github.com/nasimubd/skills/commit/158ee5d66588d72712a3d200b9cd93f11397d292))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add plugin integration surface ([9df3719](https://github.com/nasimubd/skills/commit/9df37193af289544945ccb2677ca90a0d8ebc225))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add README integration surface ([df635ea](https://github.com/nasimubd/skills/commit/df635ea7a92add4867ac1d268213ea81b27d875b))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add README integration surface ([87bdaf3](https://github.com/nasimubd/skills/commit/87bdaf3f84920a27135bb269cd8343a5c699063e))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add README integration surface ([518a669](https://github.com/nasimubd/skills/commit/518a669dc200afdd21134210dab56ab64c9f938d))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add setup integration surface ([e4dff02](https://github.com/nasimubd/skills/commit/e4dff02caea9736d4dfeede46cdd224c64df846f))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add SKILL integration surface ([0a23c52](https://github.com/nasimubd/skills/commit/0a23c5270cff69d8275916a0f1eb6de6c24cc306))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add SKILL integration surface ([67d6884](https://github.com/nasimubd/skills/commit/67d68841373c9fcf8d3cb9b214d420c9df954eca))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add SKILL integration surface ([dfe9a5e](https://github.com/nasimubd/skills/commit/dfe9a5ee54f25a7ca023c7dc54d14d08226c804f))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.
* add SKILL integration surface ([48a066e](https://github.com/nasimubd/skills/commit/48a066e544989d623d5596bdd9c080f822ee7cfc))

Add one reviewable piece of the Norn integration while preserving the marketplace repository's provider and versioning boundaries.

# [1.2.0](https://github.com/nasimubd/skills/compare/v1.1.0...v1.2.0) (2026-09-29)


### Bug Fixes

* **custom-statusline:** align test-install.sh with sibling tests ([12507d1](https://github.com/nasimubd/skills/commit/12507d1fcf0951ae6bb2fdfb9566fe5b54328c2f))

Matches the PASS/FAIL naming and assert_eq shape the other test-*.sh files in this plugin already use, and adds a new_scratch_settings helper so every test gets its own temp file instead of sharing state.
* **custom-statusline:** back up before stub creation, not after ([b3263da](https://github.com/nasimubd/skills/commit/b3263dacb0ec3aed2b829ff5f8b3c7eb84d3fac4))

backup_settings_file ran after the fresh-install stub was already written, so a first-time install backed up the stub it had just created and reported it as a previous config. Backup now runs first, against whatever (if anything) was really there.
* **custom-statusline:** fix latest_backup_path under pipefail ([d3733d6](https://github.com/nasimubd/skills/commit/d3733d63a6c42f38abac68668e4820f87c7aa36f))

ls -1t $pattern | head -1 silently aborted the whole script whenever no backup existed: an unmatched glob makes ls exit non-zero, and set -o pipefail propagates that through head even though head itself succeeds — set -e then kills the assignment before run_uninstall prints anything. Caught by actually running uninstall with no backup present, not by reading the code.

Replaced with a nullglob array expansion that returns cleanly on zero matches, sorted with sort -r instead of relying on ls -t.
* **custom-statusline:** rename build skill to install ([6f618d9](https://github.com/nasimubd/skills/commit/6f618d97981f91743ef993752499f60b638bde79))

skills/build/ collided with the root .gitignore's generic build/ rule, which ignores a directory named build at any depth and silently refused to track the file. install also better matches the hub CLAUDE.md's verb glossary: this skill acquires and wires up a configuration, it does not construct anything.
* **custom-statusline:** stop freezing this repo's own release tag ([e4642bb](https://github.com/nasimubd/skills/commit/e4642bbd8be8f4f8ff86ba7a80b327888a49b9d4))

test-segment-release.sh asserted a literal v1.0.0 as this repo's latest published tag. That value is live and changes on every release, so the assertion broke the moment v1.1.0 shipped. Assert a semver pattern instead, which still proves the live fetch reached a real repo and returned a real tag.


### Features

* **custom-statusline:** add cache staleness row and reflection ([78ab534](https://github.com/nasimubd/skills/commit/78ab534e977ad526c250b78b0f540512b368657d))

Final troubleshooting row plus the mandatory Post-Execution Reflection section required by validate-skill-body.mjs.
* **custom-statusline:** add dry-run support to install ([fd21f80](https://github.com/nasimubd/skills/commit/fd21f802cbb646c3198f546e5aa675f5809a0152))

Prints what would change without touching settings.json or creating a backup.
* **custom-statusline:** add dry-run support to uninstall ([acc3f6a](https://github.com/nasimubd/skills/commit/acc3f6a1439768e9b07dbf6960115ee4ff1ea124))

Mirrors install's dry-run: reports what would happen, writes nothing.
* **custom-statusline:** add install action core logic ([f4f2958](https://github.com/nasimubd/skills/commit/f4f2958495641554ad5bf7b67cf1e0359af00bf7))

Creates settings.json if absent, backs up any existing statusLine, then patches in this plugin's command via jq.
* **custom-statusline:** add jq troubleshooting row ([ba4a75e](https://github.com/nasimubd/skills/commit/ba4a75e653b93d789651c3ae5bdc1822267ad3a3))

Missing jq is the failure both install.sh and statusline.sh hit first; call it out before the less common ones.
* **custom-statusline:** add reload and missing-segment rows ([d984c0f](https://github.com/nasimubd/skills/commit/d984c0fe33b57595e59d2302a2e79306e987cecd))

Two more common points of confusion: a stale session, and segments that correctly render nothing because there's no data.
* **custom-statusline:** add settings.json backup helpers ([3f896fa](https://github.com/nasimubd/skills/commit/3f896fa0393d849a45adaed6041e293127f3734a))

Timestamped backup before any write, plus a lookup for the most recent one so uninstall can restore it.
* **custom-statusline:** add status action ([6f49a40](https://github.com/nasimubd/skills/commit/6f49a40672d1c6a8ab0f1f1901298b5cede79f8a))

Reports whether settings.json exists, has any statusLine configured, and whether it points at this plugin.
* **custom-statusline:** add uninstall action ([3b8387b](https://github.com/nasimubd/skills/commit/3b8387b704e2d70906ccc4bb5f499b950efe37e9))

Restores the most recent backup if one exists; otherwise clears the statusLine field entirely.
* **custom-statusline:** describe install skill's purpose ([2c29a41](https://github.com/nasimubd/skills/commit/2c29a416d14e2b66f4121d0f48c05458ce04f1d3))

Sets the title to match the skill's actual verb and adds the overview section a reader hits first.
* **custom-statusline:** dispatch parsed action to its handler ([aa609fd](https://github.com/nasimubd/skills/commit/aa609fddaceeda3e052f08f464b5c0783c8023cb))
* **custom-statusline:** document install action in skill ([123f502](https://github.com/nasimubd/skills/commit/123f502ed572fd5cc9fac735f51a09200a624e03))

The install action and its --dry-run preview.
* **custom-statusline:** document segment customization ([0d7a94e](https://github.com/nasimubd/skills/commit/0d7a94e750ba208b555ffa87e63f50d3636761fe))

Points at references/segments.md and explains disabling a segment is a direct edit, not a config flag.
* **custom-statusline:** document status action in skill ([e71566e](https://github.com/nasimubd/skills/commit/e71566ef87d57c1f2c1b8b43067249ff567ecf10))

How to check whether the statusline is currently installed.
* **custom-statusline:** document uninstall action in skill ([dd673f6](https://github.com/nasimubd/skills/commit/dd673f6239c850594938631d951a4c409aaf2fb3))

The uninstall action and its backup-restore fallback.
* **custom-statusline:** parse action and --dry-run flag ([0a4cd72](https://github.com/nasimubd/skills/commit/0a4cd7222651c89e8f7da36a66433a89e01a2e12))

Validates the action name up front so a typo fails fast with the usage message rather than falling through to unimplemented logic.
* **custom-statusline:** resolve plugin root and settings path ([e8d6a74](https://github.com/nasimubd/skills/commit/e8d6a745157248c824ddd83a41e280eeb3270d5a))

Settings path is overridable via CUSTOM_STATUSLINE_SETTINGS_FILE so tests can point it at a scratch file instead of the real ~/.claude/settings.json.
* **custom-statusline:** scaffold install.sh with usage ([393a0f5](https://github.com/nasimubd/skills/commit/393a0f5455f3886b8baa96e2825a81ee5c1ae9e5))

Shebang, strict mode, and the usage message printed on missing/bad arguments.

# [1.1.0](https://github.com/nasimubd/skills/compare/v1.0.0...v1.1.0) (2026-09-29)


### Bug Fixes

* **custom-statusline:** always exit 0 from git_current_branch ([73ba924](https://github.com/nasimubd/skills/commit/73ba9245fc6d7f2c0876b3fc7d29ce4f5553845a))
* **custom-statusline:** always exit 0 from the statusline entrypoint ([77cb6d0](https://github.com/nasimubd/skills/commit/77cb6d0cb90e0d943240940cb38150e59b218d59))
* **custom-statusline:** guard empty-array deployments response ([716bc2e](https://github.com/nasimubd/skills/commit/716bc2e9ae52bcfaee155d9d3d6a7c48081f1d95))
* **custom-statusline:** normalize malformed stdin before segments run ([132cca9](https://github.com/nasimubd/skills/commit/132cca9df35c88faf4f7e746e38212b9fb75dce0))
* **custom-statusline:** supply required package_type for user packages ([da0dbcd](https://github.com/nasimubd/skills/commit/da0dbcda21807f4548c05742597f2894db448d1c))


### Features

* **custom-statusline:** add ahead/behind counts for git segment ([6e81bb1](https://github.com/nasimubd/skills/commit/6e81bb1d006eb71da480eeac0b2726ec20d9dae3))
* **custom-statusline:** add atomic cache_set ([9d7bb6c](https://github.com/nasimubd/skills/commit/9d7bb6c7795a69724c751cfa61aac53f4a336e53))
* **custom-statusline:** add cache directory resolver ([d210ac5](https://github.com/nasimubd/skills/commit/d210ac55c2a7e6406f7e00d31785e156268187a4))
* **custom-statusline:** add cache key sanitizer ([74d80bd](https://github.com/nasimubd/skills/commit/74d80bd88fb9e22c53d9959c26703c80a383a2de))
* **custom-statusline:** add cache_fetch to wrap a command with TTL cache ([6be4f8c](https://github.com/nasimubd/skills/commit/6be4f8c3fd63bf2ed49c1a154b9aceb967ab642a))
* **custom-statusline:** add cache_get with TTL expiry ([e33a7bf](https://github.com/nasimubd/skills/commit/e33a7bf3aae98a897e7f8850b9f2d1e924f26178))
* **custom-statusline:** add context-window percentage segment ([450d742](https://github.com/nasimubd/skills/commit/450d742d16c6bf8d37f1d8856c82c610fca0c6bf))
* **custom-statusline:** add deploy-workflow-run fetch ([6325275](https://github.com/nasimubd/skills/commit/6325275806f9c0472572ac217e34f4048f5ce36b))
* **custom-statusline:** add deployments-api status fetch ([0cfe4a3](https://github.com/nasimubd/skills/commit/0cfe4a3786986394433181d7b3999dbe2b2bb708))
* **custom-statusline:** add directory segment scaffold ([c62c1d7](https://github.com/nasimubd/skills/commit/c62c1d72447b7976bc3e25b62251b0277b740633))
* **custom-statusline:** add dirty-state counts for git segment ([4df02d8](https://github.com/nasimubd/skills/commit/4df02d83234479412ba94a1b37ded78c9fb32292))
* **custom-statusline:** add duration formatter for model segment ([65c4dd9](https://github.com/nasimubd/skills/commit/65c4dd937805125d160ba9599216a4e7760846b8))
* **custom-statusline:** add git branch resolver ([84d9429](https://github.com/nasimubd/skills/commit/84d942959ab3ab368fd7178a232b416afa46551f))
* **custom-statusline:** add guarded USD cost formatter ([939ad07](https://github.com/nasimubd/skills/commit/939ad07b6771be150b0ab9897b71b41b92b6d148))
* **custom-statusline:** add join_nonempty assembly helper ([9db076b](https://github.com/nasimubd/skills/commit/9db076bf7231bb73e773bc7bd69e375521104f0c))
* **custom-statusline:** add model segment scaffold ([a94c2cd](https://github.com/nasimubd/skills/commit/a94c2cd475f2d9483c31462b725b89d328761374))
* **custom-statusline:** add owner packages fetch with org/user fallback ([c6520ab](https://github.com/nasimubd/skills/commit/c6520ab0660dc503a80aa9eb151b76f5f254dc3a))
* **custom-statusline:** add portable cache file mtime lookup ([f809989](https://github.com/nasimubd/skills/commit/f8099890fd6576b580bce500264c25d4f0c472c7))
* **custom-statusline:** add release-tag fetch via gh api ([eadd8cd](https://github.com/nasimubd/skills/commit/eadd8cdc78f54d4cc534dc0bd36311ea50ed746e))
* **custom-statusline:** add session segment reading session_id ([d1e24bb](https://github.com/nasimubd/skills/commit/d1e24bb4a811233db9afcda92fcc135bb939223c))
* **custom-statusline:** add statusline entrypoint reading stdin ([f0de803](https://github.com/nasimubd/skills/commit/f0de8035042c2cb616964da7c6250d54c2619d98))
* **custom-statusline:** append session name when present ([a8ab828](https://github.com/nasimubd/skills/commit/a8ab828f328216027dc54bebf03dc736cf291147))
* **custom-statusline:** assemble footer line from model segment ([7bb0592](https://github.com/nasimubd/skills/commit/7bb059224e35bbdc8e62409e9d2c0c2f87dc799c))
* **custom-statusline:** assemble git segment with branch name ([c0b0613](https://github.com/nasimubd/skills/commit/c0b0613caa5c1ea81b4040174d389d839ae2d261))
* **custom-statusline:** assemble line 1 from session and directory ([b354878](https://github.com/nasimubd/skills/commit/b354878636b3194b5aff7f3f1913ea8e698ce1f4))
* **custom-statusline:** assemble line 2 from git and release ([9ecc6a6](https://github.com/nasimubd/skills/commit/9ecc6a6f24b8e52b8a3b4921cb265a46299beea7))
* **custom-statusline:** assemble line 3 from context window usage ([c5c1c7a](https://github.com/nasimubd/skills/commit/c5c1c7a51e654cda235a97e2e59bf5e0141282d9))
* **custom-statusline:** assemble line 4 from deployment and package ([a8550a8](https://github.com/nasimubd/skills/commit/a8550a8f4a707ed1f6c21c4a61f6428e135e8dc9))
* **custom-statusline:** assemble model segment with cost and lines-changed ([26ca310](https://github.com/nasimubd/skills/commit/26ca3104d3083e48dd40fee2de71980323cc700e))
* **custom-statusline:** assemble release segment through the TTL cache ([5dd4ded](https://github.com/nasimubd/skills/commit/5dd4ded3a466945e02441d0f45abf1aed9f9f853))
* **custom-statusline:** combine deployment sources, omit if neither exists ([6d08a46](https://github.com/nasimubd/skills/commit/6d08a46d96d747040dab6deaec2c9542518130d9))
* **custom-statusline:** combine package sources, omit if neither exists ([2f3caac](https://github.com/nasimubd/skills/commit/2f3caac12e8828e407b3353c2dd5662f5a8baa1b))
* **custom-statusline:** compare release tag against manifest version ([deb5d28](https://github.com/nasimubd/skills/commit/deb5d28acff854e0edbbda3dfc19d8610b2cbdac))
* **custom-statusline:** detect local manifest version ([a09de55](https://github.com/nasimubd/skills/commit/a09de5582dacbaa983ed008e2ed6a85dd032a6d2))
* **custom-statusline:** fall back to short sha on detached HEAD ([006dd46](https://github.com/nasimubd/skills/commit/006dd4641bbafe2cf8f9721e0efa4f4233d3cd20))
* **custom-statusline:** filter owner packages by repository ([960da72](https://github.com/nasimubd/skills/commit/960da72b9d4d2cb38f5c09aac6c3d7564c4eb199))
* **custom-statusline:** middle-truncate long directory paths ([6a3498b](https://github.com/nasimubd/skills/commit/6a3498b47fb2b10ce00833d922c42b3e9bea550d))
* **custom-statusline:** render ahead/behind arrows in git segment ([ba1e48f](https://github.com/nasimubd/skills/commit/ba1e48f63607912f7c3b1e2a10184554a33cae42))
* **custom-statusline:** render context usage as a block bar ([60594a0](https://github.com/nasimubd/skills/commit/60594a0aeed15291663068b97dddd3973c00341f))
* **custom-statusline:** render dirty-state symbols in git segment ([cb0d67b](https://github.com/nasimubd/skills/commit/cb0d67b89b0be7ca259e3ad02cdc4037f2ce3fe7))
* **custom-statusline:** resolve cache file path for a key ([796c2d7](https://github.com/nasimubd/skills/commit/796c2d75b01110277d5646b36e988afc376615e6))
* **custom-statusline:** reuse release-tag fetch in package segment ([d25e384](https://github.com/nasimubd/skills/commit/d25e384b14b284e8c6a0440cdad1021b86acc95a))
* **custom-statusline:** shorten session id to first 8 chars ([dc34dfe](https://github.com/nasimubd/skills/commit/dc34dfe07e793ab6aed8e9c69e44a823ad8afe2c))
* **custom-statusline:** source all segment libs in the entrypoint ([55a53dd](https://github.com/nasimubd/skills/commit/55a53dd1f9704f6784a02be14485842d091a47c8))
* **custom-statusline:** substitute home directory with ~ ([a9488d1](https://github.com/nasimubd/skills/commit/a9488d193665b3c359396a9594cf16161fe595ec))

# 1.0.0 (2026-09-29)


### Bug Fixes

* **release:** accept every legitimate GitHub token prefix ([d36f8bf](https://github.com/nasimubd/skills/commit/d36f8bf7a89aab186f34a1959e2d1ab5a4f4d654))

Check 2 accepted only ghp_ and github_pat_, so a gho_ OAuth token — what `gh auth token` returns when the CLI is authenticated interactively, and therefore the most common way this variable gets set on a developer machine — was reported as malformed.

Now accepts ghp_ (classic PAT), gho_ (OAuth), ghu_ (user-to-server), ghs_ (server-to-server) and github_pat_ (fine-grained). All five are valid for the API calls a release makes.

Found by running the gate rather than reading it. A gate that blocks the ordinary path is worse than no gate: the reflex it trains is to bypass it.
* **release:** reflow commit bodies for GFM, and stop hiding lockfile diffs ([e95b7df](https://github.com/nasimubd/skills/commit/e95b7df14b2c21ecd550a009cd35dd8be77d137b))

Two corrections to the scaffold.

The release-notes generator emitted commit bodies raw. GitHub renders a release body as GFM with hard line breaks on, so a body wrapped at 72 columns arrived studded with &lt;br>, an angle-bracketed generic like Vec&lt;T> was eaten as an unknown HTML tag, and indented blocks flattened. The transform now joins prose runs while preserving fences, structural lines and genuinely aligned columns, and escapes angle brackets outside code spans.

No try/catch around it, deliberately. It runs during generateNotes, before a tag exists, so a throw aborts the release with nothing published — which is the outcome we want. Catching would restore exactly the silent degradation being removed: an error logged, the raw body published, and a release that looks wrong for a reason nobody sees.

The test asserts on rendered output, not on the transform's return value — a transform-only test passes while every release still looks wrong. It was mutation-tested from both directions: bypass the reflow and 6 of its 25 assertions fail, covering all three modes; restore it and all 25 pass.

Separately, .gitattributes had `-diff` on lockfiles. `-diff` marks a file binary for diff purposes, so git reports only "Binary files differ" — locally and in review. For a lockfile that is precisely backwards: the lockfile diff is the one place a changed resolution, a substituted registry or an unexpected transitive dependency becomes visible to a person. Collapsing it is helpful; hiding it is a supply-chain review gap.

Not hypothetical: adding one test-only dependency split the tree and pinned a second copy of a package under semantic-release to satisfy a peer range. Invisible under `-diff`; one line of diff without it. That copy is now pinned to match what semantic-release already resolves.

CHANGELOG.md keeps `-diff` — it restates commits that are themselves reviewable, so nothing is lost by not diffing it.


### Features

* **repo:** scaffold the marketplace ([d5e8ac0](https://github.com/nasimubd/skills/commit/d5e8ac08f4092512d98f74bee8e3b8a1739911db))

An empty marketplace with working machinery, so the first plugin lands against gates that already pass rather than alongside gates written at the same time.

Structure follows an established reference marketplace: marketplace.json as the single source of truth, a tracked .claude-plugin/plugins symlink so a ./plugins/&lt;name> source resolves from either root, hub-and-spoke CLAUDE.md with progressive disclosure, and semantic-release cutting v&lt;version> tags with notes generated from commits.

Two gates here do not exist upstream:

- check-version-equality.mjs asserts the version lockstep actually holds
  — every plugin entry equals the marketplace root, and no per-plugin
  manifest carries a version key at all. Upstream's own strategy document
  specified this and it was never written; the observable cost was an
  entry six minor versions behind the marketplace shipping it, and a
  manifest pinned across roughly sixteen majors because it was in the
  release assets but not the version sync list.

- validate-skill-body.mjs asserts a skill's frontmatter name equals its
  directory name, plus the description budget, the references/ threshold
  and the two mandatory body sections. A slash command resolves on the
  directory, so a mismatch is invisible at runtime while the description
  keeps advertising the old identity.

Both were exercised against deliberately broken fixtures, not just against a passing tree.

Three divergences from the reference, each deliberate:

- .gitignore carries a !.claude/commands/ negation. The reference ignores
  .claude/ wholesale because it has no command wrappers; this repo commits
  its release namespace.
- .gitattributes exists. The reference has none, despite a committed
  symlink and a generated changelog now past a megabyte.
- Exactly one lockfile. The reference ships two.

Preflight is 462 lines against the reference's 1072: the universal core kept, seventeen hook-architecture audits not ported and tombstoned with the reason. Its empty-registry waiver for the test suite is derived from the manifest on every run, so it lapses by itself when the first plugin is registered — a flag set by hand is a flag left on.
