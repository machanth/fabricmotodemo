# Ontology-grounded Fabric data agent

## Current support boundary

Fabric's UI supports adding an Ontology (preview) as a Data Agent source. However, the
public DataAgent definition schema currently doesn't include `ontology` in the
documented datasource type enum. The source-controlled desired definition is retained
in `fabric/Motorola Ontology Agent.DataAgent`; deploy it through the public API only
when the service accepts that datasource type.

The live `MotorolaSalesOntology` item is currently a valid, empty Generation 2 shell.
It has no entity types, relationships, or data bindings. In addition, Microsoft
documents a current known issue: a Fabric data agent doesn't work with an ontology that
uses semantic models for binding. Ontology entities must first be bound to supported
queryable sources before this agent can answer data questions.

## UI completion

1. Open `MotorolaSalesOntology`.
2. Use **Ontology agent** in Plan mode to create Customer, Product, Segment, Customer
   Segment Assignment, Sale, Order Date, and Ship Date.
3. Bind the entities to the corresponding Gold lakehouse tables so the Fabric data
   agent can query them during the current preview.
4. Preserve Customer Segment Assignment as an entity between Customer and Segment.
5. Review, validate, switch to Act mode, and apply the ontology definition.
6. Open `Motorola Ontology Agent`.
7. Select **Add a data source**, search OneLake Catalog for
   `MotorolaSalesOntology`, and select **Add**.
8. In **Agent instructions**, retain the committed PCR warning and add
   `Support group by in GQL`.
9. Run `ai/ontology-agent-test-cases.json`. Treat the numeric KPI results as acceptance
   targets only after supported bindings and security are configured.
10. Publish the agent in the UI. Publishing remains a preview API/UI action and isn't
    implied by draft deployment.

RLS defined only inside the Power BI semantic model does not automatically become
ontology source security. Validate effective identity and source permissions for each
ontology binding. Use the existing semantic-model-grounded `Sales Agent` when Power BI
RLS behavior is required.

Official references:

- [Add a data source to Data Agent](https://learn.microsoft.com/en-us/fabric/data-science/data-agent-add-datasources)
- [Create a Data Agent with an ontology](https://learn.microsoft.com/en-us/fabric/iq/ontology/how-to-create-data-agent)
- [DataAgent public definition](https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/definitions/data-agent-definition)
