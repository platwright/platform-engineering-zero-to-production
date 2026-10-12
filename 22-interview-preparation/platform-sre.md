# Interview Prep — Platform SRE

> This domain tests whether you can keep a platform reliable when many teams
> depend on it: platform SLOs, error budgets, toil, incidents, chaos, DR, and
> capacity. Interviewers probe the control-plane-versus-data-plane distinction and
> whether your reliability work is data-driven. Practice reasoning about blast
> radius out loud before reading the model answer.

## Reliability targets

### Q: What is different about SLOs for a platform versus an application?

**What they're really asking:** Do you know the platform's SLIs are its own self-service journeys?

A platform's "users" are internal teams, so its SLIs measure the **platform's own
interfaces and control plane**: API server availability and latency, time to provision
an environment, CI/CD and GitOps reconciliation success and latency, ingress and image
registry availability. The crucial point is that platform reliability is a
**dependency of every tenant's reliability**, so platform SLOs must be strong,
**published**, and defined around the journeys teams rely on. Keep platform-provided
SLOs (what the platform guarantees) distinct from the per-app SLOs that teams own.

**Going deeper:** [17.2 · Platform SLOs](../17-platform-sre/02-platform-slos/) and [11.7 · SLOs and Error Budgets](../11-observability-engineering/07-slos-and-error-budgets/)

**Red flags:** Measuring node CPU instead of the self-service experience teams actually depend on.

### Q: What is an error budget, and what is an error budget policy?

**What they're really asking:** Do you make the speed-versus-reliability trade explicit?

The error budget is `1 − SLO` — the allowed unreliability over a window. An **error
budget policy** is the pre-agreed response to the budget's state: while budget remains,
ship features quickly; when it is **exhausted**, freeze risky changes and redirect
effort to reliability until it recovers. It removes case-by-case arguing and makes the
trade data-driven. For a platform team, it governs how aggressively you roll out
changes that could affect many tenants at once.

**Going deeper:** [17.2 · Platform SLOs](../17-platform-sre/02-platform-slos/) and [11.7 · SLOs and Error Budgets](../11-observability-engineering/07-slos-and-error-budgets/)

### Q: What is toil, and how do you manage it?

**What they're really asking:** Do you know toil's definition and that automating it is the platform product?

Toil is manual, repetitive, automatable work that scales linearly with the system and
produces no lasting value — hand-provisioning, applying YAML by hand, repetitive
restarts. Manage it by **measuring** it and capping it (SRE guidance is under ~50% of
time), then **automating** it away. For a platform team this is not a side task — it is
the product: self-service is how you eliminate the ticket toil that would otherwise
grow with every new team.

**Going deeper:** [17.1 · Platform SRE Fundamentals](../17-platform-sre/01-platform-sre-fundamentals/)

**Red flags:** Accepting endless manual ticket work as "just operations," with no plan to automate it.

## Incidents and resilience

### Q: How do you run incident management?

**What they're really asking:** Do you have a structured, role-based response?

Declare an incident early, assign clear roles, and separate coordination from hands-on
work:

- **Incident Commander** coordinates and decides; **Comms/Scribe** handles stakeholder updates and a timeline; **Ops/subject experts** investigate and mitigate.
- Classify **severity**, keep a single source of truth, and **mitigate first** — restore service (roll back, fail over) before chasing root cause.
- Communicate proactively, then run a **blameless postmortem** with concrete action items.

Because a platform incident can hit many tenants at once, comms and blast-radius
awareness matter even more than for a single app.

**Going deeper:** [17.3 · Platform Incident Management](../17-platform-sre/03-platform-incident-management/)

**Red flags:** No incident commander, debugging root cause while users are down, or blaming individuals.

### Q: What are MTTD, MTTR, and the blameless postmortem?

**What they're really asking:** Do you know recovery often matters more than prevention?

**MTTD** is mean time to detect; **MTTR** is mean time to restore. Lowering MTTR — fast
rollback, good runbooks, strong observability — is frequently higher-leverage than
trying to prevent every failure, because failures are inevitable. A **blameless
postmortem** examines **systemic** causes without blaming individuals, because people
are only honest when safe and most failures are system failures; it must produce
owned, tracked action items, not just a narrative.

**Going deeper:** [17.3 · Platform Incident Management](../17-platform-sre/03-platform-incident-management/)

### Q: What is chaos engineering, and how do you do it safely?

**What they're really asking:** Do you validate resilience deliberately rather than hope?

Chaos engineering deliberately injects failure — killing pods, adding latency, draining
nodes, failing a dependency, simulating a zone outage — to **verify** your resilience
assumptions and find weaknesses before a real incident does. Do it safely:

- Start from a **hypothesis** and a steady-state metric you expect to hold.
- Keep a **small blast radius**; begin in non-prod, then carefully in prod.
- Have an **abort and rollback**, monitor closely, and run GameDays to build muscle memory.

It is how you prove failover, SLOs, and runbooks actually work.

**Going deeper:** [17.5 · Chaos Engineering for Platforms](../17-platform-sre/05-chaos-engineering-for-platforms/)

**Red flags:** "Randomly break prod to see what happens," with no hypothesis, blast-radius control, or abort plan.

## Continuity and capacity

### Q: What are RTO and RPO, and how do you design DR for a platform?

**What they're really asking:** Do you size recovery to the business, not just "take backups"?

**RTO** (recovery time objective) is how fast you must restore after a disaster; **RPO**
(recovery point objective) is how much data loss is tolerable — effectively how fresh
backups must be. For a platform:

- Back up critical state — **etcd**, databases, persistent volumes (Velero), and secrets — and **practice restores**; an untested backup is not a backup.
- Because platform config lives in **Git and IaC**, you can **rebuild** clusters declaratively, which shrinks RTO.
- Match the strategy — backup/restore, warm standby, or active/active across regions — to the RTO/RPO the business will actually pay for.

**Going deeper:** [17.6 · Disaster Recovery for Platform](../17-platform-sre/06-disaster-recovery-for-platform/)

**Red flags:** Having backups but never testing restore, or promising aggressive RTO/RPO with a backup-only design.

### Q: How do you plan capacity and autoscale (Karpenter versus Cluster Autoscaler)?

**What they're really asking:** Do you know the autoscaling layers and modern node provisioning?

Capacity planning means staying ahead of demand with headroom for failover while not
overspending. Three layers combine: **HPA** scales pod replicas on metrics, **VPA**
right-sizes pod requests, and **node autoscaling** adds/removes nodes. **Cluster
Autoscaler** scales **fixed node groups** when pods are pending. **Karpenter** is
group-less and just-in-time: it provisions **right-sized nodes** directly from pending
pods' requirements (choosing instance types and spot), and **consolidates** — re-packs
workloads and removes underused nodes — giving faster scale-up and lower cost. This
ties directly into FinOps.

**Going deeper:** [17.4 · Platform Capacity Planning](../17-platform-sre/04-platform-capacity-planning/) and [18.4 · Cost Optimization Patterns](../18-finops-and-cost-engineering/04-cost-optimization-patterns/)

### Q: What makes a platform reliable — the control plane versus the data plane?

**What they're really asking:** Do you design so serving survives a control-plane outage?

Separate the **control plane** (API server, scheduler, controllers, GitOps/CI,
provisioning) from the **data plane** (running workloads serving traffic). A
well-designed platform keeps the **data plane serving even when the control plane is
degraded**: existing pods keep running and ingress keeps routing if the API server is
down — you simply cannot make changes. So you make the control plane HA (multi-master,
etcd quorum) but ensure request-path serving does not hard-depend on it. A control-plane
outage should degrade **change**, not **serving**.

**Going deeper:** [17.1 · Platform SRE Fundamentals](../17-platform-sre/01-platform-sre-fundamentals/)

**Red flags:** A design where the API server going down also takes down live traffic.

### Q: How do you keep on-call sustainable?

**What they're really asking:** Do you treat on-call health as a reliability concern?

Sustainable on-call needs humane rotations with enough people (follow-the-sun where
possible), **only actionable, user-impacting pages** (tied to SLO burn, not static
thresholds), active reduction of alert noise and toil, recognition for on-call, a
**blameless** culture, solid runbooks and handoffs, and a loop that feeds incident
learnings back into fixes so the same page does not recur. Burnout is itself a
reliability risk.

**Going deeper:** [17.3 · Platform Incident Management](../17-platform-sre/03-platform-incident-management/) and [17.1 · Platform SRE Fundamentals](../17-platform-sre/01-platform-sre-fundamentals/)

**Red flags:** Noisy, non-actionable paging and no mechanism to reduce recurring alerts.
