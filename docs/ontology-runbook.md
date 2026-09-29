# Fabric IQ ontology runbook

## Design decision

Keep the existing **Sales Certified** semantic model
(`dc34c959-f4fe-4ff7-b566-0aeddcf20ece`) as the governed source for DAX metrics, RLS,
and Direct Lake; don't create a duplicate semantic model. Bind ontology entities to
the Gold lakehouse Delta tables. Microsoft currently documents that a Fabric data
agent doesn't work with an ontology whose entity bindings come from a semantic model.
The semantic model therefore remains the direct source for `Sales Agent`, while the
ontology supplies business entities and relationship context to
`Ontology Agent`.

The ontology item is named `SalesOntology` because Fabric ontology names must
start with a letter, contain only letters, numbers, or underscores, and be fewer than
100 characters.

Fabric Ontology Generation 2 and the Ontology Agent are preview features. A Fabric
administrator must first enable **OneLake catalog → Govern → Configurations → Tenant
settings → Enable Ontology item (preview)**.

## Deploy the ontology item

With the same service-principal variables or Azure CLI authentication used by the main
deployment:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deploy-ontology.ps1
```

The script publishes the source-controlled Generation 2 TMDL shell, refuses to replace
an unowned item of the same name, and records its ID in `.fabric-deploy-state.json` for
safe teardown.

## Generate entities and bind the Gold tables

Entity generation and source binding use the preview **Ontology agent**, not a public
REST operation. Open `SalesOntology`, select **Ontology agent**, remain in
**Plan** mode, and submit:

> Use MedallionLakehouse item bbecaf2d-0d3f-4016-bffc-2b133292a0ee in this workspace.
> Create entity types named Customer, Product, Segment, Customer Segment Assignment,
> Sale, Order Date, and Ship Date. Bind Customer to golddimcustomer, Product to
> golddimproduct, Segment to golddimsegment, Customer Segment Assignment to
> goldbridgecustomersegment, Sale to goldfactsales, and both date roles to golddimdate.
> Preserve business-friendly property names and don't expose technical columns except
> keys required for identity and relationships. PCR means Priority Communications
> Revenue and is synthetic terminology used only for this POC.

Review the proposed plan. It must reference workspace
`930bbe6f-b256-46b7-a70e-f3dcab99d2c9` and the exact lowercase Gold table names above.
Switch to **Act** mode and submit:

> Apply the approved entity and metric plan.

Then return to **Plan** mode and submit:

> Create these ontology relationships using the bound key properties: Customer places
> Sale through Customer Key; Sale contains Product through Product Key; Customer has
> Customer Segment Assignment through Customer Key; Customer Segment Assignment
> classifies Into Segment through Segment Key; Sale occurs On Order Date through Order
> Date; and Sale ships On Ship Date through Ship Date. Keep Customer Segment Assignment
> as an entity so the many-to-many customer-to-segment relationship remains explicit.

Review the key mappings, switch to **Act**, and submit:

> Apply the approved relationship plan.

## Acceptance checks

1. The canvas contains seven entity types and six relationships.
2. `Sale` is bound to `goldfactsales` from **MedallionLakehouse** with item ID
   `bbecaf2d-0d3f-4016-bffc-2b133292a0ee`.
3. The ontology exposes the Sale properties needed for revenue, PCR, and distinct-order
   aggregation. The DAX measures remain governed in **Sales Certified** and are not
   claimed as ontology bindings.
4. Customer-to-segment navigation passes through **Customer Segment Assignment**.
5. Order Date and Ship Date remain separate business roles.
6. Hidden technical fields aren't shown as ordinary business properties.
7. The Ontology Agent answers:
   - "Which segments generated the most net revenue?"
   - "Show PCR revenue by region and product category."
   - "Which customers belong to more than one segment?"
8. `Sales Agent` answers respect semantic-model RLS. For `Ontology Agent`,
   validate each bound source's effective identity and permissions separately; Power
   BI RLS doesn't automatically transfer to lakehouse-bound ontology queries.

After configuration, use **Get Ontology Definition** or Fabric Git integration to
export the generated TMDL and replace the initial shell in source control. This
round-trip captures the service-generated table, entity, metric, and relationship
parts without guessing preview TMDL extension syntax.

## Support boundary

- Creating and updating an Ontology definition is supported by the Fabric REST API.
- Generation 2 definitions use TMDL and participate in Git integration and deployment
  pipelines.
- Entity generation and source binding use the Ontology Agent preview experience.
- Fabric documents a current known issue for data agents over ontologies that use
  semantic-model bindings; this POC uses lakehouse table bindings for that path.
- Ontology is preview and requires the tenant setting plus supported Fabric capacity.

Official references:

- [Create Ontology REST API](https://learn.microsoft.com/en-us/rest/api/fabric/ontology/items/create-ontology)
- [Ontology Generation 2 definition](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/ontology-definition)
- [Create a Data Agent with an ontology](https://learn.microsoft.com/en-us/fabric/iq/ontology/how-to-create-data-agent)
- [Ontology prerequisites](https://learn.microsoft.com/en-us/fabric/iq/ontology/tutorial-0-introduction)
