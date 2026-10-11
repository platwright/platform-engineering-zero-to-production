# Lab — Build a Software Catalog Graph

> Write a realistic multi-entity `catalog-info.yaml`, import it into your local
> Backstage, navigate the relationship graph, then switch to automatic **GitHub
> discovery**. The core runs entirely against local Backstage; discovery uses a free
> GitHub account.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A connected catalog in Backstage showing a System, two Components, an
API, a Resource, and a Group — with working owner, dependency, and API links.

## Objectives

- Author a valid, multi-entity catalog descriptor with real relationships.
- Import entities into Backstage and read the dependency/system graph.
- Configure GitHub discovery so new repos are ingested automatically.

## Prerequisites

- [Module 15.3](../README.md) and a running Backstage app from
  [Module 15.2](../../02-backstage-fundamentals/) (`yarn dev`).
- The starter files in this folder: [`catalog-info.yaml`](./catalog-info.yaml) and
  [`openapi.yaml`](./openapi.yaml).
- A free GitHub account for the optional discovery step.

## Steps

1. **Read the starter descriptor.** Open [`catalog-info.yaml`](./catalog-info.yaml). It
   declares six entities in one multi-document file: a **System**
   (`order-management`), two **Components** (`checkout-service`, `payment-gateway`), an
   **API** (`checkout-api`), a **Resource** (`orders-database`), and a **Group**
   (`team-payments`). Trace the relationships: `owner`, `system`, `dependsOn`,
   `providesApis`.

2. **Register it in Backstage.** In the UI, use **Create → Register Existing
   Component**, and paste a URL to this file (if you pushed it to a repo), or add a
   local location to `app-config.yaml`:

   ```yaml
   catalog:
     locations:
       - type: file
         target: ../../path/to/catalog-info.yaml
         rules:
           - allow: [Component, API, System, Resource, Group]
   ```

   Restart `yarn dev` if you edited config.

3. **Explore the graph.** Open `checkout-service`. Confirm:

   - the **owner** links to `team-payments`,
   - it is **part of** `order-management`,
   - it **provides** `checkout-api`,
   - it **depends on** `payment-gateway` and `orders-database`.

   Open the system `order-management` and view its diagram — you should see all the
   pieces and their edges.

4. **Render the API.** Open the `checkout-api` entity. Backstage renders browsable
   docs from the referenced [`openapi.yaml`](./openapi.yaml). Note how a consumer could
   read the contract without asking your team.

5. **Break and fix a relationship (learn the failure mode).** Temporarily change
   `dependsOn` to reference `resource:does-not-exist`, reload, and find the processing
   error Backstage surfaces. Revert it. This is what catalog *health* monitoring
   catches.

6. **(Optional) Turn on GitHub discovery.** Push a `catalog-info.yaml` to a repo in
   your GitHub org and configure discovery:

   ```yaml
   # app-config.yaml
   catalog:
     providers:
       github:
         myOrg:
           organization: your-org
           catalogPath: /catalog-info.yaml
           schedule:
             frequency: { minutes: 30 }
             timeout: { minutes: 3 }
   ```

   Within the refresh window, the new repo appears in the catalog with no manual
   registration.

## Expected result

A navigable catalog where `order-management` shows its components, APIs, and resource;
`checkout-service` links to its owner, system, API, and dependencies; and the
`checkout-api` page renders OpenAPI docs. If you did Step 6, a newly pushed repo
self-registers.

## Cleanup

> Local Backstage holds no cloud resources. Revert any temporary config.

```bash
# Remove any local catalog.locations or discovery config you added to app-config.yaml,
# and restart `yarn dev`. No cloud resources were created.
```

## Reflection

- How many Slack questions does this one graph replace (owner, deps, API, on-call)?
- What enforces that every new service arrives with a real owner? (Preview: the golden
  path in Module 15.6 bakes the descriptor into the skeleton.)
- Which annotations would you add now to prepare for the plugins in Module 15.5?

## Stretch goals (optional)

- Add a **Domain** (`commerce`) and make `order-management` part of it.
- Add a `consumesApis` entry so `payment-gateway` consumes `checkout-api`, and see the
  reverse relationship render.
- Write a tiny CI check that fails if any `catalog-info.yaml` has `owner: unknown`.
