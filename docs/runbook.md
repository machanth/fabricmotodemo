# Deployment and evidence runbook

## 1. Required access and values

The operator needs Workspace Contributor (or higher for deployment), permission to use the assigned F2+/P1+ capacity, permission to use the external cloud connection, and tenant admin help for Copilot/Purview settings. Populate `.env` with:

- `FABRIC_WORKSPACE_ID` and `FABRIC_CAPACITY_ID`
- `SHORTCUT_SOURCE_TYPE`: exactly `AdlsGen2` or `AmazonS3`
- `SHORTCUT_CONNECTION_ID`, `SHORTCUT_LOCATION`, and `SHORTCUT_SUBPATH`
- an authenticated Azure CLI identity (`az login`) authorized for Fabric and OneLake

Credentials are never required in source control. `AZURE_CLIENT_SECRET` is intentionally blank in `.env.example`; interactive Azure CLI authentication is preferred for the POC.

Prepare the external domain by uploading only the three files under `sample-data\object-storage` to the configured ADLS/S3 path. Create a Fabric cloud connection for that location and grant the deployment/operator identity permission to use it. The other three CSVs are uploaded to OneLake by the official Azure Storage SDK.

## 2. Automated deployment

```powershell
Copy-Item .env.example .env
# Edit .env without committing it.
python -m pip install -r requirements-deploy.txt
az login
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\preflight.ps1 -RequireDeploymentTools
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy.ps1
```

`deploy.ps1` performs the supported automation:

1. Deploys lakehouse and notebook metadata with Microsoft `fabric-cicd`.
2. Resolves the destination item IDs.
3. Uses the official Azure Storage SDK to place warehouse-domain CSVs in `Files/landing/warehouse`.
4. Creates/updates `Files/landing/customer-domain/external-customers` with the official shortcut REST API.
5. Submits the notebook, which overwrites only this POC's named Bronze/Silver/Gold Delta tables after referential-integrity checks.
6. Records created item IDs in ignored `.fabric-deploy-state.json`.

The scripts refuse to overwrite a matching item/shortcut not already owned by this state file. State is atomically checkpointed after each creation, including partial `fabric-cicd` failures, so `teardown.ps1` remains safe and resumable.

Check the notebook job in **Workspace → Monitor**. After it succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy-model-report.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify-deployment.ps1
```

The second script discovers the target lakehouse SQL analytics endpoint, stages a generated copy under ignored `dist`, replaces only endpoint and DataAgent source IDs, then deploys model, report, and the DataAgent draft. Lakehouse ALM does not deploy tables or Files, which is why this ordering is required.

## 3. Manual/tenant-dependent controls

### Power BI project previews

In Power BI Desktop, go to **File → Options and settings → Options → Preview features** and enable **Power BI Project (.pbip) save option**, **Store semantic model using TMDL format**, and **Store reports using enhanced metadata format (PBIR)** before editing committed definitions. These formats remain preview at the validation date.

### RLS role membership and persona validation

RLS role definitions deploy in TMDL; members do not.

1. In the workspace, select **Motorola Sales Certified → … → Security**.
2. Add the approved North America security group/user to **North America** and Europe group/user to **Europe**.
3. Ensure consumers are Workspace Viewers or app recipients. Admins, Members, and Contributors bypass model RLS.
4. Select **Test as role** and run the identical first prompt from `ai/test-cases.json`.
5. Capture the North America result `$6,737,571.05 / $1,477,389.30 / 300` and Europe result `$12,893,250.00 / $2,987,650.25 / 600`.

### Fabric data agent

Data-agent creation is GA; configuration management and publish APIs are preview. The official `fabric/Motorola Sales Agent.DataAgent/Files/Config` definition is source-controlled and its draft is deployed by `fabric-cicd`. `ai/data-agent-config.json`, `ai/instructions.md`, and `ai/test-cases.json` are the readable contract and acceptance suite. Publishing remains manual:

1. Open the deployed **Motorola Sales Agent** draft.
2. Verify **Motorola Sales Certified** is its only source, the selected business elements match the committed definition, and hidden bridge/technical fields are excluded.
3. Compare **Data agent instructions** with `ai/instructions.md`.
4. Run the four prompts in `ai/test-cases.json`; semantic-model sources do not support UI few-shot examples, so these are acceptance tests rather than a fabricated `fewshots.json`.
5. Test each prompt while impersonating the correct RLS user; inspect generated DAX/queries and retain screenshots.
6. Publish through the UI. Use the preview [publish API](https://learn.microsoft.com/en-us/rest/api/fabric/dataagent/items/publish-data-agent) only if the tenant has explicitly accepted preview automation.

### Standalone Copilot and approved model

1. Fabric admin portal → **Tenant settings → Copilot and AI**.
2. Enable **Users can use Copilot and other features powered by Azure OpenAI** for an approved security group.
3. Enable applicable cross-region processing/storage and OpenAI subprocessor settings for the tenant's geography.
4. Explicitly enable **Users can access a standalone, cross-item Copilot in Power BI experience (preview)**; optionally restrict it to approved items.
5. If delegated settings are used, repeat under **Capacity settings → target capacity → Delegated tenant settings**.
6. Assign this workspace to F2+/P1+ or assign test users to a Fabric Copilot capacity.
7. Open model **Prep data for AI** (preview), constrain the AI schema to the approved business fields, apply `ai/instructions.md`, add verified answers from the test cases, and select **Apply**.
8. Model **Settings → Approved for Copilot → Apply**, then perform the documented service refresh.
9. In standalone Copilot, select the approved model and rerun the persona tests.

### Power BI mobile

1. Publish/share **Motorola Sales Overview** or include it in a Power BI app.
2. Open the report in supported Power BI authoring, switch to **Mobile layout**, arrange the two cards above the chart/table, and publish. External editing of legacy `mobileState.json` is unsupported, so it is not fabricated here.
3. Install the official Power BI app on iOS/Android, sign in as each RLS persona, open the report/app, and capture the same scoped KPIs.
4. If managed devices are required, Intune admin center → add the iOS/Android store app → assign users/devices → create and assign the required app-protection policy.

## 4. Governance and lineage

### Fabric lineage and OneLake Catalog

Open **Workspace → Lineage view** and capture the deployed chain. Expected Fabric-native item lineage is shortcut/notebook/lakehouse → semantic model → report. Fabric shows one upstream level outside a workspace and does not promise external ADLS/S3 object- or field-level lineage. Use `docs/field-traceability.csv` for auditable field mapping.

For each production item, open **Settings → Endorsement**:

- promote **MedallionLakehouse**
- certify **Motorola Sales Certified**
- promote or certify **Motorola Sales Overview** according to tenant policy

Select **Apply**, then verify the badges in OneLake Catalog. Certification/Master data requires the tenant's configured reviewer group. No documented public source/API representation exists for endorsement, so this is evidence-backed manual configuration.

### Purview

1. Fabric admin enables metadata scanning, **Allow service principals to use read-only admin APIs**, detailed metadata responses, and applicable OneLake external-app access.
2. Put the Purview managed identity/service principal in the allowed Entra security group.
3. Purview → **Data Map → Register → Fabric**, configure credentials, then create and run a full scan followed by scheduled incremental scans.
4. Register and scan the ADLS source separately if ADLS metadata is required. Register the applicable supported source for S3 according to Purview coverage.
5. Capture both assets and item-level lineage. Explicitly label the external-object-to-shortcut connection as traceability evidence, not automatically stitched Purview subitem lineage; Microsoft does not support that end-to-end stitching.

## 5. Capacity Metrics load demonstration

Capacity admin installs **Microsoft Fabric Capacity Metrics** from **Apps → Get apps**, connects with OAuth2 and Organizational privacy, and selects the target capacity. Record the capacity ID/SKU and UTC offset.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\run-capacity-demo.ps1 -Iterations 3 -DelaySeconds 30
```

The script creates a unique POC run ID, submits three `RunNotebook` operations, and writes `dist\capacity-demo-<run-id>.csv` with UTC timestamps and item IDs. Wait at least 15 minutes (the documented data lag is normally 10–15 minutes), then:

1. Open Capacity Metrics → **Compute**.
2. Use the same 14-day/date window and filter to the recorded workspace/item.
3. Drill from item to operation and the matching 30-second timepoints.
4. Capture CU seconds, billing type, operation IDs, timestamps, and screenshot/export.
5. Keep the CSV beside the evidence. Export can be sampled, and Microsoft's supplied metrics semantic model is not supported as a custom telemetry API.

## 6. Evidence checklist

| Evidence | Pass condition |
|---|---|
| Data safety | Generator seed recorded; only synthetic organizations/products/transactions; no secrets in Git |
| Source domains | Three warehouse-style files and three external shortcut files visible |
| Delta path | Six Bronze, six Silver, and six Gold tables/query outputs present; notebook job succeeded |
| Complex model | Six relationships, true customer-segment bridge, two date roles, three measures, hidden keys |
| Thin report | Cards/chart/table render without report-level joins |
| RLS | Same prompt yields the two exact scoped expected results; users are not elevated workspace roles |
| Ask the data | Agent and standalone Copilot use approved model, synthetic PCR warning, and four passing prompts |
| Mobile | iOS/Android capture shows scoped KPI cards |
| Native lineage | Workspace lineage screenshot shows shortcut/notebook/lakehouse → model → report |
| Catalog | Endorsement badges visible in OneLake Catalog |
| Purview | Fabric scan plus external-source scan captured; unsupported stitching disclaimer retained |
| Capacity | POC run CSV correlates to item/operation CU seconds after ingestion delay |
| Teardown | `teardown.ps1 -WhatIf` lists only IDs recorded in POC state |

## 7. Safe teardown

First inspect:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\teardown.ps1 -WhatIf
```

Then run without `-WhatIf` and confirm. The script refuses name inference, validates each recorded item before deletion, and preserves the workspace, capacity, cloud connection, external storage, and any resource not in the POC state file.
