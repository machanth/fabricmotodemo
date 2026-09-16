# Demo video recording runbook

This script produces a 12-15 minute evidence-based, text-to-speech demo of the deployed
Motorola-style Microsoft Fabric POC. All organizations, products, transactions, and
**PCR ("Priority Communications Revenue")** terminology are synthetic.

The quoted paragraphs are the complete voiceover. Spoken transitions such as "Now I'm
going to open..." replace production directions so the narration remains natural while
the presenter performs the matching action. Pause the text-to-speech playback after a
transition when the interface needs time to load.

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

> This is a synthetic Microsoft Fabric proof of concept for complex sales analytics,
> governed self-service reporting, and conversational data access. It combines a
> warehouse-style order domain with an ADLS customer domain without exposing
> proprietary data. Business users consume a certified semantic layer and never create
> joins themselves.
>
> Now I'm going to open the MaddysWS workspace and the Motorola Sales Overview report
> to begin the demonstration.

Add a small on-screen caption: **Synthetic POC data - not Motorola production data**.

## 3. Architecture and source domains (0:45-2:00)

> Now I'm going to show the solution architecture and then open the Medallion
> Lakehouse.
>
> The first source domain simulates warehouse orders, order lines, and products. The
> second simulates customer, segment, and many-to-many assignment data in ADLS Gen2.
> The OneLake shortcut gives Fabric a governed reference to that external location.
>
> First, I'm expanding Files, landing, and warehouse. Here we can see orders, order
> lines, and products.
>
> Next, I'm expanding Files, landing, customer domain, and external customers. Here we
> can see customers, segments, and customer segment assignments.
>
> Now I'm opening the shortcut details. These customer files are referenced through
> the external ADLS shortcut rather than manually copied into the landing folder.

Do not open the connection credential page during recording.

## 4. Medallion transformation and data quality (2:00-3:15)

> Now I'm going to open the Transform Medallion notebook and briefly show its typed
> schemas and fail-fast duplicate and orphan checks.
>
> The notebook validates keys and referential integrity before writing Delta. Six
> Bronze tables preserve ingestion, six Silver tables standardize business data, and
> six Gold tables provide the star schema. The customer-segment assignment remains a
> genuine bridge instead of flattening away the many-to-many relationship.
>
> Now I'm opening Monitor to show the successful production notebook run.
>
> Next, I'm returning to the lakehouse and expanding the Bronze, Silver, and Gold
> tables. Finally, I'm opening the Gold Fact Sales and Gold Dimension Segment previews
> to show the analytics-ready Delta data.

## 5. Certified semantic layer and thin report (3:15-5:30)

> Now I'm going to open the Motorola Sales Certified semantic model and its
> relationship diagram.
>
> Here we can see Fact Sales, Customer, Product, Segment, and the customer-segment
> bridge. We can also see Order Date and Ship Date, which are two roles played by the
> same date dimension.
>
> Direct Lake reads the Gold Delta tables without importing a second copy. The model
> owns every relationship, including bidirectional propagation through the bridge and
> two roles for the date dimension. The thin report contains presentation only, so
> users drag and drop approved fields without recreating joins.
>
> Now I'm showing the business-friendly fields, hidden technical keys, and the Net
> Revenue, PCR Revenue, and Order Count measures.
>
> Next, I'm opening the report and selecting product, segment, and date filters to
> demonstrate that all visuals use the centrally managed model relationships.

Show the refresh history entry for request
`ca57251d-84de-42f5-b41a-b5baf6cf7ee5` and call out **DirectLakeFraming -
Completed**.

## 6. RLS and ask-the-data experience (5:30-7:45)

### RLS

> Now I'm opening semantic model Security to show the North America and Europe roles.
> Personal email addresses are hidden during this demonstration.
>
> First, I'm testing as the North America Viewer persona and asking: What are net
> revenue, PCR revenue, and order count?
>
> The North America result is 6 million, 737 thousand, 571 dollars and 5 cents in net
> revenue; 1 million, 477 thousand, 389 dollars and 30 cents in PCR revenue; and 300
> orders.
>
> Now I'm testing as the Europe Viewer persona and asking the exact same question.
>
> The Europe result is 12 million, 893 thousand, 250 dollars in net revenue; 2 million,
> 987 thousand, 650 dollars and 25 cents in PCR revenue; and 600 orders.
>
> The question is identical. The effective identity changes, and semantic-model RLS
> applies the regional filter. Elevated workspace roles bypass RLS, which is why these
> tests use Viewer identities.

### Fabric data agent and Copilot

> Now I'm going to open the Motorola Sales Agent.
>
> Here we can see that Motorola Sales Certified is its approved source. I'm also
> showing the instruction that defines PCR.
>
> PCR means Priority Communications Revenue, a synthetic term created only for this
> POC. The agent is grounded in the approved model rather than raw landing data, so it
> inherits business definitions, relationships, and security.
>
> Now I'm asking: What does PCR mean, and what is PCR revenue for my region?
>
> The answer uses the approved business definition and respects the current user's
> regional security context. Where available, I'm also showing the generated query
> details for transparency.
>
> If standalone Copilot is enabled, I'm now opening it and selecting the approved
> semantic model to repeat the same prompt.

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

> Now I'm opening the Fabric Admin portal and selecting Domains.
>
> Here is the Commercial Analytics domain, its Sales Intelligence subdomain, and the
> MaddysWS workspace assignment. I'm also showing the domain metadata inherited by a
> workspace item.
>
> Domains provide federated organization and governance. The workspace assignment makes
> every POC item discoverable under Sales Intelligence, while access still comes from
> workspace roles and item permissions. Domain admins can also manage delegated tenant
> settings where the Fabric admin has allowed delegation.

Do not select **Assign by capacity** for this shared POC capacity: it could reclassify
unrelated workspaces.

## 8. OneLake Catalog, endorsement, security, and lineage (10:15-12:15)

### Catalog and endorsement

> Now I'm opening OneLake Catalog and selecting Explore.
>
> I'm filtering to the Commercial Analytics domain and Sales Intelligence subdomain,
> then searching for Motorola Sales Certified.
>
> The domain filter makes governed assets easier to discover. Promotion indicates
> owner readiness; certification requires an authorized reviewer and signals that the
> semantic model meets organizational standards. Domain assignment itself does not
> provide access.
>
> Now I'm opening the model details to show its description, owner, endorsement, and
> lineage. The Medallion Lakehouse is promoted, the Motorola Sales Certified semantic
> model is certified, and the Motorola Sales Overview report is promoted or certified
> according to tenant policy.
>
> Next, I'm opening the Govern tab to show recommended governance actions, followed by
> the Secure tab to show the centralized workspace and OneLake security posture.

If certification is not enabled, show **Request certification** and say that a Fabric
admin must enable certification and configure reviewer groups. Do not claim the item is
certified until the badge is visible.

### Native lineage

> Now I'm returning to MaddysWS and opening Lineage view.
>
> I'm selecting the semantic model and highlighting its lineage. This shows the chain
> from the lakehouse and notebook through the semantic model to the report.
>
> Workspace lineage explains dependencies and change impact. Fabric displays upstream
> sources outside the workspace only one level up. The ADLS object-to-shortcut
> traceability is documented separately because Fabric does not promise automatic
> field-level lineage across that external boundary.
>
> Where useful, I'm also opening Impact analysis to show the downstream effect of a
> proposed change.

If Purview has been configured, show the Fabric and ADLS assets and latest successful
scan. Label any manually correlated external-source connection as traceability evidence,
not automatically stitched subitem lineage.

## 9. Capacity and operational evidence (12:15-13:15)

> Now I'm opening the Microsoft Fabric Capacity Metrics app and selecting the Compute
> page.
>
> I'm filtering to the POC capacity, the MaddysWS workspace, and the recording or load
> test time window. Next, I'm drilling into the notebook and semantic-model operations
> to show CU seconds, operation type, billing status, and timestamps.
>
> Capacity Metrics attributes consumption to the workspace, item, and operation. The
> repeatable load script records run IDs and UTC timestamps so the demo activity can be
> correlated to CU usage after the normal telemetry delay.

If telemetry hasn't arrived, show the generated
`dist\capacity-demo-<run-id>.csv` and state that Capacity Metrics normally lags by
10-15 minutes.

## 10. Close (13:15-14:00)

> To close the demonstration, I'm returning to the Motorola Sales Overview report and
> then opening the semantic model details in OneLake Catalog.
>
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
