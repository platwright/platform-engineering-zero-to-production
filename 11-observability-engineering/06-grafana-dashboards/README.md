# Module 11.6 — Grafana Dashboards

> A dashboard is where raw telemetry becomes a decision. **Grafana** is the "G" in the
> LGTM stack — one pane of glass over metrics (Prometheus), logs (Loki), and traces
> (Tempo). This module is about building dashboards that *answer a question* instead
> of drowning you in graphs, and treating them as **code** you version in Git, not
> clicks you lose.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 11.3](../03-metrics-with-prometheus/), a kind cluster,
`kubectl`, and [Helm](https://helm.sh/).

## Learning objectives

By the end of this module you will be able to:

- Apply **dashboard design principles**: one purpose, top-down hierarchy, readable panels.
- Use **variables and templating** to make one dashboard serve many services.
- Combine **mixed data sources** and correlate pillars on a single board.
- Explain Grafana **alert rules**, contact points, and notification policies.
- Deliver dashboards **as code** (Grafonnet/Jsonnet) and version them in Git.

---

## 1. Concept

### A dashboard answers one question

The most common dashboard failure is the "wall of graphs": forty panels nobody reads,
built by accretion. A good dashboard has **one purpose** and a clear audience, and it
is organized **top-down** — the summary that tells you *if* something is wrong at the
top, the detail that tells you *what and where* below.

Design principles that actually matter:

- **One purpose per dashboard.** "Platform Overview" (health at a glance) and "Service
  Deep-Dive" (debugging one service) are *different* dashboards, not one giant board.
- **Top-down hierarchy.** First row: the four golden signals / SLO status — the
  "should I care?" answer. Lower rows: the breakdowns that explain it.
- **Lead with symptoms, support with causes.** Put user-facing signals (latency, error
  rate) above resource signals (CPU, memory); causes are for drilling, not the headline.
- **Readable panels.** Title every panel as the question it answers, set units
  (seconds, bytes, percent), and use consistent time ranges. A graph with no units is
  a trap.
- **Few, well-chosen panels** beat many. If a panel has never driven a decision,
  delete it.

### Variables and templating

Hardcoding a service name into every query means one dashboard per service — hundreds
of near-identical boards to maintain. **Template variables** fix this: a dropdown at
the top (`$service`, `$namespace`, `$datasource`) rewrites every query on the board.

```promql
# a templated query: $service is chosen from a dropdown
sum by (job) (rate(http_requests_total{job="$service"}[5m]))
```

Variables can be **queries** (populate a `namespace` dropdown from
`label_values(kube_pod_info, namespace)`), **custom** lists, or **data source**
variables (so one board works across clusters). One well-templated dashboard replaces
a hundred copies — the platform-scale move.

### Mixed data sources and correlation

A Grafana panel can query different **data sources**, and a dashboard can mix them: a
metrics panel from Prometheus next to a logs panel from Loki next to a traces panel
from Tempo — all sharing the dashboard's time range. This is where the three pillars
come together visually: see the error-rate spike, the error logs, and a slow trace on
*one screen*. **Exemplars** (Module 11.5) let you click a point on a latency graph and
jump to the trace behind it. Correlation configured once, consumed by everyone.

### Alerting in Grafana

Grafana has its own alerting engine (complementary to Prometheus Alertmanager):

- **Alert rules** evaluate a query on a schedule and fire when a condition holds for a
  duration (e.g. error ratio > 5% for 5 minutes).
- **Contact points** are *where* a notification goes: Slack, PagerDuty, email, a webhook.
- **Notification policies** route firing alerts to contact points by label (team,
  severity), with grouping, timing, and silences.

The platform-engineering point (Module 11.7 goes deeper): alert on **symptoms and SLO
burn**, route by **ownership labels**, and keep the policy as code. A dashboard is for
investigation; an alert is for waking someone — do not confuse them.

### Dashboards as code

Dashboards built by clicking live only in Grafana's database. They drift, they are
not reviewed, and they vanish when someone "tidies up." Treat them like any other
platform artifact — **as code in Git**:

- **JSON model** — Grafana's native dashboard format. Exportable and importable, but
  verbose and painful to diff or template by hand.
- **Grafonnet** — a **Jsonnet** library that builds the JSON programmatically, so you
  compose panels from functions, share defaults, and avoid copy-paste. The idiomatic
  "dashboards as code" tool.
- **Grizzly / the sidecar** — tools and patterns to *apply* dashboards to Grafana from
  Git. In Kubernetes, the common pattern is a **ConfigMap** labelled
  `grafana_dashboard=1` that a Grafana sidecar auto-imports — so a merged pull request
  deploys a dashboard, GitOps-style (Phase 8).

Dashboards as code means review, diffs, rollback, and reuse — the same discipline you
apply to infrastructure.

---

## 2. Why it matters for platform engineering

- **Dashboards are a platform product surface.** The boards you ship — a Platform
  Overview, per-team RED dashboards generated from a template — are how teams *see*
  their services. A good default dashboard is a golden path.
- **Templating is how you scale to N teams.** One parameterized dashboard serves every
  service; you do not hand-build a board per team. That is the leverage argument again.
- **As-code dashboards survive people.** Click-built boards rot and disappear.
  Versioned dashboards are reviewable, diffable, and reproducible across clusters — and
  they are a portfolio-grade artifact.
- **One pane over three pillars reduces cognitive load.** Teams should pivot
  metrics → logs → traces without learning three tools or wiring correlation
  themselves. You configure it once, centrally.

---

## 3. Mental model

A dashboard is an **inverted pyramid**: the headline answer on top, the supporting
detail beneath, and links out to the raw evidence.

```text
   ┌─────────────────────────────────────────────┐
   │  ROW 1  SLO status · golden signals          │  "should I care?"  (summary)
   ├─────────────────────────────────────────────┤
   │  ROW 2  rate · errors · latency per service  │  "what is wrong?"  (breakdown)
   ├─────────────────────────────────────────────┤
   │  ROW 3  CPU/mem · logs · traces (exemplars)  │  "why / where?"    (drill-down)
   └─────────────────────────────────────────────┘
        ▲ $datasource  $namespace  $service  ← templating rewrites every query

   Source of truth = Jsonnet in Git → rendered JSON → applied to Grafana (as code).
```

Rule of thumb: **if you cannot answer "what one question does this dashboard answer,
and for whom?" it is two dashboards wearing a trench coat.** Split it.

---

## 4. Minimal implementation

The smallest dashboard-as-code is a JSON model with one templated panel. Even hand-
written, the shape is clear — a variable and a panel whose query references it:

```json
{
  "title": "Service RED (minimal)",
  "templating": { "list": [
    { "name": "service", "type": "query", "datasource": { "type": "prometheus" },
      "query": "label_values(http_requests_total, job)" } ] },
  "panels": [
    { "type": "timeseries", "title": "Request rate — $service",
      "gridPos": { "h": 8, "w": 24, "x": 0, "y": 0 },
      "targets": [ { "expr": "sum(rate(http_requests_total{job=\"$service\"}[5m]))" } ] }
  ],
  "schemaVersion": 39
}
```

Hand-maintaining that JSON across dozens of panels is miserable — which is the whole
argument for Grofonnet. The same panel in **Grafonnet** is a function call you can
reuse and parameterize:

```jsonnet
local g = import 'g.libsonnet';
local panel = g.panel.timeSeries;

panel.new('Request rate — $service')
+ panel.queryOptions.withTargets([
    g.query.prometheus.new('$datasource',
      'sum(rate(http_requests_total{job="$service"}[5m]))'),
  ])
```

You `jsonnet` it into the JSON model, commit both, and apply it from Git. The lab
builds a real **Platform Overview Dashboard** this way and imports it via a ConfigMap.

---

## 5. Hands-on lab

You will deploy the metrics stack on kind, import a **Platform Overview Dashboard**
(delivered as Grafonnet *and* ready-to-import JSON) via a Grafana sidecar ConfigMap,
watch it populate with namespace CPU, RED, latency, and active alerts, and template it
by service.

➡️ **[Start the lab: A Platform Overview Dashboard as code](./lab/README.md)**

---

## 6. Production considerations

- **Version dashboards in Git, deploy via GitOps.** No production dashboard should
  exist only in Grafana's database. Render from Jsonnet, review the diff, and apply via
  sidecar/Grizzly so changes are auditable and reversible.
- **Templatize instead of copying.** Maintain a *few* parameterized dashboards
  (Overview, Service Deep-Dive) and generate per-team views from them. Hundreds of
  bespoke boards are unmaintainable.
- **Standardize units, thresholds, and layout.** A shared Grafonnet library of panel
  helpers keeps every team's board consistent and readable — consistency is a platform
  value.
- **Mind query cost.** Heavy panels on auto-refresh hammer the datasource; back hot
  panels with recording rules (Module 11.3) and set sane refresh intervals.
- **Control access and secrets.** Scope folders and permissions per team; keep data
  source credentials out of the JSON (use Grafana-managed secrets); do not expose
  Grafana publicly.
- **Separate dashboards from alerts.** Dashboards are for humans investigating; alerts
  page machines-to-humans. Keep alert rules as code too (Module 11.7), routed by
  ownership labels.

## 7. Common mistakes

- **The wall of graphs.** — A dashboard with no single purpose and forty panels nobody
  reads. *Fix:* one question per dashboard, top-down, delete panels that never drive a
  decision.
- **Hardcoding service names.** — One static dashboard per service becomes hundreds to
  maintain. *Fix:* template variables (`$service`, `$namespace`, `$datasource`).
- **Click-built, unversioned dashboards.** — They drift, cannot be reviewed, and
  vanish. *Fix:* dashboards as code (Grafonnet) committed to Git and applied from there.
- **Panels without units or clear titles.** — "0.few" on an axis means nothing; a
  panel titled `panel 3` answers no question. *Fix:* set units, title each panel as its
  question.
- **Causes above symptoms.** — Leading with CPU graphs buries the user-facing signal.
  *Fix:* golden signals and SLO status on top, resources below.
- **Dashboards as alerts.** — Expecting someone to *watch* a board to catch incidents.
  *Fix:* alert on SLO burn and symptoms; dashboards are for investigation after the page.

## 8. Assessment

**Knowledge checks**

1. What is the single most important question to ask before building a dashboard?
2. How do template variables let one dashboard serve many services?
3. Why put user-facing symptoms above resource metrics in the layout?
4. Name two advantages of Grafonnet over a hand-edited JSON export.
5. What does the ConfigMap-plus-sidecar pattern achieve for dashboards?

**Concept exercise**

> Describe how you would present the health of 50 services to an on-call engineer on
> **one screen** — **without using the words "Grafana," "panel," or "dashboard."**
> Focus on what they must see first and what they drill into.

**Architecture / trade-off exercise**

> Your team has 120 click-built dashboards, many near-duplicates, and nobody trusts
> them. Design a plan to get to a small set of versioned, templated dashboards: what
> you consolidate, how you template, how you store and deploy them, and how you prevent
> the sprawl from returning.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** "What one question does this dashboard answer, and for whom?" Purpose and
  audience drive every other choice.
- **Q2:** A variable (`$service`) is a dropdown whose value is substituted into every
  query, so one board re-renders for any selected service instead of needing a copy per
  service.
- **Q3:** You want the "should I care?" (user impact) answer first; resource metrics
  are causes you drill into, not the headline. Leading with causes buries the signal.
- **Q4:** Reuse (panels are functions with shared defaults), and diffable/parameterized
  source instead of giant copy-pasted JSON — plus easy consistency across teams.
- **Q5:** It makes dashboards GitOps-deployable: a dashboard committed as a ConfigMap
  (labelled `grafana_dashboard=1`) is auto-imported by the Grafana sidecar, so a merged
  PR ships the dashboard — versioned, reviewed, reproducible.
- **Trade-off:** Consolidate duplicates into a few templated boards (one Overview, one
  Service Deep-Dive) parameterized by `$service`/`$namespace`; author in Grafonnet with
  a shared panel library; store in Git and deploy via sidecar/Grizzly; prevent sprawl
  by making the templated boards the paved road and disallowing unversioned production
  dashboards.

</details>

---

## 9. Further reading

- Grafana — [Dashboards documentation](https://grafana.com/docs/grafana/latest/dashboards/)
  and [best practices](https://grafana.com/docs/grafana/latest/dashboards/build-dashboards/best-practices/)
- Grafana — [Templating and variables](https://grafana.com/docs/grafana/latest/dashboards/variables/)
- Grafana — [Grafonnet](https://grafana.github.io/grafonnet/) and
  [Grizzly](https://grafana.github.io/grizzly/)
- Grafana — [Alerting](https://grafana.com/docs/grafana/latest/alerting/)
- Grafana — [Provision dashboards and data sources](https://grafana.com/docs/grafana/latest/administration/provisioning/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 11.5 — Distributed Tracing with Tempo](../05-distributed-tracing-with-tempo/)
· _Next:_ [Module 11.7 — SLOs and Error Budgets →](../07-slos-and-error-budgets/)
