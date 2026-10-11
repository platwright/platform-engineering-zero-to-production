# Module 18.3 — Cost Attribution and Chargeback

> Module 18.2 gave you a cost per workload. This module gives it an **owner**. A
> number nobody is accountable for changes nothing; the discipline of FinOps is
> turning "the cluster costs \$80k" into "`team-payments` costs \$9k, here's the
> trend, and here's the lever." That requires a **mandatory label contract**
> (enforced with the same Kyverno you used for security), a decision about
> **showback vs chargeback**, and a report that lands in the team's channel on its
> own.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 18.2](../02-kubernetes-cost-management/) (OpenCost), [Module 13.3 · Kyverno](../../13-security-and-policy-engineering/03-policy-as-code-with-kyverno/), and a working `kubectl` + [kind](https://kind.sigs.k8s.io/) + [Helm](https://helm.sh/).

## Learning objectives

By the end of this module you will be able to:

- Distinguish **showback** from **chargeback** and sequence them as a maturity path.
- Design a **mandatory cost-label taxonomy** and explain why each key exists.
- **Enforce** that taxonomy at admission with a Kyverno `require-cost-labels` policy.
- Build **per-team cost reporting** — a Grafana view and a pushed weekly summary.
- Hold a **FinOps conversation** with an engineering manager that drives action, not
  defensiveness.

---

## 1. Concept

### Two ways to make cost land on a team

Attribution data can be used two ways, and the order matters:

- **Showback.** You *show* each team what it costs; no money actually moves. It is
  cheap to run, politically low-friction, and surprisingly effective — most teams have
  never *seen* their number and will self-correct once they do. Showback is where you
  start.
- **Chargeback.** You *bill* each team's budget for its cloud spend. Now cost has teeth:
  it competes with headcount and features for real money, which drives the strongest
  accountability. But it demands accurate data, finance buy-in, and trust. Bill a team
  for a number they don't believe and you'll spend the next quarter arguing about the
  meter instead of reducing the bill.

```text
   Showback ─────────────────────────────────▶ Chargeback
   "here is your cost"                          "here is your invoice"
   low friction, builds awareness               high accountability, needs trust
   START HERE                                    EARN THIS with accurate showback
```

The progression is the point. **You earn the right to charge back by first proving,
through showback, that your attribution is accurate.** Skipping to chargeback on shaky
data is the fastest way to discredit the whole FinOps effort.

### The label taxonomy: the contract that makes attribution possible

Attribution is only as good as the labels under it. You need a small, **mandatory,
consistent** set of keys on every workload. Reusing the scheme
[Project 1](../../04-platform-project-01/) established:

- `platform.example.com/team` — the owning team. *Who pays?*
- `platform.example.com/environment` — `production` / `staging` / `development`. Splits
  the expensive prod spend from cheap dev spend.
- `platform.example.com/cost-center` — the finance code this maps to. *Which budget?*
- `app.kubernetes.io/name` — the service. Gives per-application granularity within a
  team.

Two design choices worth understanding:

- **Namespaced keys** (`platform.example.com/…`) avoid collisions with app labels and
  signal that the platform owns and enforces them — they are not teams' to redefine.
- **Consistency is everything.** One team writing `team: payments` and another
  `team: Payments` fractures every report into two half-teams. The taxonomy is a
  *contract*: fixed keys, controlled values, documented, and — crucially — enforced.

Where the labels go matters for OpenCost. OpenCost aggregates by **pod** labels, so the
labels must be on the **pod template** (`spec.template.metadata.labels`), not just the
Deployment's top-level metadata. The coarse, always-reliable boundary is the
**namespace** (often one namespace per team/environment); labels add finer per-service
attribution on top.

### Enforcing the contract with Kyverno

A taxonomy that relies on people remembering decays exactly like the security checklist
did in Module 13.3 — so you enforce it the same way. A `require-cost-labels`
ClusterPolicy inspects every workload at admission and **rejects any that lack the
mandatory labels**. You roll it out the safe way you already know:

```text
Audit ──(measure the gap via policy reports)──▶ Enforce ──(reject non-compliant)──▶
```

This is the course theme made literal: **cost labels are structural, not bolt-on**, and
the same admission-control guardrail that makes workloads secure by default makes them
*attributable* by default. (A more advanced setup uses a Kyverno **mutate** rule to
*add* a default `cost-center` from the namespace, reserving hard `validate` rejections
for the labels only a human can supply — like `team`.)

### From labels to per-team reporting

With labels enforced and OpenCost running, reporting is a query. OpenCost aggregates
allocation by any label:

```text
GET /allocation/compute?window=7d&aggregate=label:team     → cost per team
GET /allocation/compute?window=7d&aggregate=namespace      → cost per namespace
```

Two delivery channels turn that query into behavior change:

- **Dashboards.** A Grafana row per team (filtered on the team label) shows each team
  its own 30-day trend next to the latency and error dashboards it already watches —
  cost as just another signal.
- **A pushed weekly report.** Dashboards require someone to go and look; most won't. A
  weekly job queries OpenCost per team, formats "this week vs last week, top services,
  anything anomalous," and posts it to each team's Slack channel. Push beats pull.

### The FinOps conversation

The hardest part is not the tooling; it's the conversation. A few rules that keep it
productive:

- **Lead with trend and unit economics, not absolute dollars.** "Your cost per request
  rose 30% after Tuesday's deploy" is an engineering bug report. "You spent \$9,000" is
  just a number that invites defensiveness.
- **Make it their data, with levers attached.** Hand teams their own dashboard and a
  concrete recommendation ("these five workloads request 4× what they use"), not a
  scolding.
- **Frame cost as a quality attribute**, peer to latency and reliability — something
  good engineers tune, not a punishment. The platform's job is to make the efficient
  path the easy one, never to play cost police.

---

## 2. Why it matters for platform engineering

- **Attribution is the deliverable of the whole "Inform" phase.** Without a credible
  per-team number, optimization is unfocused guessing and governance is just politics.
  Everything in Module 18.4 and 18.5 assumes this data exists and is trusted.
- **The label contract is a platform responsibility.** Only the platform can define one
  taxonomy for everyone and *enforce* it uniformly — a team can't make its peers label
  consistently. This is identical in shape to owning the security baseline.
- **Showback is the cheapest behavior-change tool you have.** Making cost visible to the
  people who create it, with no billing machinery, moves numbers on its own.
- **It's where platform meets finance.** The `cost-center` label is the join key between
  your cluster and the company's budget. Get it right and chargeback becomes possible;
  get it wrong and finance never trusts your data.

---

## 3. Mental model

Hold the **attribution pipeline** — each stage owned by a tool you already know:

```text
   LABEL            ALLOCATE           REPORT              ACT
   ─────            ────────           ──────              ───
   Kyverno    ─▶    OpenCost     ─▶    Grafana + Slack ─▶  team right-sizes
   enforces         splits node        per-team trend      platform commits CUDs
   the taxonomy     cost by label      pushed weekly       finance charges back
   (18.3)           (18.2)             (18.3)              (18.4 / 18.5)

   Maturity:   showback  ───────────────────────────▶  chargeback
               (show the number)                       (bill the budget)
```

The rule: **enforce the label, trust the allocation, push the report, and only then
discuss the money.** Skip a stage and the conversation collapses into an argument about
the data.

---

## 4. Minimal implementation

The smallest useful attribution is one enforced label plus one aggregation query.

The policy — require a `team` label on the pods of every Deployment (start in Audit):

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-team-label
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: check-team-label
      match:
        any:
          - resources:
              kinds: [Deployment]
      validate:
        message: "Every workload must set spec.template.metadata.labels['platform.example.com/team']."
        pattern:
          spec:
            template:
              metadata:
                labels:
                  platform.example.com/team: "?*"
```

The report — cost per team, straight from OpenCost:

```bash
curl -sG http://localhost:9003/allocation/compute \
  -d window=7d -d aggregate=label:team -d accumulate=true \
| jq -r '.data[0] | to_entries | sort_by(-.value.totalCost)
         | .[] | "\(.key)\t$\((.value.totalCost*100|round)/100)"'
```

Enforce the label, and `?*` (Kyverno's "any non-empty value") guarantees every future
workload is attributable. Aggregate by it, and you have a per-team bill. Everything
else — more labels, dashboards, Slack — is scale and polish on these two moves.

---

## 5. Hands-on lab

You'll apply a real `require-cost-labels` ClusterPolicy, watch it **block** a workload
missing the labels and **admit** a compliant one (Audit → Enforce, as in Module 13.3),
then run a **weekly per-team cost report** script that summarizes OpenCost allocation
and can post to Slack. The report runs against live OpenCost *or* a bundled sample, so
it works even on a fresh cluster.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Showback first, always.** Run showback until teams trust the numbers and the data
  reconciles with the cloud invoice. Only then discuss chargeback — and introduce it
  gradually (e.g. charge back a subset of clearly-attributable cost first).
- **Have a plan for shared and idle cost.** Idle, ingress, logging, and the platform's
  own components aren't any one team's. Decide a split rule — spread proportionally to
  usage, or hold it in a `platform` cost-center — and make it **transparent**, because
  unexplained "overhead" on a team's bill destroys trust.
- **Backfill existing workloads.** Flip the policy to Enforce only after Audit shows the
  gap is closed; give teams a window and a mutate-default where you safely can, so
  enforcement doesn't block deploys on day one.
- **Normalize values, not just keys.** Consider a Kyverno rule (or CI check) that
  rejects unknown `team`/`environment` values, so `prod`, `production`, and `Prod` don't
  become three cost centers.
- **Make reports actionable, not noise.** A weekly report that's just a number gets
  muted. Highlight the *change* and the *anomaly*, and attach the lever. (Anomaly
  alerting is Module 18.5.)
- **Reconcile with the bill.** Periodically check that the sum of attributed cost plus
  idle equals the actual invoice. Drift means your price list or allocation rules need
  attention.

---

## 7. Common mistakes

- **Chargeback before trust.** Billing teams on inaccurate or unexplained data turns
  every finance meeting into an argument about the meter. *Fix:* earn chargeback with a
  period of accurate, reconciled showback.
- **Inconsistent label keys or values.** `team` vs `Team`, `prod` vs `production` —
  each split fractures the report. *Fix:* namespaced keys, a controlled value list, and
  enforcement (optionally a mutate rule that normalizes).
- **Labeling the Deployment but not the pod template.** OpenCost aggregates on *pod*
  labels, so top-level-only labels produce empty per-team reports. *Fix:* require the
  labels on `spec.template.metadata.labels`.
- **Enforcing on day one.** Flipping straight to Enforce rejects every existing
  non-compliant deploy and causes an outage of goodwill. *Fix:* Audit → measure →
  backfill → Enforce.
- **Hiding shared cost or dumping it on teams.** Silently spreading idle onto tenants
  makes their numbers look wrong and untrustworthy. *Fix:* an explicit, documented
  shared-cost policy.
- **Playing cost police.** Reports framed as blame make teams hide from FinOps. *Fix:*
  give teams their own data and levers; make the efficient path the easy one.

---

## 8. Assessment

**Knowledge checks**

1. In one sentence each, define showback and chargeback, and say which comes first and
   why.
2. Name the four cost-label keys from the taxonomy and what question each answers.
3. Why must cost labels live on the pod template rather than only the Deployment's
   metadata?
4. What is the safe rollout sequence for the `require-cost-labels` policy, and what does
   the Audit phase give you?
5. Why is "your cost per request rose 30% this week" a better opener than "you spent
   \$9,000"?

**Concept exercise**

> Explain how you'd make a product team genuinely care about its cloud cost **without
> billing them a single dollar** — describe the mechanism and why it works, without
> using the word "chargeback."

**Trade-off / debugging exercise**

> You enforce `require-cost-labels` and flip it to Enforce. Overnight, OpenCost's
> per-team report still shows 40% of cost under `__unallocated__`. The policy reports no
> violations. What are the two most likely causes, and how would you confirm each?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Showback *shows* a team its cost with no money moving; chargeback *bills* the
  team's budget. Showback comes first because it builds trust in the data you need
  before anyone will accept a real invoice.
- **Q2:** `team` (who pays), `environment` (prod vs dev split), `cost-center` (which
  budget), `app.kubernetes.io/name` (which service).
- **Q3:** OpenCost aggregates cost by **pod** labels; labels only on the Deployment's
  metadata never reach the pods, so label-based attribution comes back empty.
- **Q4:** Audit → read policy reports to size the gap → backfill existing workloads →
  Enforce. Audit gives you visibility into non-compliance without blocking anyone.
- **Q5:** It's a trend tied to a cause (a specific deploy), framing cost as a tunable
  engineering quality attribute rather than a blame-laden lump sum.
- **Trade-off:** Either (a) the labels are on the Deployment metadata but **not the pod
  template**, so OpenCost can't attribute them — confirm by inspecting a running pod's
  labels; or (b) workloads created *before* enforcement (or kinds the policy doesn't
  match, like bare Pods / Jobs / DaemonSets) remain unlabeled — confirm by listing pods
  without the `team` label across namespaces.

</details>

---

## 9. Further reading

- FinOps Foundation — [Chargeback and showback](https://www.finops.org/framework/capabilities/invoicing-chargeback/)
- OpenCost — [Allocation API and aggregation](https://www.opencost.io/docs/integrations/api)
- Kyverno — [Validate rules](https://kyverno.io/docs/writing-policies/validate/) and [require labels sample](https://kyverno.io/policies/other/require-labels/require-labels/)
- Kyverno — [Mutate rules](https://kyverno.io/docs/writing-policies/mutate/) (defaulting labels)
- Slack — [Incoming webhooks](https://api.slack.com/messaging/webhooks) (for the weekly report)
- FinOps Foundation — [Allocation (cost allocation capability)](https://www.finops.org/framework/capabilities/allocation/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 18.2 — Kubernetes Cost Management](../02-kubernetes-cost-management/) · _Next:_ [Module 18.4 — Cost Optimization Patterns →](../04-cost-optimization-patterns/)
