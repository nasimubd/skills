# Platform APIs used, and how sure we are

All calls are reads. Record a real observation in the last column when a call is first run
live, with the date.

| Platform | Call | Used for | Status |
|---|---|---|---|
| Power Apps | `GET api.powerapps.com/.../apps?api-version=2016-11-01&$filter=environment eq '<env>'` (az token, resource `https://service.powerapps.com/`) | App inventory, `connectionReferences` (lists, flows) | Endpoint and token resource proven in production use (reference repo); the environment filter **observed 2026-10-28**: 4 apps returned. The list gives data source *titles* only (`connectionReferences.*.dataSources`), no list id or site |
| Power Apps | `GET .../apps/<id>/versions?api-version=2016-11-01`, the version with `isLive`, then `appDefinition.properties.appUris.documentUri.value` | Live app source and version | Proven (reference repo `release:pin`, 2026-10-26). **Observed 2026-10-28:** package entries use backslashes (`Src\App.pa.yaml`); `References\DataSources.json` maps each data source to `DatasetName` (site) and `TableName` (list id). **Observed 2026-10-28, later:** that `documentUri` is the link signed at publish time and expires seven days later (`se` in its query), so an app not republished within a week fails with HTTP 403 `AuthenticationFailed`. `GET .../apps/<id>?api-version=2016-11-01` returns the same blob signed afresh; download from there after checking the blob path equals the live version's (checked on all four apps in the environment) |
| Power Automate | `GET api.flow.microsoft.com/.../environments/<env>/flows/<id>?api-version=2016-11-01` (resource `https://service.flow.microsoft.com/`) | Definition, state, `lastModifiedTime` | Proven in production use |
| Power Automate | `.../flows?api-version=2016-11-01` and `&$filter=search('team')` | Owned and shared flow inventory | Owned list proven; with `search('team')`, **observed 2026-10-28**: 9 flows in total. Action steps carry `inputs.host.operationId` (`GetOnUpdatedItems`, `PatchItem`, …) |
| n8n | `GET <url>/api/v1/workflows?limit=250[&cursor=]`, `GET /api/v1/workflows/<id>` with `X-N8N-API-KEY` | Inventory, export, `activeVersionId` | Single-workflow read proven in production use; **list observed 2026-10-28**: 21 workflows, webhook node `parameters.path`, Execute Workflow `parameters.workflowId`, SharePoint node `parameters.list.value`. The Keychain value can come back hex-encoded from `security -w` (a pasted newline); `keychainSecret` decodes it |
| Make.com | `GET https://<zone>/api/v2/scenarios?teamId=`, `/scenarios/<id>`, `/scenarios/<id>/blueprint`, `/hooks?teamId=` with `Authorization: Token` | Inventory, blueprint, webhook URLs | From Make's public API reference; **not yet observed** in this tenant |
| Zapier | none | Zaps cannot be exported through a general public API | Zapier hooks are found by URL in flows/workflows and documented only |

## Discovery evidence model

A link is recorded only when a concrete value connects two artifacts. The evidence is the
artifact, the JSON path inside it, and the value:

- SharePoint list: `TableName` in the live package's `References/DataSources.json` for an app
  (older metadata: `tableName` under `connectionReferences…dataSets`), or a `dataset` + `table`
  pair in a flow step's `inputs.parameters`.
- Read or write: an app writes a list when its live `.pa.yaml` calls `Patch`, `Collect`,
  `Remove`, `RemoveIf` or `UpdateIf` on it, or binds a form to it (evidence: file and line);
  a flow step writes when its `operationId` is a write (`PostItem`, `PatchItem`, …). Discovery
  follows a list to the flows it triggers only when the list is written in the chain.
- App → flow: the flow's id (GUID) appears in the app's properties.
- Flow → flow: a `Workflow` action's `host.workflowReferenceName`.
- → n8n: a URL `<n8n url>/webhook[-test]/<path>` whose `<path>` equals a Webhook node's `path`.
- n8n → n8n: an Execute Workflow node's `workflowId`.
- → Make: a `hook.<zone>.make.com/<key>` URL matching a Make hook, and the scenario whose
  webhook module uses that hook.
- → Zapier: a `hooks.zapier.com/hooks/catch/…` URL (the key is masked in documents).
- n8n/Make → list: the list's GUID appears in the workflow or blueprint.
