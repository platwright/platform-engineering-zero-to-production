# Project 4 — Internal Developer Platform

> Build a fully functional **Internal Developer Platform**: a Backstage portal where a
> developer requests a new service and the platform scaffolds everything — repo,
> CI/CD, GitOps deployment, namespace with RBAC and quota, secrets, and dashboards —
> integrating the capabilities from Projects 1–3 behind a single golden path.

This is the capstone of the core curriculum. It builds on
[Phase 12 · Developer Experience and IDP](../../15-developer-experience-and-idp/)
(which taught Backstage, catalog, templates, plugins, golden paths, the CLI, and docs)
and wires together [Project 1](../../04-platform-project-01/) (the cluster),
[Project 2](../../09-platform-project-02/) (GitOps), and
[Project 3](../../12-platform-project-03/) (observability). As before, you build it in
**two passes**.

---

## The two-pass approach

```text
PASS 1 — Build it now (free, local)
  • Run Backstage locally (Node.js) with a software catalog
  • Register Components / APIs / Systems / Groups from catalog-info.yaml
  • TWO golden-path templates: a Go microservice and a Python/FastAPI service
  • Scaffold a service from a template → it produces a repo skeleton with CI,
    a Helm/Kustomize deploy, a GitOps overlay, and a catalog-info.yaml
  • The new service's GitOps overlay lands in the Project 2 config repo → ArgoCD
    deploys it (closing the loop from portal to production)

PASS 2 — Deploy for real (as cloud/accounts allow)
  • Backstage on GKE with GitHub authentication                 → Phase 12 / Project 1
  • Catalog auto-populated via GitHub org discovery
  • Plugins: ArgoCD, Kubernetes, Grafana, Cost Insights (Kubecost)→ Projects 2, 3; Phase 14
  • TechDocs rendered from service repositories (MkDocs)         → Module 15.8
  • Backstage itself delivered by GitOps                         → Project 2
```

---

## Target architecture

```text
   Developer
      │  "Create a service" (fills a short form)
      ▼
   Backstage Portal
      ├─ Software Catalog   (every service, API, system, team — who owns what)
      ├─ Software Templates (Go microservice, Python/FastAPI service)   ← golden paths
      ├─ TechDocs           (docs-as-code rendered from each repo)
      └─ Plugins            (ArgoCD · Kubernetes · Grafana · Cost Insights)
      │
      │  the Go/Python template scaffolds and wires:
      ▼
   ┌──────────────── one self-service action produces ────────────────┐
   │ GitHub repo (skeleton: app, Dockerfile, CI, Helm, catalog-info)   │
   │ CI/CD pipeline (build → scan → sign → push)       → Project 1/Phase 5 │
   │ GitOps overlay in the config repo                 → Project 2      │
   │ Namespace + RBAC + ResourceQuota                  → Project 1      │
   │ Secrets via ESO + Secret Manager                  → Projects 1/2   │
   │ Observability wired in (OTel SDK + dashboards)    → Project 3      │
   └───────────────────────────────────────────────────────────────────┘
      │
      ▼
   Platform foundation (Projects 1–3): GKE + Terraform · ArgoCD · LGTM ·
   Kyverno · Cilium + Gateway API · External Secrets Operator
```

This project is the **developer control plane** and the integration layer that ties
the other four planes together — the realization of the five-plane model from
[Module 01.4](../../01-platform-foundations/04-the-internal-developer-platform/README.md).

See [architecture/architecture.md](./architecture/architecture.md) for the full
component inventory and the decisions behind it.

---

## Requirements

From the course outline. The **Pass** column shows what you build now vs later.

| # | Requirement | Pass | Taught in |
|---|-------------|------|-----------|
| 1 | Two golden-path templates (Go service, Python/FastAPI service) | **1** | [Module 15.4](../../15-developer-experience-and-idp/04-backstage-software-templates/) |
| 2 | A software catalog of services/APIs/systems/teams | **1** | [Module 15.3](../../15-developer-experience-and-idp/03-backstage-software-catalog/) |
| 3 | Scaffolding wires repo + CI + GitOps overlay + catalog entry | **1** | [Modules 15.4](../../15-developer-experience-and-idp/04-backstage-software-templates/), [Project 2](../../09-platform-project-02/) |
| 4 | Backstage deployed on GKE with GitHub auth | 2 | [Module 15.2](../../15-developer-experience-and-idp/02-backstage-fundamentals/) |
| 5 | Catalog auto-populated from the GitHub org | 2 | [Module 15.3](../../15-developer-experience-and-idp/03-backstage-software-catalog/) |
| 6 | ArgoCD, Kubernetes, Grafana, Cost Insights plugins | 2 | [Module 15.5](../../15-developer-experience-and-idp/05-backstage-plugins/) |
| 7 | TechDocs rendered from 3+ service repos | 2 | [Module 15.8](../../15-developer-experience-and-idp/08-developer-portal-documentation/) |
| 8 | Backstage delivered via GitOps | 2 | [Project 2](../../09-platform-project-02/) |

**Stretch goals:** a custom plugin for internal incident history; the
[`platform` CLI](../../15-developer-experience-and-idp/07-platform-cli-tools/) wired to
`env create`/`deploy`; a scaffolder action that provisions cloud resources via
Crossplane.

---

## Prerequisites

- Completed [Phase 12](../../15-developer-experience-and-idp/) and
  [Projects 1–3](../../12-platform-project-03/).
- Tools: **Node.js 20+** and **Yarn** (for Backstage), plus `git`, `kubectl`, `kind`,
  `helm`. For Pass 2: `gcloud`, a GitHub org, and the Project 2 GitOps platform.

---

## Build it

The full, staged walkthrough is the project's build guide:

➡️ **[Build guide — step by step](./build-guide.md)**

Quick start:

```bash
# From this project directory
./scripts/bootstrap.sh      # scaffold + run Backstage locally with the course catalog & templates
# ... open http://localhost:3000, scaffold a service from a golden path ...
./scripts/cleanup.sh        # remove the local Backstage app
```

---

## Repository layout

```text
internal-developer-platform/
├── README.md                 # you are here
├── build-guide.md            # the staged build walkthrough
├── architecture/
│   ├── architecture.md       # full architecture + component inventory
│   ├── decisions/            # ADRs (why Backstage, template strategy, docs-as-code)
│   └── diagrams/
├── backstage/
│   ├── README.md             # how the config maps to the five planes
│   ├── app-config.idp.yaml   # catalog, integrations, TechDocs, auth (Pass 2)
│   └── catalog/              # the org catalog: systems, groups, components
├── golden-paths/
│   ├── README.md
│   ├── go-microservice/      # scaffolder template + skeleton (CI, Helm, GitOps overlay)
│   └── python-fastapi/       # scaffolder template + skeleton
├── config-repo/              # how a scaffolded service lands in GitOps (ties to Project 2)
├── docs/
│   ├── onboarding.md         # the zero-to-production developer journey
│   └── runbooks/
└── scripts/
    ├── bootstrap.sh          # scaffold + run Backstage locally
    └── cleanup.sh
```

---

## Portfolio-ready checklist

This project is portfolio-ready (and "done" for Pass 1) when you can tick:

- [ ] Clear problem statement and architecture diagram in the README
- [ ] Backstage runs with a populated **software catalog** (systems, groups, components)
- [ ] **Two** golden-path templates (Go, Python) that scaffold a complete service
- [ ] Scaffolding produces a skeleton with app, Dockerfile, CI, Helm, GitOps overlay,
      and `catalog-info.yaml`
- [ ] A scaffolded service's GitOps overlay is picked up by ArgoCD (Project 2)
- [ ] A documented [onboarding journey](./docs/onboarding.md): form → running service
- [ ] At least one [ADR](./architecture/decisions/) explaining a key decision
- [ ] Cleanup leaves nothing running

Pass 2 adds: Backstage on GKE with GitHub auth, the four plugins, TechDocs from real
repos, catalog auto-discovery, and GitOps delivery of Backstage itself.

---

## Architecture decisions

- [ADR-007 — Why Backstage over Port/Cortex/custom](./architecture/decisions/ADR-007-why-backstage.md)
- [ADR-018 — Golden-path template strategy (one skeleton, versioned)](./architecture/decisions/ADR-018-golden-path-template-strategy.md)
- [ADR-019 — Docs-as-code with TechDocs](./architecture/decisions/ADR-019-techdocs-docs-as-code.md)

---

_Previous:_ [15 · Developer Experience and IDP](../../15-developer-experience-and-idp/)
· _Next:_ [17 · Platform SRE](../../17-platform-sre/)
