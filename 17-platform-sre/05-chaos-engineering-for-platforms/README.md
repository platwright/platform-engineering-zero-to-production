# Module 17.5 — Chaos Engineering for Platforms

> You do not actually know your platform is resilient until you break it on purpose.
> **Chaos engineering** injects controlled failure — killed pods, network latency, a
> dead dependency — to find weaknesses *before* your users do, and to prove that your
> SLOs hold, your alerts fire, and your runbooks work. This module frames chaos as a
> disciplined experiment and runs three against real platform components.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 17.2](../02-platform-slos/) (SLOs/alerts) and
[Module 17.3](../03-platform-incident-management/) (runbooks), a local
[kind](https://kind.sigs.k8s.io/) cluster, `kubectl`, and
[Chaos Mesh](https://chaos-mesh.org/) (installed in the lab, free and local).

## Learning objectives

By the end of this module you will be able to:

- Define chaos engineering as a **controlled experiment**, not random breakage.
- Write a **steady-state hypothesis** that says what "normal" looks like before you
  inject failure.
- Enumerate the **platform failure modes** worth testing.
- Author **Chaos Mesh** experiments (pod kill, network latency) against platform
  components.
- Run a **GameDay** and read its results: did SLOs hold, alerts fire, runbooks work?

---

## 1. Concept

### Chaos engineering is an experiment, not vandalism

Chaos engineering is the practice of **deliberately injecting failure into a system to
build confidence in its ability to withstand turbulent conditions.** The key word is
*confidence*: you are not breaking things for fun, you are running a **scientific
experiment** to test a belief about resilience. Real failures are inevitable; chaos
engineering just schedules them for a time when the team is watching, the blast radius
is contained, and you can learn safely.

The method mirrors the scientific method:

```text
1. STEADY STATE   define a measurable "normal" (an SLI: syncs succeeding, p99 latency)
2. HYPOTHESIS     "when I kill a third of Argo CD pods, steady state HOLDS"
3. INJECT         introduce the failure in the smallest blast radius that tests it
4. OBSERVE        did steady state hold? did the SLO stay green? did alerts fire?
5. LEARN          weakness found → fix it (and add a runbook); held → confidence up
```

### The steady-state hypothesis

The foundation of a good experiment is the **steady-state hypothesis**: a *measurable*
definition of normal system behavior, expressed as the SLIs you built in Module 17.2.
You state it **before** injecting failure, and you predict it will *keep holding*
through the failure.

```text
Weak:   "Argo CD should be fine."                        (not measurable)
Strong: "Argo CD app-sync success stays >= 99% and the
         API p99 stays < 500ms while a third of its pods
         are killed."                                    (measurable → falsifiable)
```

A strong hypothesis is **falsifiable** — the experiment can prove it wrong. If the
steady state breaks, you have found a real weakness; if it holds, you have earned real
confidence. Vague hypotheses ("it should work") teach you nothing.

### Control the blast radius

Chaos is controlled failure, so every experiment has guardrails:

- **Start small.** One pod before a third; one component before the whole namespace;
  a dev cluster before production.
- **Define abort conditions.** Decide in advance the signal that means "stop the
  experiment now" (e.g. real user-facing SLO starts burning) and how to halt it.
- **Announce it.** A chaos experiment should not look like a real incident to the rest
  of the org — tell people, or run it as a scheduled GameDay.
- **Prefer a kill switch.** Chaos Mesh experiments have a `duration` and can be deleted
  instantly; never inject failure you cannot immediately undo.

### Platform failure modes worth testing

Point chaos at the failures that actually take platforms down:

```text
failure mode              example injection                 what it tests
────────────────────────  ────────────────────────────────  ──────────────────────────
control-plane / component  kill a third of Argo CD pods      does the service tolerate
unavailability                                               losing replicas?
dependency failure         delete the ESO pod                do dependents degrade or die?
network degradation        +500ms latency to Prometheus      graceful degradation vs
                                                             total blackout?
node failure               drain / kill a node               do pods reschedule in time?
network partition          cut a namespace off               split-brain? stuck sync?
storage failure            fail a PVC / slow I/O              data-plane resilience
```

The three you run in the lab cover the first three — the most common platform
failure modes — against Argo CD, Prometheus, and the External Secrets Operator.

### Tools: Chaos Mesh and Litmus

You could `kubectl delete pod` by hand, but real chaos tooling gives you *controlled,
declarative, repeatable* fault injection with selectors, scheduling, and a kill
switch:

- **Chaos Mesh** — a CNCF, Kubernetes-native chaos platform. Faults are CRDs
  (`PodChaos`, `NetworkChaos`, `StressChaos`, `IOChaos`, …) with label selectors, a
  `mode` (one / fixed-percent / all), and a `duration`. Declarative chaos, applied and
  removed like any manifest — which is exactly why the lab uses it.
- **Litmus** — another CNCF chaos framework, organized around reusable *chaos
  experiments* and *workflows*, with a hub of predefined faults and GameDay tooling.

Both encode the discipline so your experiments are versioned, scoped, and reversible
rather than ad-hoc `kubectl delete`.

### GameDays and reading the results

A **GameDay** is a scheduled, structured chaos exercise with the platform team in the
room: you pick a failure mode, state the hypothesis, inject it, and watch the system
*and the team's response* together. The GameDay tests three layers at once, and the
results are judged against each:

```text
layer        the question                              a failing result
───────────  ────────────────────────────────────────  ─────────────────────────────
the system   did the steady-state SLO hold?            sync failed when pods died
the signals  did the right alert fire (and only it)?   no alert, or alert storm
the humans   did the runbook work? was the IC clear?   runbook missing/wrong/slow
```

That last column is the point: chaos does not just test the software, it tests your
**SLOs, alerts, and runbooks** — the whole Module 17.2/17.3 machinery — under
realistic failure, while it is safe to find the gaps.

---

## 2. Why it matters for platform engineering

- **Your resilience claims are untested until you test them.** "Argo CD is HA" is a
  hope until you kill a third of its pods and watch syncs continue. Chaos converts
  hope into evidence — exactly what a platform's many dependents need.
- **It validates the rest of this phase cheaply.** A GameDay exercises your SLOs
  (17.2), alerts, runbooks, and incident process (17.3) without a real outage. You find
  the missing runbook on a Tuesday afternoon, not at 3 a.m.
- **It finds the weakness before all teams feel it.** A platform failure hits everyone
  (Module 17.1), so proactively hunting failure modes has outsized value — one found
  weakness prevents an org-wide incident.
- **It builds a resilience culture.** Teams that routinely rehearse failure respond
  calmly to the real thing; teams that never do, panic.

---

## 3. Mental model

Chaos engineering is a **vaccine**: a small, controlled dose of the pathogen (failure),
given while the patient is monitored, so the system builds immunity before it meets the
real infection.

```text
   define STEADY STATE (measurable normal: SLO green)
          │
          ▼
   form a FALSIFIABLE HYPOTHESIS  "steady state HOLDS when I inject X"
          │
          ▼
   inject the smallest dose ───────► OBSERVE three layers:
   (one pod → a third → ...)          ├─ system: did the SLO hold?
   with a kill switch (duration)      ├─ signals: did the alert fire?
          │                           └─ humans: did the runbook work?
          ▼
   HELD → confidence earned     BROKE → weakness found → fix + runbook
          │                                   │
          └──────────────── repeat, widen blast radius ◄──┘
```

The durable idea: **a resilience you have not tested is a guess. Chaos turns the guess
into a measured result — safely, on your schedule.**

---

## 4. Minimal implementation

A chaos experiment is just a manifest plus a steady-state check. First, establish the
steady state (the thing you predict will keep holding):

```bash
# steady state: all Argo CD apps are Synced/Healthy and the API answers
kubectl -n argocd get applications
kubectl -n argocd get deploy
```

Then inject the smallest failure that tests the hypothesis — here, kill a third of
Argo CD's pods with Chaos Mesh:

```yaml
apiVersion: chaos-mesh.org/v1alpha1
kind: PodChaos
metadata:
  name: argocd-pod-kill
  namespace: chaos-testing
spec:
  action: pod-kill
  mode: fixed-percent
  value: "33"                 # a third of the matched pods
  selector:
    namespaces: ["argocd"]
    labelSelectors:
      app.kubernetes.io/part-of: argocd
```

Apply it, then immediately re-check the steady state — did syncs keep working while a
third of the pods restarted?

```bash
kubectl apply -f argocd-pod-kill.yaml
kubectl -n argocd get pods            # a third terminating/recreating
kubectl -n argocd get applications    # hypothesis: still Synced/Healthy
```

If the apps stayed healthy, the hypothesis held and you have *evidence* Argo CD
tolerates losing replicas. If not, you found a weakness worth a fix and a runbook. The
lab runs three such experiments and records the results.

## 5. Hands-on lab

You will install Chaos Mesh locally and run three experiments against platform
components — kill a third of Argo CD's pods, add 500ms latency to Prometheus, and
delete the External Secrets Operator pod — each framed by a steady-state hypothesis.
You will record, for each, whether the SLO held, alerts fired, and recovery worked.

➡️ **[Start the lab](./lab/README.md)**

## 6. Production considerations

- **Earn your way to production chaos.** Start in dev, with small blast radius and a
  team watching. Only run chaos in production once experiments are boring in staging
  and you trust the kill switch — then it is the most valuable (real traffic, real
  dependencies).
- **Always have a kill switch and abort conditions.** Every experiment needs a
  `duration` and a pre-agreed signal to stop (a real user SLO burning). Never inject a
  fault you cannot instantly remove.
- **Steady state must be a real user signal.** Hypothesize on SLOs users feel (sync
  success, request latency), not on internal proxies. An experiment that keeps CPU
  steady while users get errors proved nothing.
- **Automate the regression, keep GameDays human.** Turn proven experiments into
  scheduled, automated resilience tests (so a regression re-breaks loudly); keep
  periodic GameDays for the human layer — new failure modes, runbook rehearsal, IC
  practice.
- **Measure all three layers.** A "passed" experiment where no alert fired is a
  *failure* of your alerting even though the system survived. Record system, signals,
  and humans every time.
- **Respect data and tenants.** Scope selectors tightly; a careless `mode: all` on a
  shared cluster can hit tenants you did not intend. Blast-radius control is a safety
  requirement, not a nicety.

## 7. Common mistakes

- **No steady-state hypothesis.** — The team kills pods and eyeballs the result, with
  no measurable prediction. *Fix:* state a falsifiable SLO-based hypothesis before
  injecting anything.
- **Chaos with no blast-radius control.** — A production `mode: all` fault becomes a
  real incident. *Fix:* start with one pod, scope selectors tightly, set a `duration`,
  and define abort conditions.
- **Only testing the software.** — Judging success purely on "did it stay up?" and
  ignoring whether alerts fired and runbooks worked. *Fix:* grade all three layers —
  system, signals, humans.
- **Running chaos nobody announced.** — A real responder pages out on your experiment.
  *Fix:* schedule GameDays and communicate; distinguish chaos from incidents.
- **Stopping after a pass.** — One green experiment is treated as "we're resilient
  forever." *Fix:* widen the blast radius, vary the failure mode, and automate the
  experiment as a recurring regression test.
- **Injecting unrecoverable faults.** — A fault with no kill switch that outlives the
  experiment. *Fix:* prefer time-boxed, declaratively-removable faults (Chaos Mesh
  `duration`).

## 8. Assessment

**Knowledge checks**

1. In one sentence, what is chaos engineering *for*, and why is "experiment" the
   operative word?
2. What makes a steady-state hypothesis *strong*, and why must it be falsifiable?
3. Name four platform failure modes worth injecting, with an example of each.
4. What three layers does a GameDay test, and what is a failing result for each?
5. Why is "the system stayed up but no alert fired" a *failed* experiment?

**Concept exercise**

> Explain to a skeptical manager why deliberately breaking the platform makes it *more*
> reliable — **without using the words "chaos" or "experiment."**

**Trade-off / debugging exercise**

> You run "kill a third of Argo CD pods" and syncs keep working — the hypothesis holds.
> A teammate says "great, Argo CD is resilient, we're done." Give two reasons that
> conclusion is premature, and describe the next two experiments you would run and the
> hypotheses for each.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** To build *confidence* that the system withstands real failure by injecting
  controlled failure first; "experiment" because you test a measurable hypothesis and
  learn, rather than break things randomly.
- **Q2:** It is expressed as a measurable SLI with a threshold (e.g. sync success ≥
  99%, p99 < 500ms) so the experiment can *disprove* it. Falsifiability is what turns
  "it should be fine" into evidence either way.
- **Q3:** Component/control-plane unavailability (kill Argo CD pods), dependency
  failure (delete ESO), network degradation (+latency to Prometheus), node failure
  (drain a node); also network partition and storage failure.
- **Q4:** System (did the SLO hold? — fail: sync broke), signals (did the right alert
  fire? — fail: no alert or an alert storm), humans (did the runbook/IC work? — fail:
  missing or wrong runbook).
- **Q5:** Because detection is part of resilience: a failure that users would feel but
  that produces no page means you would be blind in a real incident — the alerting
  layer failed even though the system survived this time.
- **Trade-off:** Premature because (1) one blast radius (a third) and one failure mode
  were tested — losing *all* pods, or a network partition, may behave differently; and
  (2) you only checked the system, not whether alerts fired and the runbook worked.
  Next: inject +500ms latency to its dependency / Prometheus (hypothesis: dashboards
  degrade gracefully, alerts still fire), and kill a hard dependency like the ESO or a
  node (hypothesis: dependents retry and recover within the SLO), grading all three
  layers each time.

</details>

## 9. Further reading

- Principles of Chaos Engineering — [principlesofchaos.org](https://principlesofchaos.org/)
- Chaos Mesh — [Documentation](https://chaos-mesh.org/docs/) and
  [experiment types](https://chaos-mesh.org/docs/simulate-pod-chaos-on-kubernetes/)
- LitmusChaos — [Documentation](https://docs.litmuschaos.io/) (CNCF chaos framework)
- Google — [SRE Workbook: Testing for Reliability](https://sre.google/workbook/testing-reliability/)
- Netflix — [Chaos Engineering / Chaos Monkey](https://netflix.github.io/chaosmonkey/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [17.4 — Platform Capacity Planning](../04-platform-capacity-planning/)
· _Next:_ [17.6 — Disaster Recovery for Platform →](../06-disaster-recovery-for-platform/)
