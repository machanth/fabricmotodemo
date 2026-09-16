# Demo video recording runbook

This script produces a 12-15 minute evidence-based demo of the deployed Motorola-style
Microsoft Fabric POC. All organizations, products, transactions, and **PCR ("Priority
Communications Revenue")** terminology are synthetic.

## 1. Prepare before recording

Use a Fabric admin or domain admin for the governance segment and a workspace
Contributor/Admin for the engineering segment. Use separate Viewer test accounts for
RLS. Do not record credentials, tenant IDs, browser developer tools, connection
credentials, or the local `.env` file.

Complete these checks:

1. Open workspace **MaddysWS** and confirm these items are present:
   - `MedallionLakehouse`
   - `TransformMedallion`
   - `Motorola Sales Certified`
   - `Motorola Sales Overview`
   - `Motorola Sales Agent`
2. In **Monitor**, confirm notebook job
   `a9650a5d-c8b1-476b-8cdf-2b73e68c80eb` is **Completed**.
3. In semantic model refresh history, confirm Direct Lake framing request
   `ca57251d-84de-42f5-b41a-b5baf6cf7ee5` is **Completed**.
4. Open the report once and verify all visuals render.
5. Assign the North America and Europe Viewer accounts to their corresponding RLS
   roles. Do not use workspace Admin, Member, or Contributor accounts for RLS evidence.
6. Publish the DataAgent draft and test its prompts before recording.
7. Close unrelated browser tabs and disable desktop/chat notifications.
8. Set browser zoom to 90-100%, use a 1920x1080 canvas, and keep the cursor still
   while explaining.

If tenant governance configuration has not been completed, record sections 2-6 first,
pause recording, complete section 7, and then record the governance chapter.

## 2. Opening and business problem (0:00-0:45)

**Show:** The `Motorola Sales Overview` report title page or the workspace item list.

**Say:**

> This is a synthetic Microsoft Fabric proof of concept for complex sales analytics,
> governed self-service reporting, and conversational data access. It combines a
> warehouse-style order domain with an ADLS customer domain without exposing
> proprietary data. Business users consume a certified semantic layer and never create
> joins themselves.

Add a small on-screen caption: **Synthetic POC data - not Motorola production data**.

## 3. Architecture and source domains (0:45-2:00)

**Show:** The Mermaid architecture in `README.md`, then the lakehouse explorer.

**Actions:**

1. Expand **Files → landing → warehouse** and show `orders.csv`, `order_lines.csv`,
   and `products.csv`.
2. Expand **Files → landing → customer-domain → external-customers** and show
   `customers.csv`, `segments.csv`, and `customer_segment_assignments.csv`.
3. Open shortcut details and show that the customer files are referenced through the
   external ADLS shortcut rather than copied manually into the landing folder.

**Say:**

> The first source domain simulates warehouse orders, order lines, and products. The
> second simulates customer, segment, and many-to-many assignment data in ADLS Gen2.
> The OneLake shortcut gives Fabric a governed reference to that external location.

Do not open the connection credential page during recording.

## 4. Medallion transformation and data quality (2:00-3:15)

**Show:** `TransformMedallion`, then **Monitor**.

**Actions:**

1. Briefly show the typed CSV schemas and fail-fast duplicate/orphan checks.
2. Show the successful notebook run.
3. Return to the lakehouse and expand the Bronze, Silver, and Gold tables.
4. Open `goldfactsales` and `golddimsegment` previews.

**Say:**

> The notebook validates keys and referential integrity before writing Delta. Six
> Bronze tables preserve ingestion, six Silver tables standardize business data, and
> six Gold tables provide the star schema. The customer-segment assignment remains a
> genuine bridge instead of flattening away the many-to-many relationship.

## 5. Certified semantic layer and thin report (3:15-5:30)

**Show:** The semantic model relationship diagram, then the report.

**Actions:**

1. Point out `Fact Sales`, `Customer`, `Product`, `Segment`, and the customer-segment
   bridge.
2. Show **Order Date** and **Ship Date** as role-playing dimensions.
3. Show business-friendly fields and the hidden technical keys.
4. Show measures **Net Revenue**, **PCR Revenue**, and **Order Count**.
5. Open the report and interact with a product/segment/date filter.

**Say:**

> Direct Lake reads the Gold Delta tables without importing a second copy. The model
> owns every relationship, including bidirectional propagation through the bridge and
> two roles for the date dimension. The thin report contains presentation only, so
> users drag and drop approved fields without recreating joins.

Show the refresh history entry for request
`ca57251d-84de-42f5-b41a-b5baf6cf7ee5` and call out **DirectLakeFraming -
Completed**.

## 6. RLS and ask-the-data experience (5:30-7:45)

### RLS

**Actions:**

1. Open semantic model **Security** and show the North America and Europe role names.
   Avoid exposing personal email addresses; use demo security groups if possible.
2. Use **Test as role** or sign in with each Viewer persona.
3. Ask the same question for both personas:

   > What are net revenue, PCR revenue, and order count?

4. Capture the expected scoped answers:

| Persona | Net revenue | PCR revenue | Order count |
|---|---:|---:|---:|
| North America | $6,737,571.05 | $1,477,389.30 | 300 |
| Europe | $12,893,250.00 | $2,987,650.25 | 600 |

**Say:**

> The question is identical. The effective identity changes, and semantic-model RLS
> applies the regional filter. Elevated workspace roles bypass RLS, which is why these
> tests use Viewer identities.

### Fabric data agent and Copilot

**Actions:**

1. Open `Motorola Sales Agent`.
2. Show `Motorola Sales Certified` as its approved source.
3. Show the instruction defining PCR.
4. Ask: **What does PCR mean, and what is PCR revenue for my region?**
5. Show generated reasoning/query details if the tenant UI exposes them.

**Say:**

> PCR means Priority Communications Revenue, a synthetic term created only for this
> POC. The agent is grounded in the approved model rather than raw landing data, so it
> inherits business definitions, relationships, and security.

If standalone Copilot is enabled, repeat the prompt there and show the approved-model
badge. Otherwise state on-screen that standalone Copilot requires the tenant setting
and approved-for-Copilot configuration; do not imply it is active.

## 7. Governance with Fabric domains (7:45-10:15)

### Recommended domain structure

Use this POC hierarchy:

- **Domain:** `Commercial Analytics`
- **Subdomain:** `Sales Intelligence`
- **Workspace assignment:** `MaddysWS` → `Sales Intelligence`
- **Domain admins:** business data owner plus a governance backup group
- **Domain contributors:** approved workspace-admin group

Fabric domains classify **workspaces**, and every item in an assigned workspace inherits
that domain metadata. They don't classify individual tables independently and don't
grant access. Keep the warehouse and customer systems as source-domain concepts in this
single-workspace POC. To demonstrate separate Fabric business domains, first place their
items in separate workspaces.

### Configure before or during the recording

As Fabric admin:

1. Open **Settings → Admin portal → Domains**.
2. Select **Create new domain**.
3. Enter `Commercial Analytics`, add the approved domain-admin group, and select
   **Create**.
4. Open the domain and select **New subdomain**.
5. Enter `Sales Intelligence` and select **Create**.
6. Open the subdomain and select **Assign workspaces**.
7. Choose **Assign by workspace name**, select `MaddysWS`, and confirm.
8. In domain settings, add a clear description:

   > Governed commercial sales, customer segmentation, and revenue analytics. POC
   > content is synthetic and must not be treated as production Motorola data.

9. Optionally set a domain image and add the approved workspace-admin group as domain
   contributors.

**Record:** The domain hierarchy, assigned workspace, and domain metadata on an item.

**Say:**

> Domains provide federated organization and governance. The workspace assignment makes
> every POC item discoverable under Sales Intelligence, while access still comes from
> workspace roles and item permissions. Domain admins can also manage delegated tenant
> settings where the Fabric admin has allowed delegation.

Do not select **Assign by capacity** for this shared POC capacity: it could reclassify
unrelated workspaces.

## 8. OneLake Catalog, endorsement, security, and lineage (10:15-12:15)

### Catalog and endorsement

**Actions:**

1. Open **OneLake catalog → Explore**.
2. Filter **Domain → Commercial Analytics → Sales Intelligence**.
3. Search for `Motorola Sales Certified`.
4. Open its in-context details and show description, owner, endorsement, and lineage.
5. Show these intended badges:
   - `MedallionLakehouse`: **Promoted**
   - `Motorola Sales Certified`: **Certified**
   - `Motorola Sales Overview`: **Promoted** or **Certified**, per policy
6. Open **Govern** and show recommended governance actions.
7. Open **Secure** and show the centralized workspace/OneLake security posture without
   exposing personal identities.

**Say:**

> The domain filter makes governed assets easier to discover. Promotion indicates
> owner readiness; certification requires an authorized reviewer and signals that the
> semantic model meets organizational standards. Domain assignment itself does not
> provide access.

If certification is not enabled, show **Request certification** and say that a Fabric
admin must enable certification and configure reviewer groups. Do not claim the item is
certified until the badge is visible.

### Native lineage

**Actions:**

1. Open **MaddysWS → Lineage view**.
2. Select the semantic model card and choose its lineage highlight control.
3. Show the chain from lakehouse/notebook through semantic model to report.
4. Open item **Impact analysis** if downstream impact is useful.

**Say:**

> Workspace lineage explains dependencies and change impact. Fabric displays upstream
> sources outside the workspace only one level up. The ADLS object-to-shortcut
> traceability is documented separately because Fabric does not promise automatic
> field-level lineage across that external boundary.

If Purview has been configured, show the Fabric and ADLS assets and latest successful
scan. Label any manually correlated external-source connection as traceability evidence,
not automatically stitched subitem lineage.

## 9. Capacity and operational evidence (12:15-13:15)

**Show:** Microsoft Fabric Capacity Metrics **Compute** page.

**Actions:**

1. Filter to the POC capacity and `MaddysWS`.
2. Filter to the recording/load-test time window.
3. Drill into notebook and semantic-model operations.
4. Show CU seconds, operation type, billing status, and timestamps.

**Say:**

> Capacity Metrics attributes consumption to the workspace, item, and operation. The
> repeatable load script records run IDs and UTC timestamps so the demo activity can be
> correlated to CU usage after the normal telemetry delay.

If telemetry hasn't arrived, show the generated
`dist\capacity-demo-<run-id>.csv` and state that Capacity Metrics normally lags by
10-15 minutes.

## 10. Close (13:15-14:00)

**Show:** Report, then OneLake Catalog details for the semantic model.

**Say:**

> This POC demonstrates an end-to-end Fabric path: external and warehouse-style
> sources, governed OneLake access, validated medallion Delta tables, a reusable Direct
> Lake semantic model, RLS-aware reporting and AI, domain-based discovery, lineage,
> endorsement, and capacity evidence. The implementation is source-controlled and
> repeatably deployable, while tenant governance decisions remain explicit.

## 11. Recording evidence checklist

Do not publish the video until every statement shown as completed has matching evidence.

| Chapter | Required evidence |
|---|---|
| Sources | Three warehouse files and three customer files through the shortcut |
| Medallion | Successful notebook run and six Bronze/Silver/Gold tables per layer |
| Model | Relationships, date roles, bridge, measures, hidden keys |
| Direct Lake | Completed framing request and rendered report |
| RLS | Same prompt with both exact regional results |
| AI | Synthetic PCR warning, approved source, grounded answer |
| Domains | Domain/subdomain, `MaddysWS` assignment, item domain metadata |
| Catalog | Domain-filtered discovery and visible endorsement state |
| Security | Viewer personas; no elevated-role RLS claim |
| Lineage | Lakehouse/notebook → semantic model → report |
| Purview | Latest scans, or an explicit not-configured statement |
| Capacity | Correlated workspace/item/operation and CU evidence |
| Safety | No secrets, personal identities, or proprietary data visible |

## Official references

- [Domains in Fabric](https://learn.microsoft.com/en-us/fabric/governance/domains)
- [OneLake catalog overview](https://learn.microsoft.com/en-us/fabric/governance/onelake-catalog-overview)
- [Endorsement overview](https://learn.microsoft.com/en-us/fabric/governance/endorsement-overview)
- [Lineage in Fabric](https://learn.microsoft.com/en-us/fabric/governance/lineage)
- [Direct Lake security integration](https://learn.microsoft.com/en-us/fabric/fundamentals/direct-lake-security-integration)

Support and UI behavior were checked against official Microsoft documentation on
2026-09-15.
