# 17 · Platform SRE

> You have built a platform — clusters, GitOps, a portal, observability, security.
> Now you have to **keep it up** for every team that depends on it. A platform team
> runs at a **higher reliability bar than any single app team**, because when the
> platform is down, *every* stream-aligned team is down at once. This phase is how
> you operate a platform like a Site Reliability Engineer: SLOs for your own
> services, relentless toil elimination, incident command, capacity planning, chaos
> testing, and disaster recovery.

**Phase 13 · 6 modules · ~10–14 hours**

## Why this phase?

Everything before this phase was about *building* capabilities. This phase is about
*running* them under the weight of production and many teams. The shift in mindset
is large and specific:

- **Your blast radius is the whole org.** An app team's outage affects one product.
  A platform outage — Argo CD stops syncing, the registry is unreachable, secrets
  stop propagating — blocks *every* team that builds on you, simultaneously. That is
  why a platform's reliability target is higher, and why the discipline here is
  borrowed wholesale from Google's SRE practice.
- **Toil is the enemy.** Platform teams drown in manual, repetitive operational work
  — creating namespaces, rotating secrets by hand, babysitting cluster upgrades. SRE
  gives you a way to *measure* that toil and a mandate to *automate it away* so the
  team scales with adoption instead of collapsing under it.
- **Reliability is engineered, not hoped for.** SLOs turn "is the platform healthy?"
  into a number. Error budgets turn reliability into something you can *spend*.
  Incident command turns chaos into a process. Chaos engineering finds the weakness
  before your users do. DR makes "the cluster is gone" a drill, not a catastrophe.

This phase builds directly on your earlier work: platform SLOs extend
[Module 11.7](../11-observability-engineering/07-slos-and-error-budgets/) and
[Project 3](../12-platform-project-03/); the incident lab runs against the
[Project 2](../09-platform-project-02/) Argo CD platform; and DR protects the
clusters you stood up in Projects 1 and 2. You are now the SRE **for the platform
itself**.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [Platform SRE Fundamentals](./01-platform-sre-fundamentals/) | Why platforms carry a higher reliability bar; blast radius; the four SRE responsibilities; toil and how to measure it. | A completed toil inventory worksheet with an automation backlog. |
| 2 | [Platform SLOs](./02-platform-slos/) | SLOs for platform services (GitOps sync, Argo CD, secret propagation, builds); error-budget policy; freeze-vs-investigate. | Four Sloth `PrometheusServiceLevel` specs rendered into burn-rate alerts. |
| 3 | [Platform Incident Management](./03-platform-incident-management/) | Severity classification (P0–P3), incident commander, comms, runbooks, blameless postmortems. | A full postmortem for a simulated Argo CD sync incident. |
| 4 | [Platform Capacity Planning](./04-platform-capacity-planning/) | Node-pool design, HPA/VPA, Cluster Autoscaler and Karpenter, forecasting, right-sizing. | A Karpenter `NodePool` with spot preference and consolidation, plus a right-sizing analysis. |
| 5 | [Chaos Engineering for Platforms](./05-chaos-engineering-for-platforms/) | Steady-state hypotheses, Chaos Mesh, GameDays, verifying SLOs/alerts/runbooks under failure. | Three Chaos Mesh experiments run against platform components, with results. |
| 6 | [Disaster Recovery for Platform](./06-disaster-recovery-for-platform/) | RTO/RPO, Velero backup/restore, etcd snapshots, multi-region, DR drills. | A tested restore from backup and a filled-in DR runbook. |

Work them in order — each builds on the last. Fundamentals frames the mindset,
SLOs give you the numbers, incident management gives you the process, and the final
three (capacity, chaos, DR) are the proactive disciplines that keep a platform
reliable *before* the pager goes off.

## Learning objectives

By the end of this phase you will be able to:

- Explain why a platform team operates at a higher reliability bar than app teams,
  and identify, measure, and attack **toil** as the core of platform SRE.
- Define, generate, and operate **SLOs and error budgets** for platform services,
  and run an error-budget policy that decides when to freeze versus investigate.
- Run a **platform incident** end to end: detect from a burn-rate alert, classify
  severity, command the response, mitigate with a runbook, and write a blameless
  postmortem.
- Plan **cluster capacity** with node-pool design and autoscaling, and use Karpenter
  to right-size, prefer spot, and consolidate underutilized nodes.
- Design and run **chaos experiments** against platform components, framed by a
  steady-state hypothesis, to verify that SLOs hold and runbooks work.
- Build and test a **disaster-recovery** plan with Velero, defined RTO/RPO targets,
  and a runbook you have actually rehearsed.

## Prerequisites

- [Phase 11 · Observability Engineering](../11-observability-engineering/) — you will
  extend the SLO and alerting work from Module 11.7 directly.
- [Project 2](../09-platform-project-02/) and
  [Project 3](../12-platform-project-03/) — the Argo CD platform and burn-rate alerts
  the labs reference.
- A local [kind](https://kind.sigs.k8s.io/) cluster, `kubectl`, `helm`, and Docker.
  Every core lab runs **free and local**. Cloud-only topics (Karpenter on managed
  Kubernetes, Velero to object storage) are clearly marked optional, with a local
  equivalent so you never need to spend money to learn the concept.

## A note on the labs

These labs produce the **operational artifacts a platform SRE actually maintains**:
a toil inventory, SLO specs, a postmortem, a capacity/right-sizing plan, chaos
results, and a DR runbook. Keep them — together they are the operational playbook
for the platform you have spent this whole course building, and exactly what a
hiring manager means by "can you *run* a platform, not just build one?"

---

Start with [**01 · Platform SRE Fundamentals →**](./01-platform-sre-fundamentals/)
