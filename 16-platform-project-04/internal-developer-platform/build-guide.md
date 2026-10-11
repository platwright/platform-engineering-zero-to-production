# Build Guide — Internal Developer Platform

> The staged walkthrough. **Pass 1** runs Backstage locally, registers the catalog and
> the two golden-path templates, and scaffolds a service that hands off to the Project 2
> GitOps platform. **Pass 2** deploys Backstage on GKE with auth, plugins, and TechDocs.
> Pass 1 takes ~2–3 hours (plus Backstage's first `yarn install`).

**Type:** Build project (capstone)
**Deliverable:** A running Backstage IDP with a populated catalog and two working
golden-path templates, plus a scaffolded service whose GitOps overlay is deployed by
ArgoCD.

## Prerequisites

- **Node.js 20+** and **Yarn** (for Backstage), plus `git`.
- For the GitOps hand-off: the [Project 2](../../09-platform-project-02/) platform
  running on a local kind cluster, and its config repo.
- You're in this project directory:
  `16-platform-project-04/internal-developer-platform/`.

---

## Pass 1 — Build it now (local, free)

### Stage 0 — Scaffold and run Backstage

```bash
./scripts/bootstrap.sh
```

This creates a Backstage app in a sibling directory (`../.idp-app`) using
`npx @backstage/create-app` (Module 15.2). It intentionally does **not** vendor
Backstage's `node_modules` into this repo.

### Stage 1 — Wire in the IDP config

Merge this project's [`backstage/app-config.idp.yaml`](./backstage/app-config.idp.yaml)
into the scaffolded app's `app-config.yaml`, pointing the catalog and template
`target:` paths at this project's
[`backstage/catalog/org.yaml`](./backstage/catalog/org.yaml) and the two
[`golden-paths/*/template.yaml`](./golden-paths/) files. Then start it:

```bash
cd ../.idp-app && yarn install && yarn dev
# open http://localhost:3000
```

### Stage 2 — Explore the catalog

In the portal, open **Catalog**. You should see the Systems, Groups (teams), and
Components from [`org.yaml`](./backstage/catalog/org.yaml) — including the platform's own
capabilities (`gitops-platform`, `observability-platform`) and an example team service.
This is the "who owns what, where it runs" inventory from
[Module 15.3](../../15-developer-experience-and-idp/03-backstage-software-catalog/).

### Stage 3 — Scaffold a service from a golden path

Click **Create** → pick **Go Microservice** (or **Python FastAPI Service**) → fill the
form (name, owner, repo). The scaffolder:

1. renders the [skeleton](./golden-paths/go-microservice/skeleton/) with your inputs,
2. (Pass 2) publishes a GitHub repo, and
3. registers the new service in the catalog.

In Pass 1 (no GitHub), use the scaffolder's **dry-run** / local output to inspect the
rendered skeleton: a complete service with app code, a hardened Dockerfile, the CI
pipeline, a GitOps overlay, `catalog-info.yaml`, and docs — none of which the developer
wrote by hand.

### Stage 4 — Hand off to GitOps (close the loop)

Take the scaffolded `gitops/` overlay and drop it into your Project 2 config repo under
`apps/<team>/<service>/overlays/dev/`, then commit and push:

```bash
# in your Project 2 config-repo clone
mkdir -p apps/team-a/my-service/overlays/dev
cp -r <scaffolded>/gitops/* apps/team-a/my-service/overlays/dev/
git add -A && git commit -m "onboard my-service" && git push
```

Project 2's ApplicationSet generates an ArgoCD Application for the new folder and
deploys it. Watch it appear:

```bash
kubectl -n argocd get applications | grep my-service
```

A developer filled a form; minutes later a hardened, observable service is running on
the platform — **that is the IDP**. See
[config-repo/README.md](./config-repo/README.md) for the hand-off detail.

### Stage 5 — Clean up

```bash
./scripts/cleanup.sh          # removes the local Backstage app
# (tear down the Project 2 cluster with its own cleanup script if you're done)
```

---

## Pass 2 — Deploy for real (as cloud/accounts allow)

1. **Backstage on GKE with GitHub auth.** Deploy Backstage with Helm; configure the
   GitHub auth provider and a `GITHUB_TOKEN`.
   → [Module 15.2](../../15-developer-experience-and-idp/02-backstage-fundamentals/)
2. **Catalog auto-discovery.** Enable the GitHub org provider so every repo with a
   `catalog-info.yaml` self-registers.
   → [Module 15.3](../../15-developer-experience-and-idp/03-backstage-software-catalog/)
3. **Plugins.** Install and configure ArgoCD, Kubernetes, Grafana, and Cost Insights so
   each service page shows sync status, live pods, dashboards, and cost.
   → [Module 15.5](../../15-developer-experience-and-idp/05-backstage-plugins/),
   [Project 3](../../12-platform-project-03/), [Phase 14](../../18-finops-and-cost-engineering/)
4. **TechDocs.** Build docs in CI and serve from object storage; every service's docs
   render in the portal.
   → [Module 15.8](../../15-developer-experience-and-idp/08-developer-portal-documentation/)
5. **GitOps-deliver Backstage itself.** Put Backstage under ArgoCD (Project 2) so the
   portal is as reproducible as everything else.
6. **Automate the GitOps hand-off.** Add a scaffolder step that opens a PR to the config
   repo, so Stage 4 is fully self-service.

As you finish each, update the
[portfolio-ready checklist](./README.md#portfolio-ready-checklist).

---

## Reflection

- In Stage 3 the developer got a complete, hardened, observable, deployable service from
  a form. List everything they did **not** have to learn or do by hand. That list is the
  cognitive load the IDP removed (Module 01.1).
- The IDP produced declarative config and let ArgoCD deploy it, rather than deploying
  directly. Why is keeping that boundary (Git as source of truth) worth it?
- Golden-path templates are versioned and opinionated. Where would you add an **escape
  hatch** so a team with a genuine special case isn't forced off the platform?
