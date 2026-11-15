# Closing the stated limits of the guard, guide and investigation plugins: research record

Research done on 2026-11-12 for [the proposed decision](../../adr/2026-11-12-closing-plugin-limits.md).
It records what was checked first-hand, what was only reported by research helpers, and what could
not be checked, so a later reader can tell which claims to trust. Version of the host used for every
experiment: Claude Code 2.1.322.

How to read the evidence labels:

- **Verified (doc)**: quoted from the host's official documentation, fetched during this work.
- **Verified (experiment)**: observed by running it; the setup is described so it can be repeated.
- **Verified (source)**: checked against the project's own repository page or the paper's abstract page.
- **Reported**: stated by a research helper from a source that was not re-read. Treat as a lead.
- **Not found / not verified**: searched for or attempted and not established.

## The three limits

The three plugins shipped with these stated limits:

1. The scans for planted instructions, secrets and blame wording are heuristics, and a passing guide
   lint shows names exist in the source, not that a path works in the running application.
2. `investigation-tools` cannot stop a write; only `change-guardrails` can.
3. The trials were smoke tests: a handful of live sessions, local files as the "ticket", output that
   varies between runs.

## Limit 2: can a plugin technically enforce "read-only"?

### Documented mechanisms (Verified, doc)

| Mechanism | What the documentation says |
|---|---|
| Plugin subagents | Live in `agents/`; namespaced `plugin:agent`. "For security reasons, plugin subagents don't support the `hooks`, `mcpServers`, or `permissionMode` frontmatter fields. These fields are ignored when loading agents from a plugin." |
| Subagent `tools` / `disallowedTools` | `tools`: "Inherits every tool available to subagents if omitted." `disallowedTools`: "Tools to deny, removed from inherited or specified list." An entry with a specifier such as `Bash(git push *)` "still removes the whole tool", not only the matching commands. |
| MCP patterns in an agent | `tools: mcp__server__*` grants one server's tools; `disallowedTools: mcp__server` or `mcp__server__*` withholds one server; `mcp__*` withholds every MCP tool. |
| Permission inheritance | A subagent inherits the parent's permission mode. If the parent runs in `bypassPermissions`, `acceptEdits` or auto mode, the subagent runs in that mode and ignores its own setting. |
| Skill `context: fork` | "Claude Code starts a new subagent of the type set in the `agent` field and gives it the skill content as its prompt." The subagent does not see the conversation. `background: false` waits for the result. The page lists built-in agent types and custom agents from `.claude/agents/`; it does not say whether a plugin-provided agent can be named. |
| Skill `allowed-tools` | A grant, not a fence: "Tools Claude can use without asking permission during the turn that invokes this skill." It clears at the next message. |
| Skill `disallowed-tools` | "Tools removed from Claude's available pool while this skill is active." Also cleared at the next message. |
| Skill `hooks` | "Hooks that Claude Code registers when the skill is invoked and keeps running for the rest of the session." |
| Plugin `settings` | "Only `agent` and `subagentStatusLine` take effect; other keys are dropped at load." A plugin cannot ship `permissions` or a default permission mode. |
| Plugin hooks | Declared in `hooks/hooks.json` (and the manifest); merged with the user's hooks while the plugin is enabled. |
| Hook failure modes | Exit code 2 blocks the call. A timed-out or crashed hook does not block unless the hook sets `onFailure: "block"` (host 2.1.295 or later). |

### Experiments (Verified, experiment)

All run with `claude -p` against a throwaway plugin. In each, the parent session was granted Write,
Edit and Bash on purpose, so only the agent's own tool set could stop an action.

| # | Question | Setup | Result |
|---|---|---|---|
| 1 | Can a skill fork into the plugin's own restricted agent? | Skill with `context: fork`, `agent: <plugin>:reader`; reader `tools: Read, Grep, Glob`, `disallowedTools: Write, Edit, NotebookEdit, Bash`; the skill asks it to write a file and run a shell command | Yes. The plugin-namespaced agent resolved. The agent reported it had only Read, Grep and Glob; neither file was created. |
| 2 | Does a Bash pattern in an agent's `tools` narrow the shell? | Agent `tools: Read, Grep, Glob, Bash(echo:*)`; the task runs `echo`, `ls` and `touch` | No. All three ran and the file was created. A pattern in `tools` does not restrict Bash, which matches the documented behaviour for `disallowedTools`. So a read-only agent must have no Bash at all. |
| 3a | Does the guard hook cover a subagent's shell call? | Force-push attempted by a forked agent with Bash | Inconclusive: the agent declined on its own judgment and never issued the command, so the hook was never exercised. |
| 3b | Same, with a harmless probe | A custom guard rule that asks on `echo guard-probe`; a forked agent with Bash runs it | Yes. The guard recorded the decision for the subagent's call, and a main-thread control behaved identically. Plugin hooks cover tool calls made inside a forked subagent. |

### Consequences of the above

- A forked, tool-restricted agent shipped by the plugin makes the read step **technically** unable to
  write, regardless of the parent's permissions.
- The reader cannot run the plugin's own scanners (they need a shell), so scanning happens on the text
  it returns.
- Plugins cannot ship MCP servers inside agents, and the names of a user's connector tools are the
  user's own. A reader that must use a connector needs an exact-name allow-list the user writes.
- Nothing a plugin ships can restrict the main thread, set permissions, or make a hook fail closed
  without the user's own settings.

### Not found / not verified

- Hook coverage of the notebook-edit tool and the exact empty-matcher semantics.
- Whether the host's sandbox (reported to cover shell commands only) can be enabled by a plugin.
- How the host treats MCP tool annotations such as a read-only hint (reported as not used for
  permissions; only issue-tracker evidence was seen).
- Whether `settings.agent` can make a restricted agent the whole session's default.

## Limit 3: evaluating non-deterministic behaviour

### The host's own tool (Verified, doc and local help)

`claude plugin eval` runs a plugin against cases in `evals/` and scores them.

- Cases: `evals/<case>/prompt.md` (frontmatter and graders) or `case.yaml` (`schema_version: "1.1"`).
  Runs per case default to 3 (`--runs` overrides); a case passes when its score meets `--threshold`
  (default 1.0).
- Graders: `regex`, `tool_used`, `tool_order`, `file_exists`, `llm` (a judge votes, passes on at least
  two of three), `baseline`. "There are no custom-code graders." A command can be graded by having the
  session run it, write the outcome to a file, and grading that file together with a `tool_used` check.
- Targets a grader can read: `last_message`, `trace`, `files` (paths only), a file's contents, or mock
  calls.
- Isolation: a run starts in an empty workspace; user settings, hooks, project instructions, MCP
  servers, other plugins and memory are absent. Fixtures come from `context.add_dirs` (read-only) or a
  `scaffold_script`, which runs only with `--scaffold`.
- Tools: runs never prompt. Tools outside the read-only set must be granted with `--allow-tools`, and a
  case lists the read-only tools it wants under `allowed_tools`. A granted shell runs in an OS sandbox.
- Cost and CI: `--max-cost-usd`, `--json`, `--model`, `--judge-model`, `-j`, `--trust-plugin`.
  A with/without-plugin delta is reported but never changes the exit code.
- Reports: an HTML report is **published to the vendor's site by default** when the account supports
  it; `--no-publish` keeps it local.
- `/skill-doctor` is a cost and usage report, not a quality evaluation (reported).

### Experiment: the first real evaluation (Verified, experiment)

One case for `click-path-guides`: an honest request on a sample definition, six graders (the skill's
own text reached the session, the guide file exists, it has a Prerequisites section, it names a real
control, it names no invented control, the lint command was run). 15 runs in total across seven
invocations while the case was debugged; the final configuration ran 3 times.

| Configuration | Outcome |
|---|---|
| Case without `allowed_tools` | Every run: the skill call was **denied**, the session improvised a guide with no Prerequisites section and never ran the lint |
| Same, graded with "the Skill tool was called" | That grader still **passed**, because a denied call counts as a call |
| `allowed_tools` placed at the top level of `case.yaml` | Silently ignored; the same failure. The key belongs under `execution:` |
| Corrected placement, `Bash(<command>:*)` grant | 5 of 6 graders passed in all runs; the lint grader failed, because the session chained its commands into one compound command and a pattern grant only matches a command that starts with the pattern |
| Corrected placement, plain `Bash` grant (OS-sandboxed) | **2 of 3 runs passed completely; 1 of 3 skipped the lint step** despite the skill instructing it |

Findings: (a) a multi-run, process-graded evaluation exposed a reliability gap that every earlier
single-run trial missed; (b) four setup traps cost more time than the plugin did, and each is now
documented; (c) a "skill was used" grader must check that the skill's text reached the session, not that
the tool was called; (d) the tool's per-run cost estimate (API-price terms; an estimate, not a bill) was about 0.15 per run
with a pattern grant and about 0.31 with a plain-shell grant, because the session did more work once
it was able to run its commands.

### Statistics (Reported, arithmetic Verified)

- A single pass proves little: a case with a true pass rate of 0.8 passes 3 of 3 runs 0.8^3 = 51% of
  the time.
- With all n trials passing, the Wilson 95% lower bound on the per-trial pass rate is n / (n + 3.84):
  10 trials: 0.72; 20: 0.84; 30: 0.89; 50: 0.93. (Arithmetic checked here; the formula is the standard
  Wilson interval at p = 1.)
- Consistency (`pass^k`, all k trials succeed) is the right metric for a release gate; defined in the
  tau-bench paper (arXiv 2406.12045, reported).
- The host's eval reports a mean score and per-run scores but no confidence interval and no documented
  seed or temperature control.

### Frameworks and corpora (Verified, source: licence and last push from each repository page)

| Project | Licence | Last push | Note |
|---|---|---|---|
| Inspect (`UKGovernmentBEIS/inspect_ai`) | MIT | 2026-11-12 | Can drive the host through a bridge package (reported); Docker |
| promptfoo | MIT | 2026-11-12 | Drives the agent SDK, not the CLI binary (reported) |
| AgentDojo | MIT | 2026-06-02 | Injection tasks and attacks, reusable as a payload source |
| InjecAgent | MIT | 2024-07-02 | Older than 12 months |
| WASP | not stated | 2026-04-13 | Web-agent benchmark; licence field empty |
| garak | Apache-2.0 | 2026-11-06 | Targets models and endpoints, not host skills (reported) |

A static payload corpus overstates security: see the adaptive-attack result under Limit 1.

### Live-system testing (Reported)

The host's eval supports mocked MCP servers (`evals/mocks/<server>/<tool>.md`, with input guards and
replay). A public read-only data source (public issue trackers) is usable without an account within
unauthenticated rate limits (reported: 60 requests per hour for the GitHub REST API). Seeded canary data,
read-only tokens and scheduled re-recording are standard practice but were not sourced to primary
documentation. The eval environment forwards only `EVAL_*`-prefixed variables and an allow-list, so a
tracker token would need that prefix.

## Limit 1: heuristics

### Detection cannot be made reliable (Verified, source)

- arXiv 2510.09023, "The Attacker Moves Second" (Nasr, Carlini, Sitawarin et al., 10 October 2025):
  using gradient descent, reinforcement learning, random search and human-guided exploration the authors
  "bypass 12 recent defenses ... with attack success rate above 90% for most", where "the majority of
  defenses originally reported near-zero attack success rates". The abstract does not name the defenses.
- arXiv 2403.14720, "Defending Against Indirect Prompt Injection Attacks With Spotlighting" (20 March
  2024): reports attack success falling "from greater than 50% to below 2%" on "GPT-family models". The
  abstract names no benchmark and does not discuss adaptive attackers. A figure from one benchmark must
  not be compared with another's.
- Consequence: any pattern or classifier is a tripwire, not a gate. Architectural controls (no write
  tools on the reading step, data flow separated from instructions) carry the weight.

### Reported design patterns (Reported)

Separating a privileged planner from a quarantined reader (CaMeL, arXiv 2503.18813, Apache-2.0
research artifact), per-task allow-lists of tool calls (Progent, arXiv 2504.11703), information-flow
labels (FIDES, arXiv 2505.23643). Published numbers differ between versions and benchmarks and were not
re-read; none is adopted as code. The pattern they share is what the proposal copies.

### Secret detection tools (Verified, source: licence, archive state and last push)

| Tool | Licence | State | Use |
|---|---|---|---|
| gitleaks | MIT | active; README: "feature complete ... security patches only" and points to its successor; latest release 2026-03-21 | Optional scanner; rules could be ported with attribution |
| betterleaks | MIT | active (push 2026-11-09); README: maintained by the gitleaks authors | Optional scanner; watch |
| trufflehog | AGPL-3.0 | active | Optional external tool only; never copy rules; live verification sends a secret to the service |
| detect-secrets | Apache-2.0 | last push 2026-04-02 | Optional scanner; patterns reusable with notice |
| Nosey Parker | Apache-2.0 | archived (retired) | Rejected |
| Titus (its successor) | Apache-2.0 | active | Not evaluated |

No precision or recall figures for any scanner were found. A short set of prefixed-token patterns is
the zero-dependency core; entropy and keyword rules produce false positives.

### UI paths: names versus working paths

- Doc Detective (AGPL-3.0, active) runs documentation steps as browser tests; AGPL rules out vendoring.
- Playwright (Apache-2.0, active) offers accessibility-tree assertions on roles and accessible names
  (reported from search summaries, not the primary page).
- The Power Apps Test Engine is described on the vendor's learning pages as deprecated in favour of
  Playwright samples (reported from search summaries; its repository path returned not-found from the
  repository API, so its state is unverified).
- Any of these needs a browser, a reachable application and credentials, so each is an optional adapter,
  never a default.

### Blame wording

One search found no study or tool that detects blame framing in incident reports; only vendor
guidance, a conference talk on language and blame, and root-cause tagging work. Not exhaustive. The
wording check stays a nudge.

## What was not established

- Primary-source numbers for CaMeL, Progent, FIDES, the prompt-guard classifier and the benchmark attack
  rates other than the two abstracts above.
- Whether plugin hooks fire for the notebook-edit tool; whether a plugin can enable the sandbox.
- Whether the host's eval has any seed or temperature control.
- Licences or activity for several tools reported by helpers (see the tables: only those with a
  repository-page check are listed as verified).

## Corrections to earlier claims in this repository's records

- The earlier decision record for `investigation-tools` said enforcement of read-only "belongs to the
  separate guard plugin" and that a hook attached to a skill cannot be scoped. Still true for hooks. It did
  not consider a tool-restricted forked agent, which this research shows can enforce the read step
  inside the plugin.
- A plausible assumption made while designing this, that `tools: Bash(<pattern>)` narrows an agent's
  shell to matching commands, is false (experiment 2). The documentation says the same for
  `disallowedTools`.
