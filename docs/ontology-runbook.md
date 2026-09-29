# Fabric IQ ontology runbook

## Design decision

Use the existing **Motorola Sales Certified** semantic model. Don't create a duplicate
semantic model. The ontology supplies business entities, relationships, and agent
context; the semantic model remains the governed source for relationships, DAX metrics,
RLS, and the Direct Lake connection.

The ontology item is named `MotorolaSalesOntology` because Fabric ontology names must
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

## Generate entities from the existing semantic model

Microsoft's documented semantic-model generation path is the preview **Ontology
Agent**, not a public "generate from semantic model" REST operation. Open
`MotorolaSalesOntology`, select **Ontology agent**, remain in **Plan** mode, and submit:

> Use the Motorola Sales Certified semantic model in this workspace. Create entity
> types named Customer, Product, Segment, Customer Segment Assignment, Sale, Order
> Date, and Ship Date. Bind each entity to the correspondingly named semantic model
> table. Bind Sale to Fact Sales. Preserve the semantic model's business-friendly
> property names and don't expose hidden technical columns except keys required for
> entity identity and relationships. Add the Net Revenue, PCR Revenue, and Order Count
> DAX measures from Fact Sales as Sale metrics. PCR means Priority Communications
> Revenue and is synthetic terminology for this POC.

Review the proposed plan. It must reference semantic model
`dc34c959-f4fe-4ff7-b566-0aeddcf20ece` in workspace
`930bbe6f-b256-46b7-a70e-f3dcab99d2c9`. Switch to **Act** mode and submit:

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
2. `Sale` is bound to `Fact Sales` from **Motorola Sales Certified**.
3. `Sale` exposes **Net Revenue**, **PCR Revenue**, and **Order Count** as metrics.
4. Customer-to-segment navigation passes through **Customer Segment Assignment**.
5. Order Date and Ship Date remain separate business roles.
6. Hidden technical fields aren't shown as ordinary business properties.
7. The Ontology Agent answers:
   - "Which segments generated the most net revenue?"
   - "Show PCR revenue by region and product category."
   - "Which customers belong to more than one segment?"
8. Answers respect the semantic model's security context. Validate with Viewer
   identities; workspace Admins, Members, and Contributors bypass semantic-model RLS.

After configuration, use **Get Ontology Definition** or Fabric Git integration to
export the generated TMDL and replace the initial shell in source control. This
round-trip captures the service-generated table, entity, metric, and relationship
parts without guessing preview TMDL extension syntax.

## Support boundary

- Creating and updating an Ontology definition is supported by the Fabric REST API.
- Generation 2 definitions use TMDL and participate in Git integration and deployment
  pipelines.
- Binding/generating ontology entities from a semantic model is documented through the
  Ontology Agent preview experience.
- Ontology is preview and requires the tenant setting plus supported Fabric capacity.

Official references:

- [Create Ontology REST API](https://learn.microsoft.com/en-us/rest/api/fabric/ontology/items/create-ontology)
- [Ontology Generation 2 definition](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/ontology-definition)
- [Ontology tutorial and semantic-model binding](https://learn.microsoft.com/en-us/fabric/iq/ontology/tutorial-1-create-ontology)
- [Ontology prerequisites](https://learn.microsoft.com/en-us/fabric/iq/ontology/tutorial-0-introduction)
