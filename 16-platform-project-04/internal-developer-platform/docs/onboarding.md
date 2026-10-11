# Onboarding — the zero-to-production developer journey

> This is the journey the IDP exists to make effortless: a developer going from "I need
> a service" to "it's running in production" — without filing a ticket or learning the
> platform's internals. It's the concrete payoff of everything in the course.

## The journey (what the developer experiences)

```text
   1. Open Backstage → click "Create"
   2. Pick a golden path: Go Microservice or Python FastAPI Service
   3. Fill a short form: name, description, owning team, repo
   4. Click "Create"
        ↓  (the platform does the rest)
   5. A GitHub repo appears, pre-wired with:
        app code · hardened Dockerfile · CI (build→scan→sign→push) ·
        a GitOps overlay · catalog-info.yaml · docs
   6. The service self-registers in the catalog (owner, docs, links)
   7. The GitOps overlay lands in the config repo → ArgoCD deploys it to dev
   8. The service is running, observable (metrics/logs/traces), and documented
   Total elapsed: minutes.
```

Compare this to the "Time to Hello World in Production" audit from
[Module 01.3](../../../01-platform-foundations/03-developer-experience/README.md) — the
nine-day, five-ticket journey the IDP replaces.

## What the developer did NOT have to do

They never touched — or needed to understand:

- Terraform, the cluster, namespaces, RBAC, or quotas (Project 1)
- ArgoCD, Kustomize overlays, or promotion flow (Project 2)
- OpenTelemetry wiring or dashboard creation (Project 3)
- Dockerfile hardening, Trivy, or Cosign (Phases 2, 5, 10)
- Kyverno policies or External Secrets (Phases 10, Project 1)

All of that is encoded in the golden path and the platform baseline. **Removing that
cognitive load is the product** (Module 01.1).

## What the platform team maintains

The flip side: the platform team owns the golden paths and the baseline so every team
inherits them. Onboarding a new *team* (vs a new service) adds:

- A `Group` entity in the catalog ([`org.yaml`](../backstage/catalog/org.yaml)).
- The team's namespaces with RBAC + quota (Project 1's
  [onboarding runbook](../../../04-platform-project-01/container-platform-foundation/docs/onboarding.md)).
- Optionally, a GitHub team and a Slack channel.

Doing this by hand is fine at first; the platform-engineering move is to make *team*
onboarding self-service too — the subject of
[Capstone 2](../../../21-capstone-projects/) ("a new team, zero-to-prod in under 30
minutes").

## Definition of done (a service is onboarded)

- [ ] Scaffolded from a golden path (not hand-assembled).
- [ ] Repo has app, hardened Dockerfile, CI, GitOps overlay, catalog-info, docs.
- [ ] Appears in the software catalog with the correct owner.
- [ ] Deployed to dev by ArgoCD (GitOps overlay picked up).
- [ ] Emitting metrics/logs/traces to the observability platform.
- [ ] Docs render in the portal (TechDocs, Pass 2).

## Measuring it (treat the IDP as a product)

Track the Phase 1 metrics for the IDP itself:

- **Time-to-first-production-deploy** for a new service (target: minutes).
- **Golden-path adoption**: % of new services created via a template.
- **Developer satisfaction** (NPS) with the onboarding experience.

If these aren't improving, the golden path isn't actually the easiest route — fix the
product, don't mandate its use (Module 01.2).
