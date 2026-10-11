# Module 15.5 — Backstage Plugins

> A catalog entry becomes genuinely useful when its page shows **live** data:
> deployment status, running pods, dashboards, and cost — all in one place. Plugins are
> how Backstage pulls those in. This module covers the plugin architecture, the
> official plugins for **ArgoCD**, **Kubernetes**, **Grafana**, and **cost**, the
> annotations that wire them to catalog entities, and when to build a custom plugin.

**Estimated effort:** ~2 hours (theory + lab)
**You'll need:** [Module 15.3](../03-backstage-software-catalog/) (annotations) and a
running Backstage app. Live plugin data needs the backing systems (ArgoCD, a cluster,
Grafana) — all **optional**; the lesson works with the catalog you already have.

## Learning objectives

By the end of this module you will be able to:

- Explain the frontend/backend split of a Backstage plugin.
- Install and configure the ArgoCD, Kubernetes, Grafana, and cost plugins.
- Use **catalog annotations** to bind a plugin's data to an entity.
- Decide when an official plugin suffices and when to build a custom one.

---

## 1. Concept

### Why plugins: the single pane of glass

A service page that lists only metadata ("owned by team-payments, lifecycle
production") answers *who* but not *how is it doing right now*. Plugins close that gap
by pulling runtime truth from the systems you already run — turning the catalog entry
into a **single pane of glass**:

- **ArgoCD** → is it in sync? healthy? what version is deployed? (your Phase 8 GitOps
  state)
- **Kubernetes** → which pods, deployments, and events are live? (your Phase 3/10
  runtime)
- **Grafana** → the service's golden-signal dashboard, embedded. (your Phase 11
  observability)
- **Cost** → what is this team/service spending? (your Phase 15 FinOps data)

That is the monitoring plane (Module 01.4) surfaced in the developer control plane,
exactly where a developer is already looking.

### Plugin architecture: frontend + backend

Recall from Module 15.2 that *everything is a plugin*. A plugin typically has two
halves:

- **Frontend plugin** (React) — the cards, tabs, and pages shown in the UI. For entity
  plugins, you add a card to the entity page layout in `packages/app`.
- **Backend plugin** (Node.js) — a service that talks to the external system (ArgoCD's
  API, the Kubernetes API, Grafana) and exposes a clean API the frontend calls, so
  credentials never touch the browser.

```text
   Entity page (React)                     Backstage backend (Node.js)
   ┌───────────────────────┐   calls      ┌───────────────────────────┐
   │ ArgoCD card           │ ───────────► │ argocd backend  ──► ArgoCD │
   │ Kubernetes card       │ ───────────► │ kubernetes      ──► cluster│
   │ Grafana dashboard     │ ───────────► │ (proxy)         ──► Grafana│
   │ Cost card             │ ───────────► │ cost backend    ──► billing│
   └───────────────────────┘              └───────────────────────────┘
          which entity?  ▲
          answered by ANNOTATIONS on catalog-info.yaml
```

### Annotations bind plugins to entities

A plugin needs to know *which* ArgoCD app or *which* pods belong to *this* entity. That
mapping lives in the entity's `catalog-info.yaml` **annotations** — the ones you
already added in Module 15.3:

```yaml
metadata:
  annotations:
    argocd/app-name: checkout-service            # ArgoCD plugin
    backstage.io/kubernetes-id: checkout-service  # Kubernetes plugin (label selector)
    grafana/dashboard-selector: "tags @> 'checkout-service'"  # Grafana plugin
```

This is why the catalog is the substrate (Module 15.3): the annotations are the wiring
that lets each plugin find its slice of reality for a given service. Govern them — a
service that is missing `argocd/app-name` silently shows no deploy status.

### The official plugins

Backstage has a large plugin ecosystem — some maintained by the core project, many by
the community (notably **Roadie**). For the four capabilities here:

- **ArgoCD** (`@roadiehq/backstage-plugin-argo-cd`) — shows sync/health status and
  history on the entity page. Reads `argocd/app-name`.
- **Kubernetes** (`@backstage/plugin-kubernetes`) — shows deployments, pods, and events
  for the entity across configured clusters. Reads `backstage.io/kubernetes-id` (a
  label selector). Needs a cluster and a service-account token.
- **Grafana** (`@roadiehq/backstage-plugin-grafana`) — embeds dashboards and alert
  state. Reads a dashboard selector annotation; proxied through the backend.
- **Cost** (`@backstage/plugin-cost-insights`) — a frontend that renders cost trends;
  you supply a backend data source (OpenCost/Kubecost or cloud billing).

> Plugin APIs evolve across Backstage's "old" and "new" backend systems. Pin your
> Backstage version and follow each plugin's install guide for the matching version —
> this is the upgrade discipline from Module 15.2.

### Building a custom plugin

When no official plugin fits — an internal system, a bespoke scorecard, a team's
on-call schedule from an in-house tool — you build a **custom plugin** with the
Backstage plugin SDK (`yarn backstage-cli new --select plugin`). You write a React
frontend card and (if it needs credentials or server logic) a Node backend. A custom
plugin is also how you surface your **platform API** (Module 15.1) directly in the
portal. Build these sparingly: each is code you own and upgrade. Prefer configuration
and official plugins; build only where you add unique value.

---

## 2. Why it matters for platform engineering

Plugins are what make the portal *sticky*. A catalog alone is a nice directory;
a catalog whose pages show live deploy status, running pods, the right dashboard, and
cost is where developers actually start their day. That stickiness is adoption, and
adoption is the scoreboard (Module 01.1).

Plugins are also the payoff for everything you built in earlier phases. The ArgoCD
plugin surfaces Project 2's GitOps; the Kubernetes plugin surfaces Project 1's clusters
and namespaces; the Grafana plugin surfaces Project 3's observability; the cost plugin
previews Phase 15's FinOps. The platform's value was always there — plugins make it
*visible* in one place, which is often the difference between a capability existing and
a developer using it.

---

## 3. Mental model

```text
     PLUGINS = live data from the systems you already run, on the entity page
     ────────────────────────────────────────────────────────────────────────

   frontend (React card)  ◄── calls ──►  backend (Node) ──► external system
                                   ▲
   which entity's data?  ── answered by ANNOTATIONS in catalog-info.yaml

   ArgoCD  → deploy/sync (Phase 8)     Kubernetes → pods/events (Phase 3/10)
   Grafana → dashboards (Phase 11)     Cost       → spend (Phase 15)

   Build CUSTOM only when no official plugin fits (and to surface YOUR platform API).
```

One sentence: **plugins turn a catalog entry into a single pane of glass by binding
live data from your existing systems to the entity through annotations.**

---

## 4. Minimal implementation

The smallest plugin win is the Kubernetes plugin showing pods for one service. Three
moves: install, configure a cluster, annotate the entity.

```bash
# 1. Install the frontend + backend packages (from the app root)
yarn --cwd packages/app add @backstage/plugin-kubernetes
yarn --cwd packages/backend add @backstage/plugin-kubernetes-backend
```

```yaml
# 2. app-config.yaml — point Backstage at a cluster
kubernetes:
  serviceLocatorMethod:
    type: multiTenant
  clusterLocatorMethods:
    - type: config
      clusters:
        - name: dev
          url: ${KUBE_API_URL}
          authProvider: serviceAccount
          serviceAccountToken: ${KUBE_SA_TOKEN}
```

```yaml
# 3. catalog-info.yaml — bind the entity to its workloads
metadata:
  annotations:
    backstage.io/kubernetes-id: checkout-service
```

Add the Kubernetes tab to the entity page in `packages/app/src/components/catalog/EntityPage.tsx`,
reload, and the `checkout-service` page now lists its live pods, deployments, and
events. The same install → configure → annotate pattern repeats for ArgoCD, Grafana,
and cost. The lab does all four and sketches a custom plugin.

---

## 5. Hands-on lab

You will add the ArgoCD, Kubernetes, Grafana, and cost plugins to your Backstage app
using the provided [`app-config.plugins.yaml`](./lab/app-config.plugins.yaml)
configuration snippets, bind them to a catalog entity with annotations, and view the
enriched entity page. Steps that need live backends (a real cluster, ArgoCD, Grafana)
are clearly optional; the install/config/annotation work is local. You will also
scaffold a custom plugin skeleton.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Keep credentials in the backend.** Plugin backends hold powerful tokens (cluster
  access, ArgoCD, billing). Source them from your secrets manager (ESO/Vault), never in
  `app-config` or the frontend.
- **Govern annotations.** A plugin only works if the entity is annotated. Bake the
  required annotations into the golden-path skeleton (Module 15.4) and validate them,
  so every service lights up every plugin by default.
- **Mind read-access scope.** The Kubernetes and ArgoCD plugins need read access across
  namespaces/apps. Use least-privilege, read-only service accounts.
- **Pin versions and test upgrades.** Plugins break across Backstage major upgrades.
  Pin, read changelogs, and test plugins against a canary before upgrading everyone.
- **Fail gracefully.** A down backend (Grafana, billing) should degrade the card, not
  the whole page. Prefer plugins that handle missing data cleanly.
- **Build custom plugins sparingly.** Each is owned code with an upgrade cost. Justify
  it against configuration or an existing community plugin first.

---

## 7. Common mistakes

- **Missing annotations, blank cards.** The plugin is installed but the entity lacks
  `argocd/app-name` or `kubernetes-id`, so it shows nothing. *Fix:* annotate in the
  skeleton and validate.
- **Secrets in the frontend or `app-config`.** Putting a cluster token where the
  browser or Git can see it. *Fix:* backend plugin + secrets manager.
- **Over-broad cluster access.** Granting the Kubernetes plugin cluster-admin. *Fix:*
  read-only, least-privilege service accounts.
- **Version drift.** Installing a plugin version that mismatches your Backstage
  backend. *Fix:* follow the plugin's versioned install guide; pin Backstage.
- **Building custom when official exists.** Reinventing the ArgoCD card. *Fix:* survey
  the ecosystem (core + Roadie) before writing code.
- **One giant entity page.** Twelve plugin cards nobody reads. *Fix:* curate the layout
  to the few signals developers actually use.

---

## 8. Assessment

**Knowledge checks**

1. What are the two halves of a typical Backstage plugin, and why does the backend
   exist?
2. How does a plugin know which ArgoCD app or which pods belong to a given entity?
3. Name the four plugins in this module and the earlier phase each one surfaces.
4. When is building a custom plugin justified, and what is its ongoing cost?

**Concept exercise**

> Explain how a developer portal shows live deployment, runtime, and cost on a service
> page **without naming Backstage or any plugin**. Describe where the data comes from
> and how the page knows which data belongs to which service.

**Architecture / trade-off exercise**

> Developers complain that half the service pages show empty ArgoCD and Kubernetes
> cards. You confirm the plugins are installed and configured correctly. Where is the
> problem most likely to be, how does it connect to Modules 15.3 and 15.4, and what is
> the systemic fix (not a per-service patch)?

<details>
<summary>Discussion</summary>

- **Q1:** A React **frontend** (cards/pages) and a Node **backend** that talks to the
  external system. The backend exists to hold credentials and do server-side calls so
  secrets never reach the browser.
- **Q2:** Through **annotations** on the entity's `catalog-info.yaml` (e.g.
  `argocd/app-name`, `backstage.io/kubernetes-id`) that the plugin reads to find its
  slice of data.
- **Q3:** ArgoCD → GitOps/delivery (Phase 8, Project 2); Kubernetes → runtime (Phase
  3/10, Project 1); Grafana → observability (Phase 11, Project 3); Cost → FinOps (Phase
  15).
- **Q4:** When no official/community plugin fits an internal system or bespoke view, or
  to surface your own platform API. The cost is owned code you must maintain and upgrade
  with Backstage.
- **Trade-off:** The entities are missing the required **annotations** (Module 15.3) —
  so the plugins have nothing to bind to. The systemic fix is to bake the annotations
  into the **golden-path skeleton** (Module 15.4) and validate them in CI, so every new
  and existing service is annotated by default, rather than patching pages one by one.

</details>

---

## 9. Further reading

- Backstage — [Plugins overview and marketplace](https://backstage.io/docs/plugins/)
- Backstage — [Kubernetes plugin](https://backstage.io/docs/features/kubernetes/)
- Backstage — [Cost Insights plugin](https://github.com/backstage/backstage/tree/master/plugins/cost-insights)
- Roadie — [ArgoCD and Grafana plugins](https://roadie.io/backstage/plugins/)
- Backstage — [Creating a Backstage plugin](https://backstage.io/docs/plugins/create-a-plugin)
- OpenCost — [Kubernetes cost monitoring](https://www.opencost.io/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [15.4 — Backstage Software Templates](../04-backstage-software-templates/)
· _Next:_ [15.6 — Golden Paths →](../06-golden-paths/)
