# Module 08.6 — GitOps Maturity Model

> "Do we do GitOps?" is the wrong question — it's not a yes/no. This module gives you
> a **maturity model**: five honest levels from "manual `kubectl`" to "adaptive
> platform GitOps," a way to assess where a real platform sits, and the discipline to
> pick the single next rung instead of chasing the top. It's also your bridge into
> Project 2, where you build toward Level 3.

**Estimated effort:** ~1.5–2 hours (theory + self-assessment)
**You'll need:** [Modules 08.1–08.5](../01-gitops-principles/). This is a reflection and assessment module — no cluster required.

## Learning objectives

By the end of this module you will be able to:

- Describe the **five GitOps maturity levels** and what distinguishes each.
- **Assess** a platform's maturity across concrete dimensions, honestly.
- Identify the **single highest-value next step** rather than boiling the ocean.
- Recognize **maturity theater** — tools adopted without the practice.
- Connect the model to the **platform you'll build in Project 2**.

---

## 1. Concept

Maturity isn't about owning the most tools; it's about how much of your delivery is
**declarative, pulled, continuously reconciled, and safe** — and how much is still
manual, tribal, or risky. Here is a five-level model (adapted from community GitOps
and CNCF maturity work) with the signals that place a platform at each level.

### Level 0 — No GitOps

- Changes are `kubectl apply`, `helm upgrade`, or console clicks done by hand.
- Knowledge lives in scripts, runbooks, and people's heads.
- **No audit trail**: "who changed prod, when, why?" has no reliable answer.
- *Signal:* the cluster is a pet; nobody is sure it could be rebuilt from Git.

### Level 1 — Manual GitOps

- Declarative config lives in Git (the source of truth is written down).
- But sync is **manual** — a human runs the deploy — and there's **no self-healing or
  drift detection**.
- You get *some* audit trail (commits), but the cluster can still silently diverge
  from Git.
- *Signal:* "it's all in Git" is true, yet drift and manual steps remain.

### Level 2 — Automated GitOps

- **Auto-sync** is on: merges reconcile without a human.
- **Self-healing** corrects out-of-band drift; the cluster converges to Git.
- Simple apps may get an **image updater** that bumps tags automatically.
- *Signal:* for application delivery, the reconcile loop runs itself.

### Level 3 — Full Platform GitOps

- **All** cluster configuration — not just apps, but ingress, RBAC, operators,
  add-ons — is managed via GitOps.
- **Secrets** are handled safely (ESO or equivalent), never plaintext in Git.
- **Multi-environment promotion** is automated (overlay bump → PR → auto-sync) with
  a production gate.
- **Drift alerts** and breaking-change detection are wired into observability.
- *Signal:* a new cluster can be bootstrapped from Git, secrets and all. **This is the
  target for Project 2.**

### Level 4 — Adaptive Platform GitOps

- **Progressive delivery** (Argo Rollouts / Flagger) — canary/blue-green with
  automated analysis and rollback — is integrated into sync.
- **Cross-cluster GitOps** manages a fleet from one control plane.
- **Policy evaluation** (OPA/Kyverno) runs as part of the sync, so non-compliant
  changes are rejected before they land.
- **Cluster bootstrapping** is automated: stand up a new cluster and it configures
  itself.
- *Signal:* delivery is self-driving and self-governing across many clusters.

```text
 L0 ──────► L1 ──────► L2 ──────► L3 ──────► L4
 manual     in Git,    auto-sync  whole      progressive,
 kubectl    manual     + self-    platform   multi-cluster,
 no audit   sync       heal       in GitOps  policy-gated
                                  + secrets  + bootstrap
   │          │          │          │           │
   └──────────┴──────────┴──────────┴───────────┘
   how much of delivery is declarative, pulled, reconciled, and safe?
```

### Dimensions, not a single number

A platform is rarely cleanly "a Level 2." Assess it across **dimensions** and you'll
see a realistic, jagged profile:

- **Source of truth** — is all state in Git, or just some?
- **Sync automation** — manual, auto-sync, or fully hands-off?
- **Drift & self-healing** — detected? corrected? alerted?
- **Secrets** — plaintext (danger), Sealed/SOPS, or a managed store via ESO?
- **Promotion** — manual per env, or PR-driven with gates?
- **Scope** — apps only, or all cluster config and add-ons?
- **Progressive delivery** — big-bang sync, or canary with analysis?
- **Multi-cluster** — one cluster, or a fleet from one control plane?
- **Policy & compliance** — reviewed by humans, or enforced at sync?
- **Observability** — can you see sync status, drift, and failures, and alert on them?

Your **overall** level is best read as the *lowest* dimension that still causes real
pain — because that's what breaks first. A platform with slick progressive delivery
but plaintext secrets in Git is not "Level 4"; it's a Level 3 practice with a Level 0
security hole.

---

## 2. Why it matters for platform engineering

A maturity model is a planning and communication tool, not a vanity score:

- **It creates a shared language.** "We're Level 2 and want Level 3 by Q3, starting
  with secrets" communicates strategy to leadership and teams in one line.
- **It prevents over- and under-investing.** Many platforms rush to progressive
  delivery (Level 4 shininess) while still hand-syncing prod or committing secrets.
  The model forces you to fix the foundation first.
- **It turns a vague goal into a roadmap.** Assess dimensions, find the lowest painful
  one, and that's your next quarter's work — concrete and defensible.
- **It sets expectations honestly.** Maturity is earned rung by rung; you can't buy
  Level 4 by installing a tool. Naming the levels keeps everyone grounded.
- **It frames Project 2.** The next thing you build in this course is a Level 3
  platform: all config in Git, ESO for secrets, multi-env promotion, drift alerts.
  This module is how you'll know you got there.

---

## 3. Mental model

Maturity is a **ladder you climb one rung at a time**, and each rung widens how much
of delivery the reconcile loop owns — from one app, to all apps, to all config, to
the whole fleet under policy.

```text
   coverage of the reconcile loop grows as you climb:

   L0  nothing reconciles (manual)                     □□□□□
   L1  Git holds state, humans sync                    ■□□□□
   L2  apps auto-sync and self-heal                    ■■□□□
   L3  ALL config + secrets + promotion, with alerts   ■■■■□   ← Project 2 target
   L4  + progressive delivery, fleet, policy gates      ■■■■■
```

Three rules to remember:

1. **Assess by dimensions; score by the weakest painful one.** The lowest rung that
   hurts is your real level.
2. **Climb the next rung, not the tallest.** The best next step removes your current
   biggest pain — usually secrets or manual prod sync, not a canary engine.
3. **Tools are not maturity.** Installing Argo Rollouts doesn't make you Level 4;
   *practicing* progressive delivery does.

---

## 4. Minimal implementation

A maturity assessment is just a scored rubric. Rate each dimension 0–4, note the
evidence, and read off the weakest painful rung:

```text
dimension            level  evidence
-------------------  -----  ---------------------------------------------------
source of truth        3    apps + most config in Git; a few manual add-ons
sync automation        2    auto-sync on; prod still manually synced (by design)
drift & self-healing   2    self-heal on; no drift ALERTING yet
secrets                1    Sealed Secrets for some; two plaintext Secrets remain  ← weakest, and risky
promotion              2    overlays + PRs; promotion not automated from CI
...                    ...  ...
-------------------  -----  ---------------------------------------------------
overall: Level 2 (secrets at 1 is the dangerous outlier → fix first)
next step: migrate the two plaintext Secrets to ESO; add drift alerts
```

The output isn't the number — it's the **one prioritized next step** the number
justifies. That's exactly what the lab produces for a platform you choose.

---

## 5. Hands-on lab

You'll run a structured self-assessment: score a platform (a real one you know, or the
provided fictional scenario) across the maturity dimensions, compute an honest overall
level, and write a single prioritized next step with its justification. The deliverable
is a maturity rating plus a next-step plan — the artifact a platform team actually
presents.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **Measure, don't guess.** Back scores with evidence: sync status dashboards, drift
  reports, "percentage of config under GitOps," time-to-rollback. A maturity claim you
  can't show is theater.
- **Beware maturity theater.** Argo Rollouts installed but every release still
  big-bangs; ESO present but secrets still committed "temporarily." The tool is not
  the practice.
- **Sequence by risk, then value.** A Level 0 dimension in **secrets** or **audit**
  outranks a shiny Level 4 feature elsewhere — fix the dangerous outlier first.
- **Organizational maturity matters too.** Who can approve a prod sync? Is there
  on-call for failed syncs? Culture and process gate how high the tech can climb.
- **It's never "done."** Like the platform itself (Module 01.1), maturity has a
  roadmap, not a finish line; re-assess periodically as scope and scale grow.
- **Right-size the target.** Not every platform needs Level 4. A small team may
  rationally stop at a solid Level 3. Match the level to the stakes, not to fashion.

---

## 7. Common mistakes

- **Treating maturity as a single number.** It hides a dangerous low dimension behind
  a flattering average. *Fix:* score dimensions; act on the weakest painful one.
- **Chasing Level 4 with a Level 1 foundation.** Canary deploys while prod is
  hand-synced and secrets sit in Git. *Fix:* climb the next rung; secure the base
  first.
- **Confusing tools with practice (maturity theater).** "We have Rollouts/ESO" while
  not actually doing progressive delivery or removing plaintext secrets. *Fix:* assess
  the practice and its evidence, not the install list.
- **Assessing without evidence.** Optimistic self-scores that don't survive an
  incident. *Fix:* require a dashboard, report, or metric behind each score.
- **One-and-done assessment.** Scoring once and never revisiting as the platform
  grows. *Fix:* re-assess on a cadence; maturity drifts like everything else.
- **Copying someone else's target level.** Adopting Level 4 goals that your stakes
  don't warrant. *Fix:* choose a target proportional to your reliability and
  compliance needs.

---

## 8. Assessment

**Knowledge checks**

1. In one line each, what distinguishes Level 1 from Level 2, and Level 2 from Level 3?
2. Why read overall maturity as the *weakest painful dimension* rather than an average?
3. Give a concrete example of "maturity theater."
4. Which maturity level is the target for Project 2, and name three of its properties.
5. Why isn't "install Argo Rollouts" enough to be Level 4?

**Concept exercise**

> Describe how you'd judge a team's delivery maturity **without naming any tool or any
> maturity level number.** Phrase it entirely in terms of behavior — what's declared,
> what's automated, what's reconciled, what's safe — so it would apply to any stack.

**Trade-off / debugging exercise**

> A platform has automated canary deployments and multi-cluster sync, but two database
> passwords are committed as base64 Secrets and production is still synced by hand.
> What overall level is this, and why? Name the first two next steps and justify the
> order against the dimensions.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** L1→L2: sync becomes automatic and the cluster self-heals drift (vs. manual
  sync, no drift correction). L2→L3: scope expands from apps to **all** config, plus
  safe secrets, automated multi-env promotion, and drift alerting.
- **Q2:** An average hides a dangerous low dimension (e.g. plaintext secrets) that will
  break or breach first; the weakest painful rung is what actually limits you.
- **Q3:** Having ESO or Argo Rollouts installed while secrets are still committed to
  Git or every release still big-bangs — the tool without the practice.
- **Q4:** **Level 3** (Full Platform GitOps): all cluster config in Git, secrets via
  ESO (no plaintext), automated multi-environment promotion with a prod gate, drift
  alerts.
- **Q5:** Maturity is the *practice*, not the install; Level 4 means you actually run
  analyzed canaries with automated rollback across the fleet, not that a controller
  exists.
- **Debugging:** Despite Level 4 features, committed secrets (Level 0 on the secrets
  dimension) make this a **Level 1–2 platform with a critical security hole**. First
  steps: (1) rotate and migrate the two secrets to a managed store (ESO) — it's a live
  breach; (2) add a production sync gate/policy and drift alerting. Security and audit
  outrank progressive-delivery polish.

</details>

---

## 9. Further reading

- OpenGitOps — [Principles](https://opengitops.dev/) (the yardstick maturity measures
  against)
- CNCF — [Platform Engineering Maturity Model](https://tag-app-delivery.cncf.io/whitepapers/platform-eng-maturity-model/)
- Argo — [Rollouts (progressive delivery)](https://argo-rollouts.readthedocs.io/en/stable/)
  and [Flagger](https://flagger.app/)
- CNCF — [GitOps WG and OpenGitOps project](https://github.com/open-gitops/project)
- Codefresh — [GitOps maturity and best practices](https://codefresh.io/learn/gitops/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [08.5 — Secrets in GitOps](../05-secrets-in-gitops/)
· _Next:_ [09 · Platform Project 02 — GitOps Platform →](../../09-platform-project-02/)
