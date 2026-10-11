# Lab — IDP Architecture and Platform-API Design

> Design the architecture for a real Internal Developer Platform: map the five planes
> and the orchestration, write a declarative **platform API** for a "new service"
> request, and make deliberate **build-vs-buy** calls. This is a design lab — the
> output is a document you will reference for the rest of the phase and Project 4.

**Estimated time:** ~60–75 minutes
**Type:** Design
**Deliverable:** A completed [platform-API design worksheet](./platform-api-design-worksheet.md)
— the planes-to-components map, a versioned `ServiceRequest` spec, and a filled-in
build-vs-buy matrix.

## Objectives

- Map the five planes to concrete components (reusing your Project 1–3 work).
- Design a stable, versioned, declarative **platform API** for one golden path.
- Make and justify **build-vs-buy** decisions with a scoring matrix, not a hunch.

## Prerequisites

- [Module 15.1](../README.md) (this lesson), plus
  [Module 01.4](../../../01-platform-foundations/04-the-internal-developer-platform/).
- No tools or cloud — this is a worksheet. A text editor is enough.
- Helpful: your [Module 01.4 capability assessment](../../../01-platform-foundations/04-the-internal-developer-platform/lab/)
  if you did it, to anchor the design in a real org.

## Steps

1. **Choose the subject.** A platform you know, or the fictional **HelloCorp** below.
   Open [`platform-api-design-worksheet.md`](./platform-api-design-worksheet.md) and
   fill in the header.

2. **Map the five planes to components.** For each plane (control, delivery, resource,
   monitoring, security) write the concrete tool or capability that will fill it.
   Reuse what you already built:

   | Plane | Likely component | Built in |
   |-------|------------------|----------|
   | Developer control | Backstage + `platform` CLI | This phase |
   | Integration & delivery | GitHub Actions + ArgoCD | Phases 6, 8 |
   | Resource | Terraform / Crossplane | Phase 5 |
   | Monitoring | Prometheus / Grafana / OTel | Phase 11 |
   | Security | ESO / Vault + RBAC + policy | Phases 10, 13 |

3. **Draw the orchestration.** In the worksheet, sketch (ASCII is fine) how one "new
   service" request fans out across the planes. Label where the **platform API** sits
   and where the **orchestration** glue lives.

4. **Write the platform API.** Complete the declarative `ServiceRequest` spec in the
   worksheet: `apiVersion` (versioned from day one), required fields, optional fields
   **with defaults**, and which fields are *always-on conventions* (monitoring,
   security) rather than developer choices.

5. **Fill in the build-vs-buy matrix.** Score each component (1–5) on
   differentiation, operational cost, time-to-value, and lock-in, then record a
   build / buy / adopt-OSS decision and a one-line justification each.

6. **Identify the escape hatch and the migration story.** Name one legitimate
   deviation the path must allow, how it stays visible/auditable, and how you would
   ship a breaking v2 of the API without breaking existing teams.

## Expected result

A completed worksheet with: a planes-to-components table, an orchestration sketch, a
versioned `ServiceRequest` spec with defaults and conventions marked, a scored
build-vs-buy matrix with decisions, and an escape-hatch + migration note. It should
read like an architecture doc you could present to an engineering leader — and it is
the design you will implement across Modules 15.2–15.8.

## Cleanup

> This is a design lab — it creates no cloud resources, so there is nothing to tear
> down. **Keep the worksheet**: it is the architecture for your Project 4 platform.

```bash
# Nothing to clean up. Save your worksheet alongside your portfolio artifacts.
```

## Reflection

- Did any plane map to "a ticket" rather than a component? That is where your
  self-service work should start.
- How many fields does your `ServiceRequest` actually require of a developer? Could
  convention remove any of them?
- Which build-vs-buy call was closest? What would change your mind?

## Stretch goals (optional)

- Express your API using the open [Score](https://score.dev/) spec and compare it to
  your hand-rolled `ServiceRequest`.
- Add a second golden path (e.g. a Python service) and note what in the API changes
  and what stays shared.
- Write one paragraph of the platform contract (reliability, interface stability,
  support) you owe consumers of this API — a preview of Module 15.6.

---

## Fictional scenario

Use **HelloCorp** if you do not have a real subject:

> **HelloCorp, 60 engineers, 25 services on GKE.** Teams create services by copying a
> neighbouring repo; namespaces, RBAC, and quotas are set by the platform person on
> request (Project 1 did this by hand). Delivery is GitOps with ArgoCD, but someone
> writes each `Application` (Project 2). Prometheus and Grafana exist, but every team
> builds dashboards from scratch (Project 3). Secrets are pasted into the cluster
> after a Slack thread. Leadership wants "a Backstage portal" by next quarter.

Your job: design the **architecture and API** so that "new service" becomes one
self-service request — not a portal pointed at the same ticket queue.
