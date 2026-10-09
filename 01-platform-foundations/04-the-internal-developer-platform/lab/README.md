# Lab — IDP Capability Assessment

> Assess a real or fictional organization's platform against the five planes and the
> core IDP capabilities. The output is a gap analysis that shows, honestly, how much
> is self-service vs. ticket-driven vs. absent — and what the thinnest valuable next
> step is.

**Estimated time:** ~45–60 minutes
**Type:** Design / analysis
**Deliverable:** A completed [capability assessment](./idp-capability-assessment.md)
with a maturity rating per capability and a prioritized "thin next step."

## Objectives

- Apply the five-planes model and the core-capabilities list to a real situation.
- Distinguish **self-service**, **ticket-driven**, and **absent** honestly.
- Identify the single highest-leverage gap and a thin way to close it.

## Steps

1. **Choose the subject.** An organization you know, or the
   [fictional "HelloCorp"](#fictional-scenario) below.

2. **Rate each core capability** in the [assessment template](./idp-capability-assessment.md):

   | Rating | Meaning |
   |--------|---------|
   | 🟢 Self-service | A developer can do it themselves, on demand, via automation. |
   | 🟡 Ticket-driven | Possible, but a human on another team must act. |
   | 🔴 Absent | Not available, or done ad hoc/by tribal knowledge. |

   Capabilities: self-service provisioning · environment management · application
   catalog · deployment automation · secrets management · observability · access
   control.

3. **Check the five planes.** For each plane (control, delivery, resource,
   monitoring, security), note what exists and what's missing. Watch especially for
   security and monitoring being bolted on rather than default.

4. **Find the biggest gap.** Which 🔴/🟡 capability, if moved to 🟢, would most reduce
   developer friction (tie it back to your Module 01.1/01.3 findings)?

5. **Propose a thin next step.** Not a two-year platform plan — the *smallest*
   valuable improvement (TVP). What would you build or buy first, and why?

## Expected result

A completed assessment: a rating per capability, a five-planes note, the top gap,
and a thin, justified next step. It should read like something you could present to
an engineering leader to justify the platform team's next quarter.

## Reflection

- How many capabilities were truly **self-service** vs **ticket-driven**? (Most
  orgs are surprised by how much is tickets.)
- Which plane was weakest? Was security or monitoring an afterthought?
- Does your "thin next step" match the top opportunity from your Module 01.2 brief?
  Consistency across these labs is a good sign.

## Stretch goals (optional)

- Map each capability to where it's taught in this course (use the plane→phase table
  from the lesson) to build your personal learning priority order.
- Rate a *second* organization and compare maturity profiles.

---

## Fictional scenario

Use "HelloCorp" (the world of Priya/Marco/Aisha) if you don't have a real subject:

> **HelloCorp, 60 engineers, 25 services on GKE.**
>
> - New services are created by copying another repo; no template. *(provisioning)*
> - There's one shared dev cluster; getting a namespace means asking the platform
>   person. *(environment management)*
> - No catalog — "who owns this service?" is answered in Slack. *(catalog)*
> - Deploys go through a hand-rolled GitHub Actions pipeline each team copied and
>   modified. *(deployment)*
> - Secrets are set by hand in the cluster after a Slack thread. *(secrets)*
> - Prometheus/Grafana exist, but each team builds dashboards from scratch.
>   *(observability)*
> - Cloud IAM is granted per-request via tickets; often over-broad. *(access)*

<details>
<summary>Hint: a reasonable assessment of HelloCorp</summary>

- Provisioning 🔴 · Environments 🟡 · Catalog 🔴 · Deployment 🟡 · Secrets 🟡 ·
  Observability 🟡 · Access 🟡.
- Weakest planes: **developer control plane** (no interface/golden path) and
  **monitoring** (exists but not default/self-service).
- Biggest gap: **no golden path for new services** (provisioning + control plane) —
  it's upstream of several other pains.
- Thin next step: a `new-service` golden-path template (secure Dockerfile, sane
  manifests, CI, default dashboard) exposed via a CLI/README — *build the glue, buy
  nothing new yet.* Catalog and portal come later, by demand.

</details>
