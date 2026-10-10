# Lab — Assess your GitOps maturity and pick the next rung

> You'll run an honest self-assessment: score a platform across the maturity
> dimensions, compute an overall level from the weakest *painful* dimension, and
> commit to a single prioritized next step with its justification. The output is the
> artifact a platform team actually presents to decide what to do next.

**Estimated time:** ~40–50 minutes
**Type:** Discovery / assessment
**Deliverable:** A completed [`maturity-worksheet.md`](./maturity-worksheet.md) with
dimension scores, an overall rating, and one prioritized next step.

## Objectives

- Score a platform across the ten GitOps maturity dimensions, with evidence.
- Derive an honest overall level (the weakest painful dimension).
- Choose and justify the single highest-value next step.

## Prerequisites

- [Modules 08.1–08.5](../../01-gitops-principles/) — the practices you're scoring.
- The worksheet in this folder: [`maturity-worksheet.md`](./maturity-worksheet.md).
- A target to assess: **a real platform you know**, or the fictional **Acme** scenario
  below so you can complete the lab solo.

## The Acme scenario (use if you have no real platform handy)

Acme Corp runs ~30 services on three clusters (dev, staging, prod). Assess *this*:

- **Source of truth.** App manifests live in a Git monorepo. Ingress and RBAC are in
  Git too, but cluster add-ons (cert-manager, metrics-server) were installed by hand
  with Helm and are **not** in Git.
- **Sync.** Argo CD is installed; dev and staging Applications auto-sync with
  self-heal. Prod is synced **manually through the UI** by the platform lead.
- **Drift.** Self-heal is on for dev/staging, but **nothing alerts** when an app goes
  OutOfSync or a sync fails.
- **Secrets.** Most apps use Sealed Secrets. Two legacy services still have **base64
  `Secret`s committed in Git** — "temporarily," for the last eight months.
- **Promotion.** Engineers hand-copy the new image tag into each overlay and open a
  PR. No CI automation opens or validates the promotion.
- **Progressive delivery.** Releases replace all Pods at once. One team tried Argo
  Rollouts in dev; it's not used in prod.
- **Multi-cluster.** The three clusters are managed as separate sets of Applications;
  there's no single fleet control plane.
- **Policy.** No automated policy checks run during sync.
- **Observability.** The Argo CD UI shows sync status, but no dashboards or alerts
  exist outside it.

## Steps

1. **Choose your target.** Decide whether you're scoring a real platform you know or
   the Acme scenario above. Open [`maturity-worksheet.md`](./maturity-worksheet.md) and
   fill in the header (platform, date, assessor).

2. **Score each dimension 0–4, with evidence.** For every row in the worksheet table,
   assign a level and write the *evidence you could show* (a dashboard, a repo path, a
   metric). Be strict: if you can't show it, it isn't that level. Re-read the level
   descriptions in the [module](../README.md) as needed.

3. **Derive the overall level.** Don't average. Find the **lowest dimension that still
   causes real pain or risk** — that's your overall level. Record it and one or two
   sentences on *why* (which dimension limits you and what it risks).

4. **Pick one prioritized next step.** Choose the single change that removes the most
   risk or pain for the least effort — usually securing a dangerous low dimension, not
   adding a shiny high one. Write what you'll do, why it's first, and how you'll know
   it worked (the evidence/metric).

5. **(Optional) Sketch a roadmap.** Name your target level and the next two or three
   rungs to reach it, in order.

## Expected result

A completed worksheet with a jagged but honest dimension profile, an overall level
justified by its weakest painful dimension, and one concrete, defensible next step. For
Acme, a strong answer lands around **Level 1–2 with a critical Level 0 secrets hole**,
and the first step is to **rotate and migrate the two committed secrets to ESO**
(Module 08.5), then **add drift and sync-failure alerting** — security and audit before
progressive-delivery polish.

## Cleanup

> This lab creates no cloud or cluster resources, so there is nothing to tear down.
> **Keep** your completed worksheet — it's a portfolio artifact and the starting point
> for Project 2.

```bash
# Nothing to delete. Optionally track your worksheet in your notes/portfolio.
```

## Reflection

- Did averaging *feel* more flattering than scoring by the weakest dimension? Why is
  the strict reading the safer one to act on?
- Your next step was probably not the most exciting capability. What makes "secure the
  base first" the right instinct?
- How would this assessment change the conversation with leadership compared with "we
  need to do more GitOps"?

## Stretch goals (optional)

- Re-score the same platform *as you'd like it to be after Project 2* and list exactly
  which modules (08.2–08.5) close each gap.
- Add a weight to each dimension (risk × effort) and show how it changes the ordering
  of your next three steps.
- Map each dimension to a measurable signal (e.g. "percentage of config under GitOps,"
  "mean time to rollback") so the next assessment is evidence-driven, not opinion.
