# 15 · Developer Experience and IDP

> Back in [Module 01.4](../01-platform-foundations/04-the-internal-developer-platform/)
> you learned the **five planes** of an Internal Developer Platform and the rule that
> *the platform API is the product, not the portal*. In [Module 01.3](../01-platform-foundations/03-developer-experience/)
> you learned about **golden paths** and measured time-to-first-production-deployment.
> This phase is where those ideas stop being theory. You will build the **developer
> control plane** — Backstage, a software catalog, golden-path templates, plugins, a
> `platform` CLI, and docs-as-code — that turns the capabilities from Projects 1–3
> into genuine self-service.

**Phase 12 · 8 modules · ~16–24 hours**

## Why developer experience and an IDP now?

Everything you have built so far is powerful but **not yet self-service**. In
[Project 1](../04-platform-project-01/) you onboarded a team by hand: you created the
namespace, the RBAC, and the quota yourself. In [Project 2](../09-platform-project-02/)
you delivered new services through GitOps, but someone still wrote the ArgoCD
`Application` and the manifests. In [Project 3](../12-platform-project-03/) you wired
in observability — but a developer who wants a dashboard still copies one from
another repo. Every one of those is a **ticket waiting to happen**, and a ticket for
routine work is the bottleneck platform engineering exists to remove.

This phase closes the loop. It builds the plane that sits in front of all the others:

- **The developer control plane.** The portal, catalog, templates, and CLI that let a
  developer *ask for* a new service — and get it, fully wired, without a ticket.
- **Golden paths, realized.** The paved road from [Module 01.3](../01-platform-foundations/03-developer-experience/)
  becomes a concrete template that scaffolds a repo, a pipeline (the
  [templates-as-product](../06-cicd-for-platform-teams/04-pipeline-templates-as-product/)
  work from Phase 6), GitOps config, observability, and docs in one click.
- **The catalog.** A live inventory answering "what exists, who owns it, where it
  runs, and is it healthy?" — the question Slack currently answers badly.
- **Docs-as-code.** Documentation that lives with the service and renders in the
  portal, so the paved road is also well-lit.

Keep two sentences from Module 01.4 in your pocket the whole way through: **the
portal is not the platform**, and **the platform API is the product**. Backstage is
*one* client of a platform you already mostly built — this phase wires it up and adds
the interface.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [IDP Architecture](./01-idp-architecture/) | The five planes realized; platform API design; convention over configuration; build vs buy. | An IDP architecture + platform-API design worksheet. |
| 2 | [Backstage Fundamentals](./02-backstage-fundamentals/) | Backstage's plugin architecture and core features; running it locally; auth; optional GKE deploy. | A Backstage app running on `localhost:3000`. |
| 3 | [Backstage Software Catalog](./03-backstage-software-catalog/) | Catalog entities and relationships; `catalog-info.yaml`; GitHub discovery; catalog health. | A multi-entity catalog (Component/API/System/Group) imported into Backstage. |
| 4 | [Backstage Software Templates](./04-backstage-software-templates/) | The scaffolder: parameters and steps; `fetch:template`, `publish:github`, `catalog:register`. | A Go-microservice golden-path template + skeleton. |
| 5 | [Backstage Plugins](./05-backstage-plugins/) | ArgoCD, Kubernetes, Grafana, and Cost Insights plugins; a note on custom plugins. | A component page showing live deploy, cluster, and cost data. |
| 6 | [Golden Paths](./06-golden-paths/) | What an end-to-end golden path must include; escape hatches; versioning; adoption metrics. | A golden-path definition + readiness checklist. |
| 7 | [Platform CLI Tools](./07-platform-cli-tools/) | When to build a CLI; Go + Cobra + Viper; config, completions; the CLI is a thin API client. | A compiling `platform` CLI skeleton (env/deploy/logs). |
| 8 | [Developer Portal Documentation](./08-developer-portal-documentation/) | TechDocs + MkDocs; docs-as-code; ADRs; runbook standards. | A TechDocs site (`mkdocs.yml` + `docs/`) with an ADR and a runbook. |

Work them in order — each builds on the last. Modules 2–5 stand up Backstage and fill
it with a catalog, templates, and plugins; Module 6 ties them into a single golden
path; Modules 7–8 add the CLI and the documentation layer that make the path usable
and well-lit.

## Learning objectives

By the end of this phase you will be able to:

- Map a real IDP onto the **five planes** and design a **stable, versioned platform
  API** that interfaces sit on top of.
- Stand up **Backstage** locally, wire up authentication, and reason about running it
  as a platform product (versioning, support, optional cloud deployment).
- Model your systems in the **software catalog** with correct entity relationships and
  automatic GitHub discovery, and keep the catalog healthy.
- Build a **golden-path software template** that scaffolds a production-ready service
  end to end, with escape hatches, versioning, and adoption metrics.
- Enrich the portal with **plugins** (ArgoCD, Kubernetes, Grafana, Cost) so a service
  page shows live delivery, runtime, and cost.
- Build a **platform CLI** in Go + Cobra that wraps the platform API, and publish
  **docs-as-code** (TechDocs, ADRs, runbooks) that render in the portal.

## Prerequisites

- [Phase 1 · Platform Foundations](../01-platform-foundations/) — especially
  [Developer Experience](../01-platform-foundations/03-developer-experience/) and
  [The Internal Developer Platform](../01-platform-foundations/04-the-internal-developer-platform/).
  This phase is the hands-on realization of both.
- [Phase 6 · CI/CD](../06-cicd-for-platform-teams/) — the
  [pipeline-templates-as-product](../06-cicd-for-platform-teams/04-pipeline-templates-as-product/)
  mindset carries directly into software templates.
- [Projects 1–3](../04-platform-project-01/) — the capabilities you are about to put
  behind self-service (namespaces, GitOps delivery, observability).
- Tools: **Node.js 20 or newer** (for Backstage), **Go 1.22+** (for the CLI lab),
  Docker, and `kubectl`. A GitHub account (free) is used for auth and discovery.

## A note on cost

The core of every lab runs **free on your laptop**: Backstage scaffolds and runs on
`localhost`, the catalog and templates are local YAML, and the CLI builds locally.
Steps that touch a cloud — deploying Backstage to **GKE** with Helm, GitHub OAuth, or
live ArgoCD/Grafana plugins — are **clearly marked optional**, with account and cost
notes, and are never required to complete the lab. Always run each lab's **Cleanup**
section.

## Up next: Project 4

This phase is the final build-up before **[Project 4 · Internal Developer
Platform](../16-platform-project-04/)** — where you assemble Backstage, the
catalog, golden-path templates, plugins, and the CLI into one working IDP on GKE that
ties together every capability from Projects 1–3. Treat each lab here as a component
you will integrate there: the catalog you model, the template you write, and the CLI
you scaffold are the actual pieces of your Project 4 platform. Keep them.

---

Start with [**15.1 · IDP Architecture →**](./01-idp-architecture/)
