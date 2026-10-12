# Capstone 2 — Full IDP with Backstage

> Build a fully functional Internal Developer Platform that can onboard a **new
> engineering team from zero to their first production deployment in under 30
> minutes** — entirely self-service. This takes Project 4 from "scaffold a service" to
> "stand up a whole team and ship," with the automation that makes the 30-minute
> promise real.

**Type:** Capstone (portfolio build)
**Estimated effort:** ~40–60 hours
**Builds on:** [Project 4](../../16-platform-project-04/) and
[Phase 12 · Developer Experience and IDP](../../15-developer-experience-and-idp/).

## Goal

An IDP where a platform engineer creates a team with one command and a developer, minutes
later, scaffolds a production-ready service through the portal — repo, pipeline, GitOps
deployment, namespace, secrets, dashboards, and on-call all wired automatically. The
north-star metric is **time-to-first-production-deployment for a brand-new team: under
30 minutes** ([Module 01.3](../../01-platform-foundations/03-developer-experience/)).

## The onboarding journey to build

```text
Platform engineer runs:
   platform team create --name payments --members alice,bob,charlie
        ↓  (automation)
   Backstage Group entity created
   GitHub team created
   Namespace provisioned (via the NamespaceProvisioner operator)
   Default RBAC + ResourceQuota + cost-label policies applied
   PagerDuty schedule created · Slack channel created

Developer opens Backstage:
   Clicks "Create Service" → selects a golden-path template → fills the form
        ↓
   GitHub repo created with the full skeleton
   CI/CD pipeline wired · ArgoCD Application created
   Dev environment deployed automatically
   Monitoring dashboard created · on-call schedule linked
   Service appears in the Software Catalog immediately
```

## Requirements

- [ ] **Backstage deployed and configured** — [Module 15.2](../../15-developer-experience-and-idp/02-backstage-fundamentals/)
- [ ] **At least 3 golden-path templates** (Go service, Python service, frontend) — [Module 15.4](../../15-developer-experience-and-idp/04-backstage-software-templates/), [Project 4](../../16-platform-project-04/)
- [ ] **All 4 core plugins configured** (ArgoCD, Kubernetes, Grafana, Cost) — [Module 15.5](../../15-developer-experience-and-idp/05-backstage-plugins/)
- [ ] **Custom template actions** for platform-specific steps (e.g. provisioning a namespace, opening a GitOps PR) — [Module 15.4](../../15-developer-experience-and-idp/04-backstage-software-templates/)
- [ ] **Platform CLI** with `team create`, `env create`, and `deploy` commands — [Module 15.7](../../15-developer-experience-and-idp/07-platform-cli-tools/)
- [ ] **Recorded demo** of the full onboarding journey (team create → service create → running in prod)

## How it extends Project 4

Project 4 built the mechanism (Backstage + two golden-path templates + the GitOps
hand-off). This capstone adds what makes it a *product*:

- **Team onboarding automation** — the `platform team create` command and the
  [NamespaceProvisioner operator](../../10-kubernetes-advanced/02-kubernetes-operators/)
  turn Project 1's manual namespace runbook into a one-command, self-service action.
- **A third template** (frontend) and **custom scaffolder actions** that do real
  platform work (namespace provisioning, a config-repo PR) rather than just creating a
  repo.
- **The four plugins live**, so each service page shows sync status, pods, dashboards,
  and cost — the portal becomes the single pane of glass.
- **A demo** — because a platform you can *show* onboarding a team in 30 minutes is far
  more convincing than a description.

## Definition of done

Meets the [portfolio standard](../portfolio-standard.md) and the
[production readiness checklist](../production-readiness-checklist.md). Concretely:

- [ ] `platform team create` provisions a team's catalog entity, namespace, RBAC, quota,
  and cost policy end-to-end.
- [ ] A developer scaffolds a service from the portal and it reaches a running dev
  environment **without any manual platform-team step**.
- [ ] Measured **time-to-first-production-deploy for a new team is under 30 minutes**.
- [ ] Each service page shows ArgoCD sync, live Kubernetes state, Grafana dashboards, and
  cost.
- [ ] The whole journey is captured in a short recorded demo.

## Deliverables

- **Backstage** deployed and configured (on GKE, or locally with documented cloud
  deltas).
- **At least 3 golden-path templates** with custom actions.
- **All 4 core plugins** configured (ArgoCD, Kubernetes, Grafana, Cost).
- **A platform CLI** (`team create`, `env create`, `deploy`) — extend the
  [Module 15.7 CLI](../../15-developer-experience-and-idp/07-platform-cli-tools/).
- **A recorded demo** of the end-to-end onboarding journey.
- **ADRs** (reuse Project 4's:
  [why Backstage](../../16-platform-project-04/internal-developer-platform/architecture/decisions/ADR-007-why-backstage.md),
  [template strategy](../../16-platform-project-04/internal-developer-platform/architecture/decisions/ADR-018-golden-path-template-strategy.md),
  [docs-as-code](../../16-platform-project-04/internal-developer-platform/architecture/decisions/ADR-019-techdocs-docs-as-code.md)).

## Where to start

1. Stand up **Project 4** (Backstage + the two golden-path templates + GitOps hand-off).
2. Build the **`platform team create`** flow: a CLI command + a custom scaffolder action
   that drives the NamespaceProvisioner operator and creates the catalog Group.
3. Add a **third template** and **custom actions** that open a config-repo PR
   automatically (so Stage 4 of Project 4 becomes self-service).
4. Wire the **four plugins** against your Project 2/3 stack.
5. **Measure** the onboarding time, tighten the slow steps, and **record the demo**.

> Remember Phase 1: the portal is not the platform, and adoption is the scoreboard.
> Measure the onboarding time, gather developer feedback, and make the golden path the
> genuinely easiest route — don't mandate it.

---

_Back to:_ [Capstones overview](../README.md)
· _Previous:_ [01 — Production Kubernetes Platform](../01-production-kubernetes-platform/)
· _Next:_ [03 — Multi-Cluster GitOps Platform →](../03-multi-cluster-gitops-platform/)
