# Lab — Define a Golden Path and Pass the Readiness Checklist

> Define one complete golden path for your platform and assess it against a readiness
> checklist: confirm every required capability is wired in by default, design its
> escape hatch, write its versioning/migration plan, and choose its adoption metrics.
> This is a design lab — the deliverable is a reusable checklist.

**Estimated time:** ~45–60 minutes
**Type:** Design
**Deliverable:** A completed [golden-path checklist](./golden-path-checklist.md) for one
path (e.g. "standard Go service"), ready to present and reuse.

## Objectives

- Compose the phase's pieces (template, CI, GitOps, observability, docs) into one
  end-to-end golden path.
- Design a documented, reviewed, visible escape hatch.
- Write a versioning + migration plan and pick adoption metrics.

## Prerequisites

- [Module 15.6](../README.md) and the pieces from Modules 15.4–15.5.
- Your [Module 15.1 design worksheet](../../01-idp-architecture/lab/platform-api-design-worksheet.md)
  and, ideally, the `go-microservice` template from
  [Module 15.4](../../04-backstage-software-templates/lab/template.yaml).
- No tools or cloud — a text editor is enough.

## Steps

1. **Pick the path.** Choose one journey to pave (e.g. "standard Go service"). Open
   [`golden-path-checklist.md`](./golden-path-checklist.md) and fill in the header.

2. **Walk the "must include" list.** For each capability — scaffold, CI/CD, image,
   IaC, GitOps, observability, security, docs — record how your path provides it and
   whether it is **default** or still **opt-in**. Every opt-in is a gap: note the fix.

3. **Design the escape hatch.** Name one legitimate deviation the path must allow,
   then specify how it stays documented, reviewed, and counted. Decide what signal
   would make you fold it into the default path.

4. **Write the versioning + migration plan.** Define your version scheme, deprecation
   policy, and — crucially — the **tooling** (bot/codemod) that moves a service from
   `v1` to `v2`. A guide alone does not count.

5. **Choose adoption metrics.** Pick concrete numbers for coverage, version adoption,
   escape-hatch rate, and time-to-first-production-deployment, and say where each comes
   from (catalog query, CI telemetry, image signatures).

6. **Score readiness.** Use the final checklist to mark the path ready / not ready. Any
   unchecked "by default" item means not ready — fix it before you claim a golden path.

## Expected result

A completed checklist showing every required capability wired in by default, a healthy
escape hatch, a migration plan with tooling, and named adoption metrics — a document you
could hand to leadership as "here is our golden path and how we know it works," and
reuse for every future path.

## Cleanup

> Design lab — no resources are created. Keep the checklist for Project 4.

```bash
# Nothing to tear down. Save the checklist with your portfolio artifacts.
```

## Reflection

- How many "must include" items were truly default versus opt-in? Opt-in is where teams
  silently skip security and observability.
- Does your escape hatch create a feedback loop, or just a release valve?
- Is your migration *tooling* real, or did you only write a guide?

## Stretch goals (optional)

- Fill the checklist for a *second* path (e.g. a Python service or a RAG app) and note
  what is shared versus path-specific.
- Draft the one-paragraph platform contract (reliability, interface stability, support)
  for this path.
- Sketch the catalog query you would run to compute coverage from `catalog-info.yaml`
  data.
