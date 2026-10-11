# Architecture — Internal Developer Platform

This document describes the Internal Developer Platform (IDP): what it's made of, how a
self-service request flows from the portal to a running service, and the reasoning
behind the design. Decisions with meaningful trade-offs are captured as
[ADRs](./decisions/).

## Problem statement

Projects 1–3 gave the platform real power — a hardened cluster, GitOps delivery, and
observability. But a developer who wants to ship a new service still has to understand
Terraform, ArgoCD, Kustomize, Kyverno, ESO, and OpenTelemetry, and assemble a repo,
pipeline, deployment, namespace, secrets, and dashboards by hand. That's exactly the
**extraneous cognitive load** platform engineering exists to remove
([Module 01.1](../../../01-platform-foundations/01-what-is-platform-engineering/README.md)).
The IDP packages all of it behind a **golden path**: a form, then self-service.

## Design goals

- **Self-service, not tickets.** A developer creates a production-ready service without
  filing a ticket or waiting on the platform team
  ([Module 01.3](../../../01-platform-foundations/03-developer-experience/README.md)).
- **The paved road is the easy road.** The golden path is the simplest way to get a
  service, so teams choose it — adoption by attraction, not mandate.
- **Integration, not reinvention.** The IDP *wires together* Projects 1–3; it does not
  replace them. Backstage is the control plane; the capabilities live beneath it.
- **The platform API is the product.** Scaffolding emits declarative artifacts (repo,
  GitOps overlay, catalog entry); the portal is one client of that contract
  ([Module 01.4](../../../01-platform-foundations/04-the-internal-developer-platform/README.md)).
- **Observable and secure by default.** A scaffolded service ships hardened and
  instrumented — not as an afterthought.

## The self-service flow

```text
   Developer opens Backstage → "Create a service" → picks Go or Python, fills a form
        │
        ▼
   Scaffolder runs the template's steps:
        ├─ fetch:template      render the skeleton with the developer's inputs
        ├─ publish:github       create the repo (app, Dockerfile, CI, Helm, docs)
        ├─ (open a PR to the config repo adding the service's GitOps overlay)
        └─ catalog:register     add the service to the software catalog
        │
        ▼
   CI builds→scans→signs→pushes the image (Phase 5 / Project 1)
   ArgoCD sees the new overlay and deploys it (Project 2)
   Namespace + RBAC + quota + ESO secret + dashboards are in place (Projects 1, 3)
        │
        ▼
   The service is running, observable, and in the catalog — minutes after the form.
```

This is the IDP developer journey from
[Module 01.4](../../../01-platform-foundations/04-the-internal-developer-platform/README.md),
made real on the platform you built.

## Component inventory

| Component | Role | Pass | From |
|-----------|------|:----:|------|
| Backstage portal | The developer control plane (catalog, templates, docs) | **1** | [Module 15.2](../../../15-developer-experience-and-idp/02-backstage-fundamentals/) |
| Software catalog | Inventory: who owns what, where it runs | **1** | [Module 15.3](../../../15-developer-experience-and-idp/03-backstage-software-catalog/) |
| Golden-path templates | Scaffolders for Go and Python services | **1** | [Module 15.4](../../../15-developer-experience-and-idp/04-backstage-software-templates/) |
| Service skeletons | App + Dockerfile + CI + Helm + GitOps overlay + catalog-info | **1** | this project |
| GitOps config repo | Where scaffolded overlays land; ArgoCD delivers them | **1** | [Project 2](../../../09-platform-project-02/) |
| GitHub auth | Developer identity in Backstage | 2 | [Module 15.2](../../../15-developer-experience-and-idp/02-backstage-fundamentals/) |
| ArgoCD plugin | Sync status on the service page | 2 | [Module 15.5](../../../15-developer-experience-and-idp/05-backstage-plugins/) |
| Kubernetes plugin | Live pods/deployments on the service page | 2 | [Module 15.5](../../../15-developer-experience-and-idp/05-backstage-plugins/) |
| Grafana plugin | Embedded dashboards (Project 3) | 2 | [Module 15.5](../../../15-developer-experience-and-idp/05-backstage-plugins/) |
| Cost Insights plugin | Per-team cost (OpenCost/Kubecost) | 2 | [Phase 14 · FinOps](../../../18-finops-and-cost-engineering/) |
| TechDocs | Docs-as-code rendered from repos | 2 | [Module 15.8](../../../15-developer-experience-and-idp/08-developer-portal-documentation/) |

## Golden-path templates

Two templates ship in Pass 1, each producing a **complete, hardened, observable**
service skeleton — not just a code stub:

```text
golden-paths/
├── go-microservice/
│   ├── template.yaml      # Backstage scaffolder: parameters + steps
│   └── skeleton/          # app (main.go), Dockerfile, CI workflow, Helm chart,
│                          # GitOps overlay, catalog-info.yaml, mkdocs docs
└── python-fastapi/
    ├── template.yaml
    └── skeleton/          # app (FastAPI), Dockerfile, CI, Helm, overlay, catalog, docs
```

Each skeleton bakes in the course's defaults: a non-root/read-only container
(Projects 1/2), a build→scan→sign→push CI pipeline (Phase 5), a Kustomize overlay that
drops into the Project 2 config repo, OTel instrumentation (Project 3), and a
`catalog-info.yaml` so the service self-registers. See
[ADR-018](./decisions/ADR-018-golden-path-template-strategy.md).

## How a scaffolded service reaches production

The template's output is the input to the platform you already built:

1. The **repo skeleton** has a CI workflow that builds, scans, signs, and pushes the
   image by digest (Project 1 / Phase 5).
2. The template adds a **GitOps overlay** under the service's path in the
   [Project 2 config repo](../../../09-platform-project-02/); ArgoCD's ApplicationSet
   generates an Application for it and deploys it (dev auto-syncs, prod is gated).
3. The namespace, RBAC, quota, ESO secret, and dashboards come from the platform
   baseline (Projects 1 and 3) — the service inherits them.

The developer did none of this by hand. That's the product.

## Security & governance posture

- Scaffolded services are hardened by default (non-root, read-only, signed images) —
  and Kyverno (Module 13.3) *enforces* it, so even a hand-edited service can't regress.
- The catalog gives **ownership** for every component (who to page), a security and
  operational control in itself.
- Templates are **versioned**; teams adopt a known-good version and migrate
  deliberately (ADR-018) — the "pipeline templates as a product" idea (Module 06.4)
  applied to whole services.
- Backstage auth (Pass 2) ties portal actions to real identities.

## Known limitations

- Pass 1 runs Backstage locally with a static catalog and local scaffolding; it
  doesn't publish to a real GitHub org or auto-discover (that's Pass 2).
- The plugins (ArgoCD/Kubernetes/Grafana/Cost) and TechDocs need the live Pass-2 stack.
- This project delivers the *mechanism*; getting to "a new team, zero-to-prod in under
  30 minutes" end-to-end is [Capstone 2](../../../21-capstone-projects/).

## Production considerations

- **Treat the portal as a product with a roadmap** (Phase 1): measure golden-path
  adoption, gather developer feedback, and version templates.
- **The IDP is now critical infrastructure.** Give Backstage its own SLOs and on-call
  (Phase 13); if the portal is down, onboarding stops.
- **Keep the catalog accurate.** Automate discovery and staleness detection, or the
  catalog rots into fiction.
- **Escape hatches matter.** Let teams deviate from the golden path when they genuinely
  must, rather than forcing every case through the template.

## Decisions

See the [ADRs](./decisions/):

- [ADR-007 — Why Backstage over Port/Cortex/custom](./decisions/ADR-007-why-backstage.md)
- [ADR-018 — Golden-path template strategy](./decisions/ADR-018-golden-path-template-strategy.md)
- [ADR-019 — Docs-as-code with TechDocs](./decisions/ADR-019-techdocs-docs-as-code.md)
