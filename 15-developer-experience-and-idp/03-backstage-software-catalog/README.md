# Module 15.3 — Backstage Software Catalog

> The Software Catalog is Backstage's backbone and the IDP's **application catalog**
> capability from Module 01.4: a live inventory of *what exists, who owns it, where it
> runs, and how the pieces relate*. This module covers the catalog's entity kinds, the
> `catalog-info.yaml` descriptor that lives in every repo, the relationships that turn a
> list into a graph, automatic **GitHub discovery**, and how to keep the catalog from
> rotting into fiction.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 15.2](../02-backstage-fundamentals/) and a running Backstage
app (local is fine). A GitHub account for the discovery step.

## Learning objectives

By the end of this module you will be able to:

- Name the catalog **entity kinds** and when to use each.
- Write a valid `catalog-info.yaml` for a Component, API, System, and Group.
- Model **relationships** (`ownedBy`, `partOf`, `dependsOn`, `providesApis`) into a
  useful graph.
- Configure **GitHub discovery** to ingest entities automatically.
- Explain and measure **catalog health** (staleness, missing owners).

---

## 1. Concept

### The catalog is the inventory you keep asking Slack for

Every organization past a handful of services develops the same blind spots: *Who owns
this service? What depends on the orders database? Which team do I page? Where is this
deployed?* Today those are answered — badly, inconsistently — in Slack threads and
tribal memory. The **Software Catalog** makes them a queryable, always-current graph.
It is the concrete form of Module 01.4's *application catalog* capability and the thing
most of the portal's value hangs off.

### Entity kinds

The catalog models your world with a small set of **entity kinds**:

- **Component** — a piece of software you build and run: a service, website, or
  library. The most common entity.
- **API** — an interface a component exposes (REST/OpenAPI, gRPC, GraphQL,
  AsyncAPI). Catalogued separately so consumers can discover it.
- **System** — a collection of components and resources that work together toward a
  capability (e.g. "order-management"). The right altitude for most architecture
  conversations.
- **Domain** — a group of related systems sharing a business area (e.g. "commerce").
- **Resource** — infrastructure a component needs: a database, bucket, queue, or
  cluster.
- **Group** — a team or org unit (e.g. `team-payments`).
- **User** — a person, usually mapped from your identity provider.

```text
  Domain  (commerce)
     └── System  (order-management)
           ├── Component (checkout-service) ──provides──► API (checkout-api)
           │        └── dependsOn ──► Resource (orders-database)
           └── Component (payment-gateway)
   Group (team-payments) ──owns──► checkout-service, checkout-api
```

### `catalog-info.yaml`: the descriptor in every repo

Each entity is declared in a YAML descriptor, conventionally `catalog-info.yaml` at the
root of the repo that owns it. This is **docs-as-code for your architecture**: the
inventory lives with the code, is reviewed in PRs, and cannot drift from the repo it
describes. A minimal Component:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-service
  description: Handles payment and order checkout
  annotations:
    github.com/project-slug: org/checkout-service
    backstage.io/techdocs-ref: dir:.
spec:
  type: service
  lifecycle: production
  owner: team-payments
  system: order-management
```

The `spec.type` (service/website/library), `spec.lifecycle`
(experimental/production/deprecated), and `spec.owner` are the fields you will set most
often. **Annotations** wire the entity to external systems — the `github.com/*`
annotation links it to a repo; later modules add `argocd/app-name`,
`backstage.io/kubernetes-id`, and Grafana annotations to light up plugins (Module
15.5).

### Relationships turn a list into a graph

A flat list of services is a phone book. The value appears when entities **reference
each other** and Backstage renders the relationships:

- **`spec.owner`** → an `ownedBy` relationship to a Group. Every entity should have a
  real owner; "who do I ask?" becomes a link, not a guess.
- **`spec.system`** → a `partOf` relationship: this component belongs to a system.
- **`spec.dependsOn`** → explicit dependencies on other components or resources
  (`component:payment-gateway`, `resource:orders-database`).
- **`spec.providesApis`** / **`spec.consumesApis`** → links components to the API
  entities they expose or call.

From these, Backstage draws a dependency graph, a system diagram, and "what will I
break if I change this?" views. The relationships are the point — model them honestly.

### API catalog from OpenAPI

An **API** entity can embed or reference a definition (an OpenAPI spec), and Backstage
renders browsable docs and a try-it view from it:

```yaml
apiVersion: backstage.io/v1alpha1
kind: API
metadata:
  name: checkout-api
spec:
  type: openapi
  lifecycle: production
  owner: team-payments
  definition:
    $text: ./openapi.yaml   # or an inline spec / a URL
```

Now API consumers discover and read the contract in the portal instead of asking the
owning team — a direct cut to the "waiting friction" from Module 01.3.

### Catalog ingestion: GitHub discovery

Registering each `catalog-info.yaml` by hand does not scale. **GitHub discovery**
points Backstage at an org and automatically ingests every repo that contains a
descriptor:

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

Add a descriptor to a new repo and it shows up in the catalog within the refresh
window — no central registry to maintain. This is the ingestion automation Module 01.4
insisted on: *"automate ingestion or the catalog rots into fiction."*

### Catalog health

A catalog is only useful if it is **current and complete**. Two failure modes to watch:

- **Staleness** — an entity still listed but the repo is archived or gone. Discovery
  plus periodic refresh prunes most of it; processing errors surface the rest.
- **Missing or fake owners** — `owner: unknown` or a group that does not exist. These
  are the entries that make the catalog untrustworthy. Enforce that every entity has a
  real `owner` (a validation step in CI, or a Soundcheck/scorecard-style check).

Treat catalog health as an operational metric: *what percent of entities have a real
owner, valid relationships, and no processing errors?*

---

## 2. Why it matters for platform engineering

The catalog is the **substrate** the rest of the portal builds on. Templates (Module
15.4) register new components into it; plugins (Module 15.5) attach live deploy,
runtime, and cost data to its entities; golden paths (Module 15.6) depend on every new
service arriving pre-catalogued. Without a trustworthy catalog, none of that works — a
plugin that shows ArgoCD status needs to know *which* ArgoCD app an entity maps to, and
that mapping lives in `catalog-info.yaml`.

More broadly, the catalog is how a platform answers ownership, dependency, and
incident-routing questions at scale. When an alert fires at 3am, "which team owns this
and what does it depend on?" is a catalog query, not an archaeology dig. That is the
difference between a platform and a pile of services.

---

## 3. Mental model

```text
     THE SOFTWARE CATALOG = your architecture, as a living graph
     ──────────────────────────────────────────────────────────

  entity kinds   Component · API · System · Domain · Resource · Group · User
  descriptor     catalog-info.yaml in each repo (docs-as-code for architecture)
  relationships  ownedBy · partOf · dependsOn · provides/consumesApis
                 (the edges are the value, not the nodes)
  ingestion      GitHub discovery auto-imports every repo with a descriptor
  health         every entity has a REAL owner + valid refs + no stale entries

  Ask of the catalog: who owns it? what's it part of? what does it depend on?
  what does it expose? — and get a link, not a Slack thread.
```

One sentence: **the catalog is your architecture expressed as owned, related entities
that live with the code and refresh themselves.**

---

## 4. Minimal implementation

The smallest useful catalog is one descriptor registered in Backstage. Create a
`catalog-info.yaml` describing a service and its owning team, then register its
location:

```yaml
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: hello-service
  description: A minimal example service
spec:
  type: service
  lifecycle: experimental
  owner: team-demo
---
apiVersion: backstage.io/v1alpha1
kind: Group
metadata:
  name: team-demo
spec:
  type: team
  children: []
```

```yaml
# app-config.yaml — register a single location (before you set up discovery)
catalog:
  locations:
    - type: url
      target: https://github.com/your-org/hello-service/blob/main/catalog-info.yaml
```

Reload the catalog and `hello-service` appears, owned by `team-demo`, with a working
"owner" link. That is the whole mechanism — the lab scales it to a realistic multi-
entity graph and switches from hand-registered locations to automatic discovery.

---

## 5. Hands-on lab

You will write a realistic [`catalog-info.yaml`](./lab/catalog-info.yaml) describing a
**System**, two **Components**, an **API**, a **Resource**, and a **Group**, wire up
their relationships, import it into your local Backstage, and then configure **GitHub
discovery** so new repos are ingested automatically. The deliverable is a connected
catalog graph you can navigate.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Enforce a real owner on every entity.** A validation check in CI (or a scorecard)
  that fails on missing/unknown owners keeps the catalog trustworthy. An unowned entity
  is an incident waiting to misroute.
- **Prefer discovery over hand registration.** Manual `catalog.locations` lists rot.
  Point discovery at the org and let descriptors self-register.
- **Watch processing errors.** Backstage surfaces entities that fail to process (bad
  YAML, dangling refs). Treat a rising error count as a catalog incident.
- **Model at the right altitude.** Systems and Domains keep large catalogs navigable;
  without them you get a flat wall of hundreds of components.
- **Keep descriptors in the service repo.** Co-locating `catalog-info.yaml` with the
  code (not in a central repo) is what prevents drift and enables PR review.
- **Govern annotations.** Plugins depend on specific annotations; document the required
  set and validate them, so a new service lights up every plugin by default.

---

## 7. Common mistakes

- **Treating the catalog as a one-time import.** Bulk-adding entities, then never
  refreshing. *Fix:* discovery + scheduled refresh so it stays current automatically.
- **Entities with no real owner.** `owner: unknown` makes the whole catalog
  untrustworthy. *Fix:* require a valid Group owner, enforced in CI.
- **Skipping relationships.** A flat list of components with no `system`, `dependsOn`,
  or `providesApis`. *Fix:* model the edges — they are where the value is.
- **A central `catalog-info` repo.** Descriptors far from the code drift immediately.
  *Fix:* one descriptor per service repo, reviewed with the code.
- **Dangling references.** `dependsOn: resource:orders-database` when that resource
  entity does not exist. *Fix:* catch processing errors; declare resources too.
- **Ignoring API entities.** Services with undocumented interfaces. *Fix:* catalogue
  APIs from OpenAPI so consumers self-serve the contract.

---

## 8. Assessment

**Knowledge checks**

1. What is the difference between a **Component**, a **System**, and a **Domain**?
2. Which `spec` fields create the `ownedBy`, `partOf`, and `dependsOn` relationships?
3. Why is `catalog-info.yaml` kept in each service's own repo rather than a central
   one?
4. What does GitHub discovery do, and why is it better than a hand-maintained
   locations list?
5. Name two signals of poor catalog health and how you would detect them.

**Concept exercise**

> Explain what a software catalog gives an organization **without naming Backstage**.
> Describe the questions it answers and why keeping the data next to the code matters.

**Architecture / trade-off exercise**

> Your catalog has 300 entities but developers do not trust it: a third have
> `owner: unknown`, several depend on resources that were never declared, and nobody
> prunes archived services. Diagnose each problem in catalog-health terms and give a
> concrete fix (config, process, or CI check) for each.

<details>
<summary>Discussion</summary>

- **Q1:** A Component is one buildable/runnable piece of software; a System groups
  components and resources that deliver a capability together; a Domain groups related
  systems by business area. Altitude increases Component → System → Domain.
- **Q2:** `spec.owner` → `ownedBy` (to a Group), `spec.system` → `partOf` (to a
  System), `spec.dependsOn` → dependency edges to components/resources.
- **Q3:** Co-location keeps the descriptor in sync with the code, lets it be reviewed in
  the same PR, and prevents the drift a separate registry suffers.
- **Q4:** Discovery scans a GitHub org and auto-ingests every repo containing a
  descriptor on a schedule, so the catalog self-updates instead of requiring someone to
  edit a central list.
- **Q5:** Missing/unknown owners (detect via a CI validation or scorecard) and stale
  entries/processing errors (detect via Backstage's processing-error surface and
  discovery pruning).
- **Trade-off:** Unknown owners → enforce a valid owner in CI and backfill; undeclared
  resource deps → add Resource entities and fail on dangling refs; no pruning → switch
  to discovery with scheduled refresh so archived repos drop out. Track "% entities
  healthy" as an ongoing metric.

</details>

---

## 9. Further reading

- Backstage — [Software Catalog overview](https://backstage.io/docs/features/software-catalog/)
- Backstage — [Descriptor format (`catalog-info.yaml`)](https://backstage.io/docs/features/software-catalog/descriptor-format)
- Backstage — [System model and relationships](https://backstage.io/docs/features/software-catalog/system-model)
- Backstage — [GitHub discovery provider](https://backstage.io/docs/integrations/github/discovery)
- Backstage — [Documenting APIs in the catalog](https://backstage.io/docs/features/software-catalog/descriptor-format#kind-api)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [15.2 — Backstage Fundamentals](../02-backstage-fundamentals/)
· _Next:_ [15.4 — Backstage Software Templates →](../04-backstage-software-templates/)
