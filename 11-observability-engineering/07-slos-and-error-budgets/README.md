# Module 11.7 — SLOs and Error Budgets

> Not everything that twitches deserves a page. **SLOs** turn "is it healthy?" into a
> precise, user-centred target, and **error budgets** turn reliability into a number
> you can spend. This module defines SLI/SLO/SLA, shows how **multi-window,
> multi-burn-rate** alerting replaces noisy threshold alerts, and uses **Sloth** to
> generate it all from one small spec.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** [Module 11.3](../03-metrics-with-prometheus/) and
[Docker](https://docs.docker.com/) (optionally kind + Helm for the live extension).

## Learning objectives

By the end of this module you will be able to:

- Distinguish **SLI**, **SLO**, and **SLA** and write a good SLI from existing metrics.
- Compute an **error budget** and explain what "spending" it means.
- Explain **burn rate** and design **multi-window, multi-burn-rate** alerts.
- Generate SLO recording and alert rules with **Sloth** from a single definition.
- Pick platform-relevant SLOs and avoid the classic SLO anti-patterns.

---

## 1. Concept

### SLI, SLO, SLA

Three terms, often muddled, with a strict hierarchy:

- **SLI — Service Level Indicator.** The *measured* number: the proportion of good
  events over valid events. "The fraction of HTTP requests that return non-5xx in
  under 300ms." An SLI is a ratio between 0 and 1, computed from the metrics you
  already collect (Module 11.3).
- **SLO — Service Level Objective.** The *target* for the SLI over a window: "99.9% of
  requests are good over 30 days." Internal, chosen by you, and the thing you actually
  engineer toward.
- **SLA — Service Level Agreement.** The *external, contractual* promise to customers,
  usually with financial penalties: "99.5% uptime or you get a credit." An SLA is a
  business/legal artifact; your SLO should be **stricter** than your SLA so you notice
  trouble before a breach.

> Rule of thumb: SLI is what you *measure*, SLO is what you *target*, SLA is what you
> *promise* (and pay for if you miss). Alert on the SLO; never let the SLA be your
> first warning.

A good SLI is **user-centred** and **event-based**: good events ÷ valid events, where
"good" reflects what a user actually experiences (fast, correct responses), not an
internal proxy like CPU.

### Error budgets

If your SLO is 99.9%, you are explicitly saying **0.1% of events are allowed to be
bad**. That 0.1% is your **error budget** — a concrete allowance of failure over the
window:

```text
SLO 99.9% over 30 days
  error budget = 100% − 99.9% = 0.1%
  at ~43,200,000 requests/30d  →  ~43,200 requests may fail before you breach
```

The error budget reframes reliability from "never fail" (impossible, infinitely
expensive) to "fail no more than *this much*." It is also a **shared currency**
between platform/SRE and product teams:

- Budget **remaining** → you can afford to ship risky changes, run chaos experiments,
  move fast.
- Budget **exhausted** → freeze risky releases and spend effort on reliability until
  it recovers.

An error budget makes the speed-versus-reliability trade *explicit and data-driven*
instead of an argument.

### Burn rate

**Burn rate** is how fast you are spending the budget relative to "sustainable."

```text
burn rate = (observed error ratio) / (1 − SLO)

  burn rate 1   → spending budget exactly fast enough to run out at window's end
  burn rate 2   → budget gone in half the window
  burn rate 14.4→ an entire month's budget gone in ~2 days
```

Burn rate is the key to *good* alerting: instead of "error ratio > 5%", you alert when
you are **burning budget fast enough to care**, scaled to your SLO.

### Multi-window, multi-burn-rate alerting

Naïve budget alerts have a dilemma. Alert on a **short** window and you page on every
transient blip (noisy, non-actionable). Alert on a **long** window and you react too
slowly to a real outage. The Google SRE solution is **multi-window, multi-burn-rate**:

- Require a **fast burn** over both a **long** and a **short** window before paging —
  the long window proves it is sustained; the short window makes the alert **reset
  quickly** once the incident ends.
- Use **several tiers**: a high burn rate pages immediately; a lower burn rate over a
  longer window opens a ticket.

The canonical table (for a 30-day SLO):

```text
severity  long win  short win  burn rate  budget consumed   meaning
────────  ────────  ─────────  ─────────  ───────────────   ───────────────────────
page       1h        5m         14.4       2%  in 1h         fast burn — wake someone
page       6h        30m        6          5%  in 6h         sustained fast burn
ticket     1d        2h         3          10% in 1d         slow burn — investigate
ticket     3d        6h         1          10% in 3d         chronic drain — plan work
```

You alert on **symptoms scaled to the budget**, not raw thresholds — far fewer, far
more meaningful pages.

### SLO tooling: Sloth and Pyrra

Hand-writing the recording rules (the SLI at every window) and the four multi-window
alert expressions per SLO is tedious and error-prone. Tools generate them from one
small spec:

- **Sloth** — you write a `PrometheusServiceLevel` (service, objective, an
  error/total query), and `sloth generate` expands it into a complete `PrometheusRule`:
  SLI recording rules at all windows, budget/metadata rules, and the multi-window
  burn-rate `page`/`ticket` alerts. Declarative SLOs as code.
- **Pyrra** — a similar SLO manager with a UI, running as a controller that reconciles
  SLO objects into rules and shows budget/burn dashboards.

Both encode the Google SRE methodology so you do not re-derive burn-rate math per
service — exactly the kind of leverage a platform provides.

---

## 2. Why it matters for platform engineering

- **SLOs are how a platform defines "working."** Platform services (Argo CD, the
  ingress, the registry, the metrics pipeline) need published SLOs so teams know what
  to expect and you know when *you* are failing *them*.
- **Error budgets govern platform change.** The platform ships constantly; the budget
  tells you when to slow down. It turns "should we risk this upgrade?" into a number.
- **Good alerting is a platform gift.** Teams drowning in threshold alerts get a
  template: define an SLI, and burn-rate alerts are generated for them. You hand out
  *actionable* paging, not noise — a huge cognitive-load win.
- **It makes reliability a conversation, not a blame game.** A shared budget aligns
  platform, SRE, and product on one number instead of competing anecdotes.

---

## 3. Mental model

An error budget is a **prepaid balance of failure**; burn rate is how fast you are
drawing it down; multi-window alerts are **two clocks** that must agree before they
wake you.

```text
   budget = (1 − SLO) × events        ← a balance you may spend
      │
      │  incidents withdraw from it at the BURN RATE
      ▼
   ┌───────────────────────────────────────────────┐
   │  fast burn (14.4×)  → short+long window agree → PAGE │  "bleeding now"
   │  slow burn (3×)     → long window only        → TICKET│ "chronic leak"
   └───────────────────────────────────────────────┘
        short window = fast reset   long window = proof it's sustained

   Spend budget? ship fast.  Budget gone? freeze features, fix reliability.
```

Rule of thumb: **page on fast burn, ticket on slow burn, and never page on anything a
human cannot act on.** If an alert is not tied to budget burn or user pain, it is
probably noise.

---

## 4. Minimal implementation

The whole method fits in a few PromQL lines. Start from an event-based SLI — good vs
total — using metrics you already have:

```promql
# SLI: the BAD-event ratio over a window (lower is better)
sum(rate(http_requests_total{code=~"5.."}[5m]))
  /
sum(rate(http_requests_total[5m]))
```

Turn it into a **burn rate** by dividing by the budget, then page when a fast burn
holds over **both** a short and a long window:

```promql
# page: budget burning ~14.4x over 1h AND 5m (SLO = 99.9%, budget = 0.001)
(
  sum(rate(http_requests_total{code=~"5.."}[1h])) / sum(rate(http_requests_total[1h]))
) / 0.001 > 14.4
and
(
  sum(rate(http_requests_total{code=~"5.."}[5m])) / sum(rate(http_requests_total[5m]))
) / 0.001 > 14.4
```

Writing that by hand for every window and every service is exactly the toil Sloth
removes. The same SLO as a Sloth spec is a dozen readable lines:

```yaml
version: "prometheus/v1"
service: checkout
slos:
  - name: requests-availability
    objective: 99.9
    sli:
      events:
        error_query: sum(rate(http_requests_total{job="checkout",code=~"5.."}[{{.window}}]))
        total_query: sum(rate(http_requests_total{job="checkout"}[{{.window}}]))
    alerting:
      page_alert: { labels: { severity: page } }
      ticket_alert: { labels: { severity: ticket } }
```

`sloth generate` expands that into all the recording rules and multi-window alerts for
you. The lab runs exactly this and reads the generated output.

---

## 5. Hands-on lab

You will write an SLO as a Sloth `PrometheusServiceLevel`, run `sloth generate` to
expand it into a full `PrometheusRule` (SLI recording rules at every window plus
multi-window burn-rate `page`/`ticket` alerts), and read the generated alerting to see
the Google SRE method made concrete.

➡️ **[Start the lab: SLOs and burn-rate alerts with Sloth](./lab/README.md)**

## 6. Production considerations

- **Choose SLIs users feel.** Availability and latency of user-facing requests, not
  CPU or a liveness probe. An SLO on the wrong indicator is green while users suffer.
- **Set SLOs stricter than SLAs.** Your internal target must trip before the
  contractual promise so you act before a breach and a credit.
- **Enforce the error-budget policy.** Agree *in advance* what happens at zero budget
  (freeze risky releases, reprioritize reliability). An unenforced budget is theatre.
- **Prefer multi-window burn-rate alerts.** They cut false pages dramatically and reset
  fast when incidents end. Retire single-threshold alerts that page on transient blips.
- **Keep SLOs as code and review them.** Sloth/Pyrra specs in Git, rendered into
  `PrometheusRule`s and deployed via GitOps (Phase 8). SLOs change; version them.
- **Do not over-SLO.** A few meaningful SLOs per service beat dozens nobody watches.
  Every SLO needs an owner, a dashboard, and a runbook (Module 11.8).

## 7. Common mistakes

- **SLIs on the wrong signal.** — An SLO on CPU or uptime-ping can read 100% while
  users get errors. *Fix:* event-based, user-centred SLIs (good requests ÷ valid
  requests).
- **SLO equals SLA (or is looser).** — You find out you breached the contract from the
  customer. *Fix:* set the SLO tighter than the SLA with margin to react.
- **Single-threshold budget alerts.** — Short windows page on blips; long windows react
  too late. *Fix:* multi-window, multi-burn-rate alerts (page on fast burn, ticket on
  slow).
- **100% as a target.** — Chasing 100% is infinitely costly and leaves no budget for
  change. *Fix:* pick an achievable target (99.9%, 99.95%) and *use* the resulting
  budget.
- **Ignoring the budget once set.** — Teams keep shipping with the budget at zero.
  *Fix:* a written, enforced error-budget policy with agreed consequences.
- **Burning effort on too many SLOs.** — Dozens of SLOs per service become noise nobody
  trusts. *Fix:* a handful of meaningful ones, each owned and runbooked.

## 8. Assessment

**Knowledge checks**

1. Define SLI, SLO, and SLA, and state which one you alert on and why.
2. For a 99.95% SLO over 30 days, what is the error budget, and what does "spending
   it" let a team do?
3. What is burn rate, and what does a burn rate of 14.4 mean for a 30-day budget?
4. Why does a multi-window alert use both a short and a long window?
5. What does Sloth generate from a single `PrometheusServiceLevel`?

**Concept exercise**

> Explain to a product manager how "99.9% reliable" lets the team **ship features
> faster** — **without using the words "SLA," "burn rate," or "alert."** Frame it
> around a budget they can choose to spend.

**Trade-off / debugging exercise**

> A team pages on `error_ratio > 1%` for 2 minutes. They get paged several times a
> night for blips that self-heal, and they *also* missed a slow 6-hour degradation that
> breached their SLO. Explain why one rule produces both failures, and design the
> alerting that fixes both — with specific windows and burn rates.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** SLI = measured good/valid ratio; SLO = internal target for it; SLA = external
  contractual promise. You alert on the SLO (via burn rate) so you act before the SLA
  is breached.
- **Q2:** Budget = 0.05% of valid events over 30 days. While budget remains, the team
  can ship risky changes, run experiments, and move fast; when it is gone, they slow
  down and invest in reliability.
- **Q3:** Burn rate = error ratio ÷ (1 − SLO). 14.4 means you would exhaust a 30-day
  budget in about two days — a fast burn worth paging on.
- **Q4:** The long window proves the burn is *sustained* (not a blip); the short window
  makes the alert **fire quickly** and, crucially, **reset quickly** once the incident
  ends.
- **Q5:** All the SLI recording rules at each window, budget/metadata rules, and the
  multi-window, multi-burn-rate `page` and `ticket` alerts — a complete `PrometheusRule`.
- **Debugging:** A single short-window threshold both over-fires on transient blips
  (short window, low bar) and under-detects slow burns (no long-window tier). Replace
  it with multi-window multi-burn-rate: page when burn ≥ 14.4 over 1h **and** 5m, and
  when ≥ 6 over 6h **and** 30m; ticket when ≥ 3 over 1d/2h and ≥ 1 over 3d/6h. The slow
  6-hour degradation trips the 6h/6× page tier; the blips no longer page because they
  fail the long-window condition.

</details>

---

## 9. Further reading

- Google — [SRE Book: Service Level Objectives](https://sre.google/sre-book/service-level-objectives/)
- Google — [SRE Workbook: Implementing SLOs](https://sre.google/workbook/implementing-slos/)
  and [Alerting on SLOs](https://sre.google/workbook/alerting-on-slos/)
- Sloth — [Documentation](https://sloth.dev/) and
  [GitHub](https://github.com/slok/sloth)
- Pyrra — [SLO manager](https://github.com/pyrra-dev/pyrra)
- Prometheus — [Alerting rules](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 11.6 — Grafana Dashboards](../06-grafana-dashboards/)
· _Next:_ [Module 11.8 — Platform Observability Strategy →](../08-platform-observability-strategy/)
