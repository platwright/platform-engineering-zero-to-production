# Golden-path templates

> These are the **golden paths** ([Module 15.6](../../../15-developer-experience-and-idp/06-golden-paths/)):
> the supported, opinionated, self-service way to create a new service. A developer
> picks one in Backstage, fills a short form, and gets a **complete, hardened,
> observable, deployable** service — not a hello-world stub. This is where the IDP
> actually removes cognitive load.

## What's here

| Template | Stack | Produces |
|----------|-------|----------|
| [`go-microservice/`](./go-microservice/) | Go (net/http) | App, Dockerfile, CI, Helm chart, GitOps overlay, catalog-info, docs |
| [`python-fastapi/`](./python-fastapi/) | Python (FastAPI) | App, Dockerfile, CI, Helm chart, GitOps overlay, catalog-info, docs |

Each template is a Backstage **scaffolder** `Template` (`template.yaml`) plus a
`skeleton/` directory that gets rendered with the developer's inputs.

## What every golden path includes (the checklist)

A golden path is only "golden" if it wires up the whole path to production. Each
skeleton here ships, by default:

```text
[x] Repository scaffold          app + Dockerfile + README
[x] CI/CD pipeline               build → scan → sign → push (Phase 5 / Project 1)
[x] Hardened container           non-root, read-only, dropped caps (Project 1)
[x] GitOps deployment config     a Kustomize overlay for the Project 2 config repo
[x] Observability                OTel SDK env + a default dashboard reference (Project 3)
[x] Catalog registration         catalog-info.yaml so it self-registers (Module 15.3)
[x] Documentation                mkdocs.yml + docs/ for TechDocs (Module 15.8)
```

That checklist is the course's golden-path definition
([Module 15.6](../../../15-developer-experience-and-idp/06-golden-paths/)) made concrete.

## How the placeholders work

Skeleton files contain Backstage scaffolder placeholders like `${{ values.name }}`.
When a developer runs the template, the scaffolder **renders** these with the form
inputs and publishes the result as a new repo. So the files here are *templates* — for
example, `skeleton/go.mod` has a placeholder module path that becomes real on scaffold.

## Versioning

Templates are **versioned** and treated as a product
([ADR-018](../architecture/decisions/ADR-018-golden-path-template-strategy.md)). Teams
adopt a known-good version; improvements ship as a new version with a migration path —
the "templates as a product" idea from
[Module 06.4](../../../06-cicd-for-platform-teams/04-pipeline-templates-as-product/).
