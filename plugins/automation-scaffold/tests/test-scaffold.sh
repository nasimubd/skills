#!/usr/bin/env bash
# End-to-end offline test: discover → scaffold → export/pin → checks → publish dry run.
# Every platform call is served from fixtures (PLATFORM_FIXTURES); gh is a stub; nothing
# leaves the machine. Auto-discovered by test-marketplace-hook-regression-suite.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$PLUGIN_ROOT/bin/automation-scaffold"

WORK="$(mktemp -d)"
trap 'if [[ -n "${KEEP:-}" ]]; then echo "kept: $WORK" >&2; else rm -rf "$WORK"; fi' EXIT
export AUTOMATION_SCAFFOLD_CONFIG_DIR="$WORK/config"
export PLATFORM_FIXTURES="$WORK/fx"
mkdir -p "$AUTOMATION_SCAFFOLD_CONFIG_DIR" "$PLATFORM_FIXTURES" "$WORK/bin"

PASS=0
FAIL=0
ok() { PASS=$((PASS + 1)); }
bad() { FAIL=$((FAIL + 1)); echo "  ✗ $1"; }
assert_eq() { if [[ "$2" == "$3" ]]; then ok; else bad "$1: expected '$2', got '$3'"; fi; }
assert_has() { if grep -qF -- "$2" <<<"$3"; then ok; else bad "$1: '$2' not found"; fi; }
assert_lacks() { if grep -qF -- "$2" <<<"$3"; then bad "$1: '$2' should not appear"; else ok; fi; }
status_of() { local s=0; "$@" >/dev/null 2>&1 || s=$?; echo "$s"; }

ENV=Default-00000000-0000-0000-0000-000000000000
LIST=11111111-1111-1111-1111-111111111111
F1=aaaaaaaa-0000-0000-0000-000000000001
F2=bbbbbbbb-0000-0000-0000-000000000002
F3=cccccccc-0000-0000-0000-000000000003
APP=dddddddd-0000-0000-0000-000000000004
F4=99999999-0000-0000-0000-000000000007
F5=55555555-0000-0000-0000-000000000008
LIST2=22222222-2222-2222-2222-222222222222

# ---- setup ----
bash "$CLI" setup set workspaceDir "$WORK" >/dev/null
bash "$CLI" setup set author.name "Test Author" >/dev/null
bash "$CLI" setup set author.email test@example.com >/dev/null
bash "$CLI" setup set powerPlatform.environmentId "$ENV" >/dev/null
bash "$CLI" setup set powerPlatform.environmentName "Test Env" >/dev/null
bash "$CLI" setup set n8n.url https://n8n.example.com >/dev/null
bash "$CLI" setup set n8n.keychainItem example-n8n-key >/dev/null
assert_eq "setup refuses a secret-shaped value" "2" "$(status_of bash "$CLI" setup set n8n.keychainItem eyJhbGciOiJIUzI1NiJ9.payload.sig)"
assert_eq "setup refuses an unknown key" "2" "$(status_of bash "$CLI" setup set password hunter2)"
assert_eq "there is no GitHub owner setting (upstream is given or asked)" "2" "$(status_of bash "$CLI" setup set githubOwner someone)"
assert_eq "config holds the workspace folder" "$WORK" "$(jq -r .workspaceDir "$AUTOMATION_SCAFFOLD_CONFIG_DIR/config.json")"

# ---- fixtures ----
FX="$PLATFORM_FIXTURES"
cat >"$FX/apps.json" <<EOF
{"value": [
  {"name": "$APP", "properties": {"displayName": "Client Intake",
    "connectionReferences": {
      "sp": {"id": "/providers/microsoft.powerapps/apis/shared_sharepointonline", "dataSources": ["Client Intake List"]}}}},
  {"name": "ffffffff-0000-0000-0000-000000000006", "properties": {"displayName": "Sibling App",
    "connectionReferences": {"sp": {"id": "/providers/microsoft.powerapps/apis/shared_sharepointonline",
      "dataSets": {"https://contoso.sharepoint.com/sites/Ops": {"dataSources": {"Client Intake List": {"tableName": "$LIST"}}}}}}}},
  {"name": "eeeeeeee-0000-0000-0000-000000000005", "properties": {"displayName": "Unrelated App", "connectionReferences": {}}}
]}
EOF
cat >"$FX/flows.json" <<EOF
{"value": [{"name": "$F1"}, {"name": "$F2"}]}
EOF
cat >"$FX/flows-team.json" <<EOF
{"value": [{"name": "$F2"}, {"name": "$F3"}, {"name": "$F4"}, {"name": "$F5"}]}
EOF
cat >"$FX/flow-1.json" <<EOF
{"name": "$F1", "properties": {"displayName": "Submit Intake", "state": "Started", "lastModifiedTime": "2026-10-20T10:00:00Z",
  "connectionReferences": {"shared_sharepointonline": {"apiName": "sharepointonline"}},
  "definition": {"description": "changes on save", "triggers": {"manual": {"type": "Request", "kind": "PowerAppV2"}},
    "actions": {
      "Create_item": {"type": "OpenApiConnection", "inputs": {"host": {"apiId": "/providers/Microsoft.PowerApps/apis/shared_sharepointonline", "operationId": "PostItem"},
        "parameters": {"dataset": "https://contoso.sharepoint.com/sites/Ops", "table": "$LIST"}}},
      "Call_n8n": {"type": "Http", "inputs": {"method": "POST", "uri": "https://n8n.example.com/webhook/new-client",
        "headers": {"Authorization": "Bearer abcdefghijklmnopqrstuvwxyz0123456789", "X-Api-Key": "literal-secret-value-123"}}}}}}}
EOF
cat >"$FX/flow-2.json" <<EOF
{"name": "$F2", "properties": {"displayName": "Notify On New Item", "state": "Started", "lastModifiedTime": "2026-10-21T10:00:00Z",
  "definition": {"triggers": {"When_item_created": {"type": "OpenApiConnection", "recurrence": {"interval": 1, "frequency": "Minute"},
      "inputs": {"parameters": {"dataset": "https://contoso.sharepoint.com/sites/Ops", "table": "$LIST"}}}},
    "actions": {"Zap": {"type": "Http", "inputs": {"uri": "https://hooks.zapier.com/hooks/catch/123456/abcdef/"}}}}}}
EOF
cat >"$FX/flow-4.json" <<EOF
{"name": "$F4", "properties": {"displayName": "[OPT] Notify On New Item", "state": "Stopped", "lastModifiedTime": "2026-10-22T10:00:00Z",
  "definition": {"triggers": {"t": {"type": "OpenApiConnection", "inputs": {"parameters": {"dataset": "https://contoso.sharepoint.com/sites/Ops", "table": "$LIST"}}}}, "actions": {}}}}
EOF
cat >"$FX/flow-5.json" <<EOF
{"name": "$F5", "properties": {"displayName": "Lookup Sync", "state": "Started", "lastModifiedTime": "2026-10-22T10:00:00Z",
  "definition": {"triggers": {"t": {"type": "OpenApiConnection", "inputs": {"parameters": {"dataset": "https://contoso.sharepoint.com/sites/Ops", "table": "$LIST2"}}}}, "actions": {}}}}
EOF
cat >"$FX/flow-3.json" <<EOF
{"name": "$F3", "properties": {"displayName": "Unrelated Flow", "state": "Stopped", "lastModifiedTime": "2026-10-01T10:00:00Z",
  "definition": {"triggers": {"t": {"type": "OpenApiConnection", "inputs": {"parameters": {"dataset": "https://contoso.sharepoint.com/sites/Other", "table": "99999999-9999-9999-9999-999999999999"}}}}, "actions": {}}}}
EOF
WF1='{"id": "wf1", "name": "New Client Webhook", "active": true, "versionId": "v-draft", "activeVersionId": "v-live",
  "pinData": {"Webhook": [{"json": {"client": "Real Client Name"}}]}, "staticData": {"x": 1}, "settings": {"executionOrder": "v1"},
  "nodes": [
    {"name": "Webhook", "type": "n8n-nodes-base.webhook", "parameters": {"path": "new-client"}},
    {"name": "Set token", "type": "n8n-nodes-base.set", "parameters": {"assignments": {"assignments": [{"name": "apiToken", "value": "plain-secret-token-0123456789abcdef"}]}}},
    {"name": "Graph", "type": "n8n-nodes-base.httpRequest", "parameters": {"url": "=https://graph.microsoft.com/v1.0/sites/x/lists/'"$LIST"'/items?cache=plain-secret-token-0123456789abcdef"}}],
  "connections": {"Webhook": {"main": [[{"node": "Set token", "type": "main", "index": 0}]]}}}'
printf '{"data": [%s, {"id": "wf2", "name": "Unrelated Workflow", "nodes": [{"name": "Cron", "type": "n8n-nodes-base.scheduleTrigger", "parameters": {}}], "connections": {}}], "nextCursor": null}\n' "$WF1" >"$FX/n8n-list.json"
printf '%s\n' "$WF1" >"$FX/n8n-wf1.json"
cat >"$FX/versions.json" <<'EOF'
{"value": [
  {"name": "20261026T100000Z", "isLive": false, "properties": {"appDefinition": {"properties": {"appUris": {"documentUri": {"value": "https://blob.example/old.msapp?se=expired"}}}}}},
  {"name": "20261027T100000Z", "isLive": true, "properties": {"appDefinition": {"properties": {"lastPublishTime": "2026-10-27T10:00:00Z", "appUris": {"documentUri": {"value": "https://blob.example/app.msapp?se=expired"}}}}}}
]}
EOF
# The versions API's link was signed at publish time and expires after seven days; the app
# endpoint signs the same blob afresh. Only the fresh link has a fixture route.
printf '{"name": "%s", "properties": {"appUris": {"documentUri": {"value": "https://blob.example/app.msapp?se=fresh"}}}}\n' "$APP" >"$FX/app-one.json"
# As Power Apps writes packages: backslash entry names, lists and called flows in
# References\DataSources.json (the app list API carries data source titles only).
python3 -I - "$FX/app.msapp" "$LIST" "$F1" <<'PY'
import sys, json, zipfile
out, lst, flow = sys.argv[1:4]
ds = {"DataSources": [
    {"Name": "Client Intake List", "Type": "ConnectedDataSourceInfo",
     "ApiId": "/providers/microsoft.powerapps/apis/shared_sharepointonline",
     "DatasetName": "https://contoso.sharepoint.com/sites/Ops", "TableName": lst},
    {"Name": "SubmitIntake", "Type": "ServiceInfo",
     "ApiId": "/providers/microsoft.powerapps/apis/shared_logicflows", "WorkflowEntityId": flow},
    {"Name": "Lookup List", "Type": "ConnectedDataSourceInfo",
     "ApiId": "/providers/microsoft.powerapps/apis/shared_sharepointonline",
     "DatasetName": "https://contoso.sharepoint.com/sites/Ops", "TableName": "22222222-2222-2222-2222-222222222222"},
    {"Name": "ComboBoxSample", "Type": "StaticDataSourceInfo"}]}
with zipfile.ZipFile(out, "w") as z:
    z.writestr("Src\\App.pa.yaml", "App:\r\n  Properties:\r\n    Theme: =PowerAppsTheme\r\n")
    z.writestr("Src\\Screen1.pa.yaml", "Screens:\n  Screen1:\n    OnVisible: |-\n      =Patch(\n          'Client Intake List',\n          Defaults('Client Intake List'), {Title: \"x\"})\n    Items: ='Lookup List'\n")
    z.writestr("Src\\_EditorState.pa.yaml", "editor: state\n")
    z.writestr("References\\DataSources.json", json.dumps(ds))
    z.writestr("Header.json", "{}")
PY
cat >"$FX/routes.json" <<EOF
[
  {"match": "/apps?api-version", "file": "apps.json"},
  {"match": "/apps/$APP/versions", "file": "versions.json"},
  {"match": "/apps/$APP?api-version", "file": "app-one.json"},
  {"match": "blob.example/app.msapp?se=fresh", "file": "app.msapp"},
  {"match": "search('team')", "file": "flows-team.json"},
  {"match": "/flows/$F1?", "file": "flow-1.json"},
  {"match": "/flows/$F2?", "file": "flow-2.json"},
  {"match": "/flows/$F3?", "file": "flow-3.json"},
  {"match": "/flows/$F4?", "file": "flow-4.json"},
  {"match": "/flows/$F5?", "file": "flow-5.json"},
  {"match": "/flows?api-version", "file": "flows.json"},
  {"match": "/api/v1/workflows?limit", "file": "n8n-list.json"},
  {"match": "/api/v1/workflows/wf1", "file": "n8n-wf1.json"}
]
EOF

# ---- discover ----
DISC="$WORK/discovery.json"
err="$(bash "$CLI" discover --seed "client intake" --out "$DISC" 2>&1 >/dev/null)"
assert_has "discover reports what it examined" "Examined: 3 apps, 5 flows, 2 n8n workflows" "$err"
assert_has "only the three platforms are queried" "Platforms queried: power-apps, power-automate, n8n" "$err"
names="$(jq -r '.nodes[].name' "$DISC" | LC_ALL=C sort | tr '\n' '|')"
assert_eq "exactly the related artifacts" "Client Intake|Client Intake List|Lookup List|New Client Webhook|Notify On New Item|Submit Intake|https://hooks.zapier.com/hooks/catch/123456/…/|" "$names"
assert_lacks "a sibling app sharing the list is not pulled in" "Sibling App" "$names"
assert_lacks "[OPT] copies are left out by default" "[OPT]" "$names"
assert_eq "a sibling writer of a list in scope is reported, not followed" "Sibling App uses-list" "$(jq -r '.notFollowed[] | "\(.name) \(.links[0].relation)"' "$DISC")"
assert_has "--include-copies brings copies in" "[OPT] Notify On New Item" "$(bash "$CLI" discover --seed "client intake" --include-copies 2>/dev/null | jq -r '.nodes[].name')"
ex="$(bash "$CLI" discover --seed "client intake" --exclude "Notify On New Item" 2>/dev/null | jq -r '.nodes[].name')"
assert_lacks "--exclude drops the artifact" "Notify On New Item" "$ex"
assert_lacks "--exclude drops what only it leads to" "zapier" "$ex"
assert_eq "list-triggered flow is linked as triggered-by" "1" "$(jq '[.edges[] | select(.relation=="triggered-by")] | length' "$DISC")"
assert_has "list evidence comes from the live package" "References/DataSources.json" "$(jq -r '.edges[] | select(.relation=="writes-list" and (.from|startswith("app:"))) | .evidence[0].artifact' "$DISC")"
assert_lacks "unrelated flow excluded" "Unrelated Flow" "$names"
assert_lacks "unrelated workflow excluded" "Unrelated Workflow" "$names"
rel() { jq -r --arg r "$1" '[.edges[] | select(.relation == $r)] | length' "$DISC"; }
assert_eq "app writes the list (Patch across a line break)" "Src/Screen1.pa.yaml:4 Patch('Client Intake List'" "$(jq -r '.edges[] | select(.relation=="writes-list" and (.from|startswith("app:"))) | .evidence[0].write' "$DISC")"
assert_eq "app only reads the lookup list" "1" "$(jq '[.edges[] | select(.relation=="reads-list" and (.from|startswith("app:")))] | length' "$DISC")"
assert_lacks "a flow triggered by a read-only list stays out" "Lookup Sync" "$names"
assert_eq "flow write classified by operationId" "PostItem" "$(jq -r '.edges[] | select(.relation=="writes-list" and (.from|startswith("flow:"))) | .evidence[0].operationId' "$DISC")"
assert_eq "app calls the flow (id in app)" "1" "$(rel calls-flow)"
assert_eq "flow calls the n8n webhook" "1" "$(rel calls-webhook)"
assert_eq "zapier hook recorded" "1" "$(rel calls-zapier)"
assert_eq "n8n workflow touches the list" "1" "$(rel touches-list)"
assert_eq "webhook evidence names the node path" "n8n:wf1 \$.nodes[0].parameters.path" "$(jq -r '.edges[] | select(.relation=="calls-webhook") | .evidence[0].target' "$DISC")"
assert_lacks "zapier hook key is masked" "abcdef" "$(jq -r '.nodes[].name' "$DISC")"
assert_eq "depth 0 keeps only the seed" "1" "$(bash "$CLI" discover --seed "$APP" --depth 0 2>/dev/null | jq '.nodes | length')"
assert_eq "unknown seed fails" "1" "$(status_of bash "$CLI" discover --seed "does not exist")"

# ---- app package: refuse a fresh link that is not the live version's blob ----
MIS="$WORK/fx-mismatch"; cp -R "$FX" "$MIS"
printf '{"properties": {"appUris": {"documentUri": {"value": "https://blob.example/other.msapp?se=fresh"}}}}\n' >"$MIS/app-one.json"
MSG=$(PLATFORM_FIXTURES="$MIS" node -e 'require(process.argv[1]).liveApp(process.argv[2]).then(() => console.log("downloaded"), (e) => console.log(e.message))' \
  "$PLUGIN_ROOT/template/scripts/lib/platform.js" "$APP" 2>&1)
[[ "$MSG" == *"is not the live version 20261027T100000Z"* ]] && ok || bad "a package that is not the live version is refused: $MSG"

# ---- component ids: the scope of a commit header capped at 72 characters ----
slug() { node -e 'console.log(require(process.argv[1]).componentSlug(process.argv[2], process.argv[3]))' "$PLUGIN_ROOT/scripts/scaffold.js" "$1" "$2"; }
assert_eq "the project name is not repeated in a component id" "asana-event-sync" "$(slug 'Matter Status – Asana Event Sync' matter-status)"
assert_eq "an artifact named like the project keeps its name" "matter-status" "$(slug 'Matter Status' matter-status)"
long="$(slug 'A Really Long Workflow Name That Keeps Going On And On Forever' x)"
(( ${#long} <= 36 )) && [[ "$long" != *- ]] && ok || bad "a long name is cut on a word boundary to 36 characters: $long"

# ---- scaffold ----
REPO="$WORK/repo"
bash "$CLI" scaffold --dir "$REPO" --name client-intake --title "Client Intake" --discovery "$DISC" >"$WORK/summary.json" 2>"$WORK/scaffold.err" \
  || { cat "$WORK/scaffold.err"; bad "scaffold failed"; }
assert_eq "four components registered" "app-client-intake flow-notify-on-new-item flow-submit-intake n8n-new-client-webhook" \
  "$(jq -r '[.components[].id] | sort | join(" ")' "$REPO/releases/components.json")"
assert_eq "every component exported and pinned" "4" "$(jq '[.exports[] | select(.ok)] | length' "$WORK/summary.json")"
assert_eq "app source holds the pa.yaml files, not editor state" "App.pa.yaml Screen1.pa.yaml" "$(ls "$REPO/src/CanvasApps/Client-Intake/src/Src" | tr '\n' ' ' | sed 's/ $//')"
assert_eq "app source has LF line endings" "0" "$(grep -c $'\r' "$REPO/src/CanvasApps/Client-Intake/src/Src/App.pa.yaml" || true)"
assert_eq "app pinned to the live version" "20261027T100000Z" "$(jq -r .live.version "$REPO/src/CanvasApps/Client-Intake/release.lock.json")"
flowdef="$(cat "$REPO/src/Flows/submit-intake/definition.json")"
assert_lacks "bearer token redacted in flow" "abcdefghijklmnopqrstuvwxyz" "$flowdef"
assert_lacks "literal API key redacted in flow" "literal-secret-value-123" "$flowdef"
wf="$(cat "$REPO/workflows/new-client-webhook/workflow.json")"
assert_lacks "pinData stripped" "Real Client Name" "$wf"
assert_lacks "n8n literal secret redacted, including where it is reused in another node" "plain-secret-token" "$wf"
assert_has "n8n export records the published version" '"exportedVersionId": "v-live"' "$wf"
assert_eq "no unfilled placeholders" "" "$(grep -rhoE '\{\{[A-Z_]+\}\}' "$REPO" --include='*.md' --include='*.json' --include='*.toml' || true)"
assert_has "CLAUDE.md carries the no-AI-attribution rule" "No AI attribution, anywhere" "$(cat "$REPO/CLAUDE.md")"
assert_has "git rules carry the rebase-and-merge protocol" "rebase and merge" "$(cat "$REPO/.claude/rules/git.md")"
assert_has "architecture cites evidence paths" '$.nodes[0].parameters.path' "$(cat "$REPO/docs/architecture.md")"
assert_has "README lists the components" '`flow-submit-intake`' "$(cat "$REPO/README.md")"
assert_eq "project.json holds no secret" "0" "$(grep -ciE 'token|password|secret' "$REPO/project.json" || true)"

# The scaffolded repository's own checks, run from inside it.
(cd "$REPO" && node scripts/check-components.js >/dev/null) && ok || bad "components:check fails on the scaffold"
for id in app-client-intake flow-submit-intake flow-notify-on-new-item n8n-new-client-webhook; do
  assert_eq "release gate: $id source matches its pin" "0" "$(cd "$REPO" && status_of node scripts/release-pin.js check "$id")"
done
assert_eq "pins match production" "0" "$(cd "$REPO" && status_of node scripts/release-pin.js verify)"
node -e "require('$REPO/commitlint.config.cjs')" 2>/dev/null && ok || bad "commitlint config does not load"
attr() { printf '%s' "$1" | node "$REPO/scripts/no-ai-attribution.js" >/dev/null 2>&1 && echo pass || echo reject; }
assert_eq "plain commit passes" "pass" "$(attr $'feat(app-client-intake): add intake\n\nWhy it changed.')"
assert_eq "Claude co-author rejected" "reject" "$(attr $'fix: x\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>')"
assert_eq "Generated-with line rejected" "reject" "$(attr $'🤖 Generated with [Claude Code](https://claude.com/claude-code)')"

# Editing the source after the pin must close the release gate.
echo "  Changed: true" >>"$REPO/src/CanvasApps/Client-Intake/src/Src/Screen1.pa.yaml"
assert_eq "edited source fails the release gate" "1" "$(cd "$REPO" && status_of node scripts/release-pin.js check app-client-intake)"

# Re-running keeps existing files.
bash "$CLI" scaffold --dir "$REPO" --name client-intake --discovery "$DISC" --no-export >"$WORK/again.json" 2>/dev/null
assert_has "re-run keeps CLAUDE.md" '"CLAUDE.md"' "$(jq -c .kept "$WORK/again.json")"
assert_eq "re-run does not duplicate components" "4" "$(jq '.components | length' "$REPO/releases/components.json")"

# ---- publish (dry run: nothing changes) ----
printf '#!/usr/bin/env bash\n[[ "$1 $2" == "repo view" ]] && exit 1\necho "gh $*" >>"%s/gh.log"\n' "$WORK" >"$WORK/bin/gh"
chmod +x "$WORK/bin/gh"
out="$(PATH="$WORK/bin:$PATH" bash "$CLI" publish repo --repo example-owner/client-intake --dir "$WORK/new" 2>&1)"
assert_has "new repo would be created private" "would run: gh repo create example-owner/client-intake --private" "$out"
assert_eq "dry run creates nothing" "no" "$([[ -e "$WORK/new" || -e "$WORK/gh.log" ]] && echo yes || echo no)"
out="$(bash "$CLI" publish pr --dir "$REPO" 2>&1)"
assert_has "PR title is a conventional header" "PR title: chore(repo): scaffold client-intake with release convention" "$out"
assert_has "PR is rebase-merged" "gh pr merge --rebase --delete-branch" "$out"
assert_lacks "PR body carries no AI attribution" "Generated with" "$out"
assert_eq "release refuses without --yes and changes nothing" "0" "$(status_of bash "$CLI" publish release --dir "$REPO")"
assert_eq "publish without config author is refused" "3" "$(AUTOMATION_SCAFFOLD_CONFIG_DIR="$WORK/none" status_of bash "$CLI" publish pr --dir "$REPO")"

# ---- the repository's About: description and topics from project.json ----
assert_eq "description says what the repository holds" \
  "Client Intake: 1 Power Apps canvas app, 2 Power Automate flows and 1 n8n workflow, exported from production and released per component." \
  "$(jq -r .github.description "$REPO/project.json")"
assert_eq "topics follow the component kinds" "power-platform power-apps power-automate n8n automation semantic-release conventional-commits" \
  "$(jq -r '.github.topics | join(" ")' "$REPO/project.json")"
assert_has "the README carries the same description" "$(jq -r .github.description "$REPO/project.json")" "$(cat "$REPO/README.md")"
# gh stub: GH_DESC and GH_TOPICS are what GitHub currently shows; edits are logged.
cat >"$WORK/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$*" in
  *nameWithOwner*) echo example-owner/client-intake ;;
  *"--json description,repositoryTopics"*) jq -n --arg d "\$GH_DESC" --arg t "\$GH_TOPICS" '{description: \$d, repositoryTopics: [\$t | splits(" ") | select(. != "") | {name: .}]}' ;;
  *"--json description"*) echo "\$GH_DESC" ;;
  *repositoryTopics*) echo "\$GH_TOPICS" ;;
  "repo edit"*) echo "gh \$*" >>"$WORK/gh-edit.log" ;;
esac
EOF
chmod +x "$WORK/bin/gh"
about() { PATH="$WORK/bin:$PATH" GH_DESC="$1" GH_TOPICS="$2" bash "$CLI" publish about --dir "$REPO" "${@:3}" 2>&1; }
out="$(about "" "n8n")"
assert_has "an empty description would be set" "--description Client Intake: 1 Power Apps canvas app" "$out"
assert_has "only missing topics are added" "--add-topic power-platform --add-topic power-apps --add-topic power-automate --add-topic automation" "$out"
assert_lacks "a topic already present is not re-added" "--add-topic n8n" "$out"
assert_eq "about without --yes edits nothing" "no" "$([[ -e "$WORK/gh-edit.log" ]] && echo yes || echo no)"
out="$(about "Written by hand" "" --yes)"
assert_has "an existing description is kept and reported" "description kept (already set on GitHub): Written by hand" "$out"
assert_lacks "an existing description is not overwritten" "--description" "$(cat "$WORK/gh-edit.log")"
assert_has "with --yes the topics are applied" "gh repo edit example-owner/client-intake --add-topic power-platform" "$(cat "$WORK/gh-edit.log")"
all="power-platform power-apps power-automate n8n automation semantic-release conventional-commits"
assert_has "nothing to do when the About is complete" "already up to date" "$(about "Written by hand" "$all" --yes)"
verify() { about "$1" "$2" --check >/dev/null && echo pass || echo fail; }
assert_eq "verification passes with a description and every topic" "pass" "$(verify "x" "$all")"
assert_eq "verification fails on an empty description" "fail" "$(verify "" "$all")"
assert_eq "verification fails on a missing topic" "fail" "$(verify "x" "n8n")"

# ---- the real order: publish repo --yes, then scaffold into the clone ----
# gh is a stub: the repo does not exist, "create" is a no-op and "clone" clones a local bare
# remote, so the initial commit and push are real git operations on this machine only.
mkdir -p "$WORK/remotes/example-owner" && git init -q --bare "$WORK/remotes/example-owner/real-order.git"
cat >"$WORK/bin/gh" <<EOF
#!/usr/bin/env bash
case "\$1 \$2" in
  "repo view") git -C "$WORK/remotes/example-owner/real-order.git" rev-parse -q --verify main >/dev/null ;;
  "repo create") exit 0 ;;
  "repo clone") git clone -q "$WORK/remotes/example-owner/real-order.git" "\$4" 2>/dev/null ;;
esac
EOF
chmod +x "$WORK/bin/gh"
CLONE="$WORK/workspace/real-order"
# A caller's GIT_AUTHOR_*/GIT_COMMITTER_* (semantic-release exports them) must not replace the author.
GIT_AUTHOR_NAME=other-bot GIT_AUTHOR_EMAIL=bot@example.com GIT_COMMITTER_NAME=other-bot GIT_COMMITTER_EMAIL=bot@example.com \
  PATH="$WORK/bin:$PATH" bash "$CLI" publish repo --repo example-owner/real-order --dir "$CLONE" --yes >/dev/null
assert_eq "initial commit is empty and conventional" "chore(repo): initialize repository|0" \
  "$(git -C "$CLONE" log -1 --format=%s)|$(git -C "$CLONE" ls-tree -r HEAD | wc -l | tr -d ' ')"
assert_eq "initial commit was pushed to main" "$(git -C "$CLONE" rev-parse HEAD)" "$(git -C "$WORK/remotes/example-owner/real-order.git" rev-parse main)"
assert_eq "initial commit is authored and committed by the configured author" "Test Author <test@example.com>|Test Author <test@example.com>" \
  "$(git -C "$CLONE" log -1 --format='%an <%ae>|%cn <%ce>')"
bash "$CLI" scaffold --dir "$CLONE" --name real-order --discovery "$DISC" --no-export >/dev/null 2>&1
assert_has "the real README is written, not a stub" "## Components" "$(cat "$CLONE/README.md")"
assert_eq "nothing was kept in a fresh clone" "[]" "$(bash "$CLI" scaffold --dir "$WORK/workspace/fresh" --name fresh --no-export 2>/dev/null | jq -c .kept)"
PATH="$WORK/bin:$PATH" bash "$CLI" publish repo --repo example-owner/real-order --dir "$CLONE" --yes >/dev/null 2>&1 \
  && ok || bad "an existing clone of the same repo is accepted"

echo "test-scaffold.sh: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
