# {{PROJECT_TITLE}} — core rules (always loaded)

{{DESCRIPTION}}

Systems: {{SYSTEMS_LINE}}

1. **Production is read-only for Claude.** Every create, edit, run, enable, disable, publish, import or upload on Power Platform, n8n, Make.com, Zapier, SharePoint or Asana needs the user's approval for that specific action. Never delete anything.
2. **Never edit a production artifact directly.** Work on copies named `[OPT] <name>` (flows, workflows, scenarios) or `TEST - <name>` (apps, lists, files), with triggers off. Promoting anything to production needs explicit approval.
3. **No client data or secrets in this repository**, reports or memory. Exports go through `mise run export`, which strips n8n `pinData` and redacts secrets. Keys come from environment variables or the macOS Keychain at run time; never print or store them.
4. **No AI attribution, anywhere.** No `Co-Authored-By` trailer for an AI assistant, no "Generated with …" line, no AI author or committer, in commits, PR titles, PR bodies, merge commits or release notes. The commit-msg hook and `mise run pr:check` reject it. See `.claude/rules/git.md`.
5. **Git protocol.** Conventional Commits with a component id or repo scope; one component per commit where possible; every change goes through a PR checked with `mise run pr:check`, then **rebase and merge**. Releases are cut per component from a clean `main` with `mise run release`. Full rules: `.claude/rules/git.md` and `docs/RELEASE.md`.
6. **A release never deploys.** Rolling a component forward or back in production is a separate, approved action, followed by `mise run release:pin <id>`.
7. Before working on a flow or app, read `.claude/rules/power-platform.md`. Before an n8n workflow, read `.claude/rules/n8n-workflows.md`. Before a Make scenario or a Zap, read `.claude/rules/make-zapier.md`. The stricter rule wins.
8. Every claim in a report, document or message is backed by evidence (command output, file and line, execution or run id, API response). `docs/architecture.md` cites the evidence for every link it draws.
