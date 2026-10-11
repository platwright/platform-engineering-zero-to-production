# Module 11.8 — Platform Observability Strategy

> You now have the tools — OpenTelemetry, Prometheus, Loki, Tempo, Grafana, Sloth. This
> final module is about **strategy**: what a *platform team* observes (which is not what
> app teams observe), how to watch the GitOps pipeline and the cluster control plane,
> who gets paged and when, and why every alert must link to a runbook. It turns a pile
> of tools into an operating discipline — and sets up Project 3.

**Estimated effort:** ~1.5–2 hours (theory + design lab)
**You'll need:** Modules [11.1](../01-observability-fundamentals/)–[11.7](../07-slos-and-error-budgets/).
No cloud; this is a design module.

## Learning objectives

By the end of this module you will be able to:

- Distinguish what a **platform team** observes from what **application teams** observe.
- Define golden signals for **platform services** (Argo CD, Prometheus, Grafana, ESO).
- Observe the **GitOps pipeline** and the **cluster control plane**.
- Design an **alerting and paging** policy: who is woken, by what, and when.
- Attach a **runbook** to every alert and publish shared signals teams self-serve.

---

## 1. Concept

### Two different jobs: platform vs application observability

An application team observes **their service**: its RED metrics, its logs, its traces,
its SLOs. A platform team observes **two** things, and conflating them is a strategic
error:

- **The platform's own services** — Argo CD, Prometheus, Grafana, the ingress, the
  secret operator, the registry, the Collector pipeline. These are *products you
  operate*, and they have their own golden signals and SLOs. When Argo CD is down,
  nobody can deploy; that is *your* incident, not any app team's.
- **The substrate every app runs on** — the cluster control plane (API server, etcd,
  scheduler), nodes, and shared capacity. App teams should rarely think about etcd; you
  always do.

Crucially, the platform also **provides** observability *to* app teams (the shared
Prometheus/Loki/Tempo/Grafana), but it does **not** own their SLOs. The dividing line:
*you own the platform's reliability and the observability plumbing; teams own their
own services' reliability on top of it.*

### Golden signals for platform services

Apply RED / the four golden signals to the platform's own products:

- **Argo CD** — sync success rate and sync latency, app health/drift, reconciliation
  queue depth, controller errors. (You met `argocd_app_sync_total` in Module 11.7.)
- **Prometheus / Mimir** — scrape success (`up`), TSDB head series (cardinality!),
  rule-evaluation failures, remote-write latency and failures, ingestion rate.
- **Grafana** — availability, request latency/errors, datasource health, failed logins.
- **External Secrets Operator (ESO)** / secret tooling — secret sync success/latency,
  provider API errors, reconcile failures (a stuck ESO silently breaks deploys).
- **The OTel Collector** — queue size, `exporter_send_failed_*`, refused spans/metrics,
  memory pressure. Observe your observability pipeline, or it fails silently.

Each of these deserves an SLO (Module 11.7). A platform that cannot say "Argo CD is
99.9% available" is not operating it as a product.

### Observing the GitOps pipeline

GitOps (Phase 8) is the platform's delivery mechanism, so its health is a
first-class platform signal:

- **Sync latency** — time from a Git commit to the change being live. A rising trend
  means delivery is slowing for everyone.
- **Sync errors** — failed reconciliations; spikes indicate a broken manifest, a bad
  image, or a cluster problem.
- **Drift events** — resources diverging from Git (manual `kubectl edit`), which Argo
  CD detects and (optionally) self-heals. Frequent drift signals a process problem.
- **Reconciliation throughput / queue depth** — the controller falling behind.

These make the invisible pipeline visible — and feed the "recent deployments" panel you
stubbed in Module 11.6.

### Cluster-level signals

The control plane and nodes are the platform's foundation:

- **API server** — request latency and error rate (`apiserver_request_duration_seconds`,
  `apiserver_request_total`), inflight requests, and throttling. A slow API server slows
  every controller and `kubectl`.
- **etcd** — health, leader changes, fsync/commit latency, DB size. etcd trouble is a
  cluster-wide emergency.
- **Nodes** — pressure conditions (CPU/memory/disk/PID), `NotReady` nodes, kubelet
  health — the USE method applied to the fleet.
- **Scheduler / controller-manager** — scheduling latency and failures (Pods stuck
  `Pending`).
- **Capacity** — allocatable vs requested CPU/memory per node and per namespace, so you
  see saturation before it bites.

### Cross-team observability: shared signals

Some signals every team should see without asking — published by the platform as a
product surface:

- A **Platform Overview** dashboard (Module 11.6) with cluster health and per-namespace
  usage, visible to all.
- **Per-team RED dashboards** generated from a template, so each team gets a consistent
  view of its services for free.
- Shared conventions (metric/label/log naming) so a metric means the same thing across
  teams — the standardization that makes self-service querying possible.

### Alerting and paging: who, what, when

Tools do not page people; *policy* does. A platform paging policy answers:

- **Page only on symptoms and SLO burn.** Platform alerts fire on *user-facing* impact
  (Argo CD can't sync, API server latency breaching SLO, a node fleet losing capacity) —
  via multi-window burn-rate alerts (Module 11.7), not raw thresholds.
- **Route by ownership.** A platform-service alert pages the **platform on-call**; an app
  alert pages the **owning team**. Routing uses labels (`team`, `severity`), so the
  right human is woken — never "everyone."
- **Tier by urgency.** `page` (wake someone now) vs `ticket` (handle in hours). Most
  alerts should be tickets; pages are rare and sacred.
- **Protect the on-call.** Group and dedupe related alerts, use silences during planned
  work, and track alert volume as a health metric. A noisy pager is a broken pager.

### Runbooks: every alert links to one

An alert at 3am that says only "HighErrorRate" is cruel. **Every alert must carry a
`runbook_url`** pointing to a short page: what this alert means, how to confirm it, the
first diagnostic steps, how to mitigate, and how to escalate. Runbooks turn tribal
knowledge into something any on-call engineer can act on — and they are the single
cheapest way to reduce incident stress and time-to-recovery.

---

## 2. Why it matters for platform engineering

- **The platform is a dependency of everyone.** When a platform service degrades, every
  team is affected. Observing and SLO-ing your own services is how you catch that before
  they do — and how you earn trust.
- **Unobserved pipelines fail silently.** A stuck Argo CD or ESO means "deploys stopped
  working" with no error anyone sees until a team complains. Pipeline observability is
  how the platform notices first.
- **Good paging policy protects your team.** Alert fatigue burns out platform engineers
  and trains people to ignore the pager. Symptom-based, routed, runbooked alerting is a
  sustainability issue, not a nicety.
- **Shared signals reduce whole-org cognitive load.** Publishing consistent dashboards
  and conventions means every team sees the same truth without building it — the
  platform-as-product thesis (Module 01.1) applied to observability.

---

## 3. Mental model

Draw a line: the platform observes *the platform and the substrate*; app teams observe
*their apps*; a shared layer in the middle is published for everyone.

```text
   ┌─────────────────────────────────────────────────────────────┐
   │ APP TEAMS own: their service RED, logs, traces, and SLOs     │  (self-serve)
   ├─────────────────────────────────────────────────────────────┤
   │ SHARED (platform publishes): Overview dashboard, per-team    │  (a product
   │ RED templates, naming conventions, the Prom/Loki/Tempo stack │   surface)
   ├─────────────────────────────────────────────────────────────┤
   │ PLATFORM owns: Argo CD · Grafana · Prometheus · ESO · OTel   │  (your SLOs,
   │ GitOps pipeline (sync latency/errors/drift)                  │   your pages)
   │ Cluster: API server · etcd · nodes · scheduler · capacity    │
   └─────────────────────────────────────────────────────────────┘
        every alert here → routed by ownership → links to a runbook
```

Rule of thumb: **if its failure blocks many teams, the platform owns the signal and the
page; if it affects one service, that team does.** When unsure, ask "whose 3am is this?"

---

## 4. Minimal implementation

Strategy becomes real as a short, written **observability charter** — a table that
assigns, for each thing you watch, an owner, the golden signals, an SLO, who gets paged,
and the runbook. Even three rows beat an unwritten plan:

```text
service      | signals (SLI)            | SLO     | page      | runbook
-------------+--------------------------+---------+-----------+------------------------
Argo CD      | sync success ratio       | 99.9%   | platform  | /runbooks/argocd
API server   | request latency p99, 5xx | 99.95%  | platform  | /runbooks/apiserver
<app>/checkout| request availability    | 99.9%   | app-team  | /runbooks/checkout
```

The corresponding alert simply carries the ownership and the runbook as labels, so
routing and response are automatic:

```yaml
labels:
  severity: page
  team: platform          # → routes to the platform on-call, not everyone
annotations:
  summary: "Argo CD sync error budget burning fast"
  runbook_url: "https://runbooks.example.com/argocd-availability"
```

That is the whole discipline: decide who owns each signal, set an SLO, route the page by
ownership, and link a runbook. The lab turns this into a filled-in strategy for a
realistic platform — the design document Project 3 implements.

---

## 5. Hands-on lab

You will produce a **platform observability strategy**: classify what the platform
observes versus what app teams observe, define golden signals and SLOs for the core
platform services, design a paging policy routed by ownership, and write one runbook.

➡️ **[Start the lab: Design a platform observability strategy](./lab/README.md)**

## 6. Production considerations

- **Dogfood your own stack.** Run the platform's services *on* the observability you
  give others, with the same SLOs and dashboards. If your monitoring of Argo CD is worse
  than a team's monitoring of its app, fix that first.
- **Watch the watchers.** Prometheus, the Collector, and Grafana must themselves be
  observed and, ideally, redundant. Alert on `up`, scrape failures, remote-write errors,
  and Collector drops — the pipeline failing silently is the classic trap.
- **Make on-call volume a tracked metric.** Count pages per week per team; a rising
  trend is an action item. Budget time to tune or delete noisy alerts.
- **Keep runbooks alive.** A stale runbook is worse than none. Link them from alerts,
  review them after incidents, and treat them as code in Git.
- **Separate tenancy and access.** Teams see their own data by default; platform-wide
  views are explicit. Enforce with Grafana folders/permissions and Loki/Prometheus
  tenancy.
- **Plan for the observability bill.** Metrics cardinality, log volume, and trace
  retention are real costs you govern centrally (Phase 18 ties this to FinOps). Budget
  and cap them before a tenant does it for you.

## 7. Common mistakes

- **Platform team only watches app metrics.** — You see tenants' services but miss your
  own (Argo CD, etcd, the Collector), so platform outages surprise you. *Fix:* golden
  signals and SLOs for every platform service and the control plane.
- **Paging everyone for everything.** — Broad routing and threshold alerts create fatigue
  and trained helplessness. *Fix:* route by ownership label, page only on symptoms/SLO
  burn, make tickets the default.
- **Alerts with no runbook.** — On-call gets a cryptic name at 3am and no next step.
  *Fix:* mandate `runbook_url` on every alert; block alerts that lack one.
- **Ignoring the GitOps pipeline.** — Sync latency, errors, and drift go unwatched, so
  "deploys stopped working" is discovered by complaint. *Fix:* observe sync
  latency/errors/drift as first-class platform signals.
- **No tenancy or shared conventions.** — Every team invents names and can see
  everything, so cross-team querying and access control break. *Fix:* shared semantic
  conventions and per-team access.
- **Unobserved observability stack.** — The monitoring that watches everything is itself
  unmonitored and fails quietly. *Fix:* monitor Prometheus/Loki/Tempo/Collector health
  and make them redundant.

## 8. Assessment

**Knowledge checks**

1. Name two things a platform team observes that an application team does not.
2. Give the golden signals you would track for Argo CD and for the Kubernetes API server.
3. What three GitOps-pipeline signals belong on a platform's radar, and why?
4. How should a platform alert be *routed*, and what must every alert link to?
5. Why must the observability stack itself be observed and made redundant?

**Concept exercise**

> Explain where a platform team's observability responsibility **ends** and an app
> team's **begins** — **without using the words "SLO," "metric," or "dashboard."** Use
> the idea of who is woken when something breaks.

**Architecture / design exercise**

> Your platform runs Argo CD, a shared Prometheus, Grafana, and ESO for 40 teams on one
> cluster. Design the alerting-and-paging policy: which failures page the platform
> on-call versus a team, which are pages versus tickets, how routing decides, and what
> each alert links to. Then name the one platform-service outage that would hurt the most
> and justify its SLO.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** The platform's own services (Argo CD, Prometheus, Grafana, ESO, the Collector)
  and the cluster substrate (API server, etcd, nodes, scheduler, capacity).
- **Q2:** Argo CD: sync success rate, sync latency, app health/drift, controller errors.
  API server: request latency (p99), error rate (5xx), inflight/throttling.
- **Q3:** Sync latency (delivery slowing), sync errors (broken reconciliations), and
  drift events (resources diverging from Git) — they make the delivery pipeline's health
  visible to the team responsible for it.
- **Q4:** Routed by ownership labels (`team`, `severity`) to the right on-call — platform
  service → platform on-call, app → owning team — and tiered page vs ticket. Every alert
  must link to a `runbook_url`.
- **Q5:** If Prometheus/Loki/Tempo/the Collector fail silently, you lose the ability to
  see any other failure; redundancy and self-monitoring keep the safety net intact.
- **Design:** Platform-service and control-plane failures (Argo CD down, API server SLO
  breach, etcd unhealthy, Collector dropping data) page the platform on-call; app SLO
  burns page the owning team by label. Page on fast burn / hard-down; ticket on slow burn
  and capacity trends. Route by `team`/`severity`; every alert carries a runbook. The
  most damaging single outage is usually **Argo CD** (no team can deploy) or the **API
  server/etcd** (cluster-wide) — justify a strict SLO (e.g. 99.9–99.95%) because its
  failure blocks everyone.

</details>

---

## 9. Further reading

- Google — [SRE Book: Monitoring](https://sre.google/sre-book/monitoring-distributed-systems/)
  and [Being On-Call](https://sre.google/sre-book/being-on-call/)
- Google — [SRE Workbook: Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- Argo CD — [Monitoring and metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/)
- Kubernetes — [Monitoring the control plane / system metrics](https://kubernetes.io/docs/concepts/cluster-administration/system-metrics/)
- Prometheus — [Alertmanager routing](https://prometheus.io/docs/alerting/latest/configuration/)
  and the [Runbooks pattern](https://prometheus.io/docs/practices/alerting/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 11.7 — SLOs and Error Budgets](../07-slos-and-error-budgets/)
· _Next:_ [Project 3 · Observability Platform →](../../12-platform-project-03/)
