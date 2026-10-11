# Module 15.2 — Backstage Fundamentals

> Backstage is the open-source framework most teams reach for to build the **developer
> control plane** — the portal surface of the IDP you architected in Module 15.1. This
> module explains what Backstage is, why *every feature is a plugin*, how it is
> deployed (a Node.js app with a Postgres backend), how authentication works, and how
> to run it as a platform **product**. You will run it locally; cloud deployment is
> optional.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 15.1](../01-idp-architecture/), **Node.js 20+**, Yarn, and a
GitHub account (free). The lab's core runs on `localhost`; GKE is optional.

## Learning objectives

By the end of this module you will be able to:

- Explain what Backstage is, where it came from, and what it is *not*.
- Describe its **plugin architecture** and the four core features (Catalog, Templates,
  TechDocs, Search).
- Scaffold and run a Backstage app locally, and describe its Node.js + Postgres
  deployment shape.
- Configure an **identity provider** (GitHub) for sign-in.
- Treat Backstage as a platform **product**: versioning, upgrades, and a support model.

---

## 1. Concept

### What Backstage is (and is not)

**Backstage** is an open-source framework for building developer portals, created
inside **Spotify** to tame the sprawl of hundreds of services and teams, and donated
to the **CNCF** in 2020 (now a CNCF Incubating project). The key word is *framework*:
Backstage is not a finished product you install and use as-is. It is a React + Node.js
application skeleton that **you** scaffold, configure, extend with plugins, and
operate.

Hold on to the Module 01.4 warning: **the portal is not the platform.** Backstage is
(part of) the **developer control plane** — one client of the platform API you
designed in Module 15.1. It makes your catalog, golden paths, and runtime data
*visible and usable*; it does not, by itself, provision, deploy, or secure anything.
Installing Backstage no more gives you an IDP than buying a storefront gives you a
supply chain.

### Every feature is a plugin

Backstage's architecture is radical in one way: **everything is a plugin**, including
the core features. The app is a thin shell that composes plugins. This is why it is so
extensible — adding ArgoCD sync status or a cost widget (Module 15.5) is "install a
plugin," the same mechanism the core is built from.

Plugins come in two halves:

- **Frontend plugins** — React components that render pages and widgets in the UI.
- **Backend plugins** — Node.js services that talk to external systems (GitHub, your
  cluster, your CI) and expose APIs the frontend calls.

```text
            Backstage app (a thin shell)
   ┌──────────────────────────────────────────┐
   │  Frontend (React)        Backend (Node)   │
   │  ┌────────────┐          ┌─────────────┐  │
   │  │ catalog    │◄────────►│ catalog     │  │
   │  │ scaffolder │◄────────►│ scaffolder  │  │
   │  │ techdocs   │◄────────►│ techdocs    │  │
   │  │ search     │◄────────►│ search      │  │
   │  │ (your)     │          │ (your)      │  │
   │  └────────────┘          └─────────────┘  │
   └──────────────────────────────────────────┘
         every box above is a PLUGIN
```

### The four core features

Out of the box, the scaffolded app ships four plugins you will use constantly:

- **Software Catalog** — the live inventory of components, APIs, systems, and teams
  (Module 15.3). This is the backbone everything else hangs off.
- **Software Templates** (the *scaffolder*) — self-service "create a new service" that
  realizes golden paths (Module 15.4).
- **TechDocs** — docs-as-code: MkDocs documentation that lives in each repo and renders
  in the portal (Module 15.8).
- **Search** — across the catalog, docs, and more.

Those four map neatly onto the IDP capabilities from Module 01.4: *application
catalog*, *self-service provisioning*, *knowledge*, and *findability*.

### Deployment shape: a Node.js app with a Postgres backend

Backstage is, concretely, a **Node.js application**. For anything beyond a laptop demo
it needs a **PostgreSQL** database (the default in-memory SQLite is for local
development only — it is wiped on restart). The production shape is familiar:

```text
Browser ──► Backstage frontend (static) ──► Backstage backend (Node.js) ──► PostgreSQL
                                                   │
                                                   ├──► GitHub (catalog discovery, auth)
                                                   ├──► Kubernetes (plugin)
                                                   └──► ArgoCD / Grafana / … (plugins)
```

You containerize it and run it on Kubernetes like any other stateful-ish web app —
typically with the community **Helm chart**, backed by a managed Postgres (Cloud SQL
on GKE). The lab shows the local run in full and the Helm deploy as an optional step.

### Authentication

Backstage separates **sign-in** (who are you?) from **identity** (which catalog
`User`/`Group` are you, for ownership and access). For sign-in it supports pluggable
providers: **GitHub**, Google, GitLab, Okta, and generic **OIDC**. In the lab you will
wire up **GitHub OAuth**, because it doubles as the credential for catalog discovery
and the scaffolder's `publish:github` step later.

> Local development has a **guest** sign-in so you can explore without any provider.
> Never enable guest access on a shared or internet-facing instance.

### Backstage as a platform product

Backstage is itself software your platform team owns — so Module 01's product
discipline applies to it directly:

- **Versioning and upgrades.** Backstage releases frequently (roughly monthly). You
  pin a version and upgrade deliberately using the official `backstage-cli` upgrade
  helper and the changelog. Falling years behind makes plugins and security fixes
  painful.
- **A support model.** A support channel, office hours, and docs — "knowledge and
  support" are in the platform definition for a reason.
- **An internal changelog.** When you add a plugin or change a golden path, your
  developers are consumers; tell them what changed.

---

## 2. Why it matters for platform engineering

Backstage is the most common realization of the developer control plane, so knowing
its shape — framework, plugins, Node.js + Postgres, pluggable auth — is core platform
literacy. But the deeper reason this module matters is **discipline**: it is easy to
mistake "we installed Backstage" for "we have an IDP." Keeping Backstage in its place —
a swappable client of your platform API — is what stops you from building the
ticket-queue-with-nicer-fonts anti-pattern.

Running it locally also demystifies it. Once you have scaffolded the app and watched
the catalog, scaffolder, and TechDocs load from local config, the rest of the phase
(and Project 4) becomes concrete: you are no longer configuring a black box, you are
composing plugins on a Node app you understand.

---

## 3. Mental model

```text
          BACKSTAGE = a React+Node SHELL that COMPOSES PLUGINS
          ────────────────────────────────────────────────────

  framework, not product   →  you scaffold + operate it (it is YOUR app)
  every feature is a plugin →  core = catalog, scaffolder, techdocs, search
  deployment               →  Node.js app + PostgreSQL, on Kubernetes (Helm)
  auth                     →  pluggable sign-in (GitHub/OIDC) + catalog identity
  its place                →  the developer CONTROL PLANE — ONE client of the
                              platform API; "the portal is not the platform"

  Run order you will follow: scaffold → run locally → add auth → (optional) deploy
```

One sentence: **Backstage is a plugin-composed Node.js app you operate as a product to
present your platform — not the platform itself.**

---

## 4. Minimal implementation

The smallest real Backstage is one command plus a run. It creates a monorepo with the
four core plugins already wired:

```bash
# Node.js 20+ required. Scaffold a new app (interactive: it asks for an app name).
npx @backstage/create-app@latest

cd my-backstage-app
yarn install

# Run frontend + backend together (uses local SQLite + guest auth)
yarn dev
# → open http://localhost:3000  (frontend)  / backend on :7007
```

What you get is already a working portal: a Software Catalog seeded with an example
component, the scaffolder, TechDocs, and search — all composed in a handful of files:

```text
my-backstage-app/
├── app-config.yaml          # the main config: auth, catalog, integrations
├── packages/
│   ├── app/                 # the FRONTEND (React) — composes frontend plugins
│   └── backend/             # the BACKEND (Node.js) — composes backend plugins
└── examples/                # sample catalog entities + a sample template
```

Everything in this phase is edits to `app-config.yaml` and `packages/*` — adding
integrations, auth providers, catalog locations, and plugins. The lab walks the full
local run; cloud comes later and only if you want it.

---

## 5. Hands-on lab

You will scaffold a Backstage app with `npx @backstage/create-app`, run it on
`localhost`, explore the four core plugins, and wire up **GitHub sign-in**. Optional,
clearly marked steps show pointing it at a **PostgreSQL** backend and deploying to
**GKE** with the community **Helm chart** using the provided
[`backstage-values.yaml`](./lab/backstage-values.yaml).

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Always use PostgreSQL.** SQLite is development-only and non-durable. Back
  production with managed Postgres (Cloud SQL) and real backups.
- **Have an upgrade cadence.** Backstage moves fast. Schedule regular upgrades with the
  `backstage-cli` and read the changelog; do not let the version rot.
- **Lock down auth.** Disable guest access everywhere but local dev, scope OAuth apps
  correctly, and map sign-in to catalog `User`/`Group` identity for ownership.
- **Run it like a real service.** HA replicas, health checks, resource limits,
  observability (it is a Node app — scrape it), and an SLO. The portal going down
  blocks every developer who depends on it.
- **Secure the backend's credentials.** Its GitHub token and cluster access are
  powerful; store them with your secrets manager (ESO/Vault), never in `app-config`.
- **Treat it as a product.** Changelog, support channel, and adoption metrics — a
  portal nobody opens is a failed product (Module 01.1).

---

## 7. Common mistakes

- **"We installed Backstage, so we have an IDP."** The portal is one plane's surface,
  not the platform. *Fix:* keep the five-planes and API-first view from Modules 01.4
  and 15.1.
- **Running on SQLite in production.** Data vanishes on restart and it does not scale.
  *Fix:* PostgreSQL from the first shared deployment.
- **Never upgrading.** Falling many releases behind makes every future plugin and
  security patch a slog. *Fix:* a regular, boring upgrade cadence.
- **Leaving guest auth on.** An unauthenticated internal portal leaks your whole
  service inventory. *Fix:* a real identity provider; guest only on localhost.
- **Hand-editing in production.** Treating the running portal as config-by-clicking.
  *Fix:* it is a Node app in Git — change it via code review and redeploy.
- **Secrets in `app-config.yaml`.** Committing the GitHub token or DB password. *Fix:*
  environment variables sourced from your secrets manager.

---

## 8. Assessment

**Knowledge checks**

1. Why is Backstage described as a *framework* rather than a product, and what does
   that imply for your team's workload?
2. What does "every feature is a plugin" mean, and how do frontend and backend plugins
   differ?
3. Name the four core plugins and the IDP capability each provides.
4. What are the two data/runtime dependencies a production Backstage needs beyond the
   Node.js app itself?

**Concept exercise**

> Explain the role Backstage plays in an IDP **without using the words "Backstage" or
> "portal."** Describe what it presents, what it does *not* do, and why it is
> interchangeable.

**Architecture / trade-off exercise**

> A teammate proposes clicking around the running Backstage UI to configure the
> catalog and auth "so we can move fast." Explain why that fights Backstage's design
> and the platform-product principles, and describe the workflow you would use
> instead.

<details>
<summary>Discussion</summary>

- **Q1:** It ships as a scaffolded app you must configure, extend, and operate — so it
  is *your* application with real ownership, upgrade, and support cost, not a
  turnkey tool.
- **Q2:** The whole app is composed of plugins, including the core features. Frontend
  plugins are React UI; backend plugins are Node services that integrate external
  systems and expose APIs the frontend consumes.
- **Q3:** Software Catalog (application catalog), Software Templates/scaffolder
  (self-service provisioning), TechDocs (knowledge/docs), Search (findability).
- **Q4:** A **PostgreSQL** database and the **external systems** its backend plugins
  integrate (GitHub, the cluster, CI). SQLite + no integrations is a laptop demo only.
- **Trade-off:** Backstage config lives in code (`app-config.yaml`, `packages/*`) and
  is meant to be versioned, reviewed, and redeployed. Click-configuring is not
  reproducible, is lost on redeploy, and breaks the product discipline; instead, make
  changes in Git, review them, and roll them out — the same way you treat the
  platform itself.

</details>

---

## 9. Further reading

- Backstage — [Getting started and `create-app`](https://backstage.io/docs/getting-started/)
- Backstage — [Backstage architecture overview](https://backstage.io/docs/overview/architecture-overview)
- Backstage — [Authentication and identity](https://backstage.io/docs/auth/)
- Backstage — [Deploying with the community Helm chart](https://github.com/backstage/charts)
- CNCF — [Backstage project](https://www.cncf.io/projects/backstage/)
- Spotify Engineering — [Backstage origin story](https://backstage.io/blog/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [15.1 — IDP Architecture](../01-idp-architecture/)
· _Next:_ [15.3 — Backstage Software Catalog →](../03-backstage-software-catalog/)
