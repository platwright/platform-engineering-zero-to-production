# Module 13.3 — Policy as Code with Kyverno

> Hardening only helps if every workload actually gets hardened. Asking each team to
> remember `runAsNonRoot`, resource limits, and no `:latest` tags is a checklist that
> decays. **Policy as code** turns those rules into enforced guardrails: a controller
> inspects every admission request and *blocks, mutates, or reports* on it before it
> reaches the cluster. This module uses **Kyverno** to make the security baseline
> structural — the same decision Project 1 recorded in ADR-004.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 10.3 · Admission Webhooks](../../10-kubernetes-advanced/03-admission-webhooks/),
[Module 02.5 · Container Security](../../02-containerization/05-container-security/),
and a working `kubectl` + [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain **policy as code** and where it sits in the admission pipeline.
- Choose between **Kyverno** and **OPA/Gatekeeper**, and justify the choice.
- Write Kyverno **validate**, **mutate**, and **generate** rules, and know when to use
  each.
- Roll out a policy safely from **Audit** to **Enforce** using policy reports.
- Design **controlled exceptions** so the paved road has escape hatches, not holes.

---

## 1. Concept

### From checklist to guardrail

Modules 02.5 and the Kubernetes security standards tell you *what* a safe workload
looks like: non-root, read-only root filesystem, dropped capabilities, resource
limits, a pinned image, required ownership labels. The hard part is not knowing the
rules — it's guaranteeing they are applied to *every* workload, forever, including the
one a tired engineer ships at 5pm on Friday.

There are two ways to get that guarantee. A **checklist** lives in a wiki and depends
on humans remembering. A **guardrail** lives in the cluster and depends on nothing:
the moment a non-compliant resource is submitted, it is rejected (or fixed, or logged)
automatically. Policy as code is how you build guardrails — the security baseline
expressed as declarative, version-controlled, testable rules that the cluster
enforces on its own.

### Where policy runs: admission control

Recall the admission pipeline (Module 10.3). Every write to the API server is
authenticated, authorized (RBAC, Module 13.2), then passed through **admission
controllers** before it is persisted to etcd:

```text
kubectl apply ─▶ API server ─▶ authn ─▶ authz (RBAC) ─▶ admission ─▶ etcd
                                                           │
                                   ┌───────────────────────┴───────────────┐
                                   │  mutating webhooks → validating webhooks│
                                   │  (Kyverno can do BOTH)                  │
                                   └─────────────────────────────────────────┘
```

A **policy engine** registers as a webhook. On every relevant request it can:

- **mutate** — change the object (inject a default `securityContext`, add a label)
  *before* validation, or
- **validate** — allow or deny based on a rule ("every container must set
  `runAsNonRoot: true`").

Because this happens at admission, the guarantee is airtight: there is no path into
the cluster that bypasses it, whether the request came from a human, a CI pipeline, an
Argo CD sync, or another controller.

### Kyverno vs OPA/Gatekeeper

The two mainstream Kubernetes policy engines are **Kyverno** and **OPA/Gatekeeper**.
Both do validating and mutating admission; the difference is how you *write* policy:

- **Kyverno** policies are **Kubernetes resources written in YAML**. The match/validate
  patterns look like the manifests your team already reads. No new language.
- **OPA/Gatekeeper** uses **Rego**, a powerful general-purpose policy language. More
  expressive for complex logic, but a separate language your policy authors must learn.

This course chooses Kyverno — the same reasoning as
[Project 1's ADR-004](../../04-platform-project-01/container-platform-foundation/architecture/decisions/ADR-004-why-kyverno.md):
lowest adoption friction for a YAML-fluent team, plus first-class **mutation**,
**generation**, and **image-signature verification** (Module 13.6), which fit a
platform's supply-chain goals. Gatekeeper remains an excellent choice when you need
Rego's expressiveness. The *concepts* here transfer to either.

### The four policy types

Kyverno rules come in four flavours — together they do far more than "block bad YAML":

- **validate** — accept or reject a resource against a pattern. The workhorse:
  "deny pods that run as root," "require resource limits," "forbid `:latest` in prod."
- **mutate** — modify a resource on the way in. Use it to apply *safe defaults* so
  teams get hardening for free: inject `seccompProfile: RuntimeDefault`, add
  `automountServiceAccountToken: false`, stamp cost-center labels.
- **generate** — create *related* resources automatically. When a namespace appears,
  generate its default-deny `NetworkPolicy`, a resource quota, or a baseline
  `RoleBinding`. The platform provisions guardrails, not just checks them.
- **verifyImages** — require a valid signature/attestation before an image may run
  (Module 13.6). The supply-chain enforcement point.

### ClusterPolicy vs Policy

- **`ClusterPolicy`** is cluster-scoped — it applies everywhere. Baseline security
  rules (no root, no `:latest`) are ClusterPolicies.
- **`Policy`** is namespace-scoped — it applies only within its namespace. Use it for
  team- or environment-specific rules a tenant may own.

### Audit vs Enforce: how to roll out without an outage

The single most important operational control is `validationFailureAction`:

- **`Audit`** — violations are *recorded* in policy reports but the resource is
  **admitted**. Nothing breaks. You learn how many workloads would fail.
- **`Enforce`** — violations are **rejected** at admission. The guardrail is live.

The golden rule: **start in Audit, measure, then flip to Enforce.** Shipping a new
`Enforce` policy against a cluster full of legacy workloads is how you cause an
incident and get policy-as-code banned. Audit first turns a scary change into a data
exercise: how big is the gap, who owns the violations, what has to change first?

Supporting machinery makes this safe at scale:

- **Policy reports** (`PolicyReport`, `ClusterPolicyReport`) give you a live,
  queryable list of pass/fail results per resource — visibility without blocking.
- **Background scanning** re-evaluates policies against *existing* resources on a
  schedule, so Audit covers what's already running, not just new admissions.
- **Policy exceptions** (`PolicyException`) are controlled, declarative escape
  hatches: "this specific workload in this namespace is exempt from this rule," in
  Git, reviewable — an opinionated default with a documented deviation, not a hole.

---

## 2. Why it matters for platform engineering

- **Security becomes structural.** The baseline is enforced by machinery, not trust.
  A team cannot *forget* to run non-root, because the cluster won't admit a root pod.
  This is the course's central theme made literal.
- **Fix once, protect everywhere.** A single ClusterPolicy secures every current and
  future namespace. No per-team review scales like that.
- **Mutation is a developer-experience feature.** Injecting safe defaults means teams
  get hardening *without writing it*. The golden path stays short; the guardrail does
  the boring part. Security that makes developers faster, not slower.
- **Generation provisions guardrails.** New namespace → default-deny network policy +
  quota appear automatically. The safe configuration is the default configuration.
- **Audits are reports, not fire drills.** Policy reports are standing evidence that
  the baseline holds — exactly what a compliance reviewer wants to see.

---

## 3. Mental model

Think of policy as an **automated reviewer standing at the cluster door** who never
sleeps, never forgets, and reviews *every* request identically:

```text
                         ┌──────────── Kyverno ────────────┐
   request ──▶ match? ──▶│  mutate   → apply safe defaults  │──▶ admitted (changed)
                │  no     │  generate → create companions   │
                ▼         │  validate →  pass ──────────────┼──▶ admitted
             ignored      │             fail ─┬─ Audit  ────┼──▶ admitted + report
                          │                   └─ Enforce ───┼──▶ REJECTED
                          └──────────────────────────────────┘

   Rollout order:   Audit (measure the gap) ──▶ fix owners ──▶ Enforce (close it)
```

Two rules to remember a year from now:

1. **Mutate to help, validate to enforce.** Give teams good defaults automatically;
   reject only what you cannot safely fix for them.
2. **Audit before Enforce, always.** You never flip a guardrail live without first
   measuring who it would break.

---

## 4. Minimal implementation

Before Kyverno, the "policy" for non-root containers is a sentence in a runbook, and
the only enforcement is code review. Prove the gap: on a plain cluster, a root pod is
admitted without complaint.

```bash
kubectl run rooted --image=nginx --restart=Never
# pod/rooted created   ← nothing stopped it; it runs as root by default
```

Now the smallest possible guardrail. Install Kyverno, then apply one ClusterPolicy
that requires `runAsNonRoot` — starting in **Audit** so it can't break anything:

```yaml
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-root-containers
spec:
  validationFailureAction: Audit   # measure first; flip to Enforce later
  rules:
    - name: check-run-as-non-root
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        message: "Containers must set securityContext.runAsNonRoot: true."
        pattern:
          spec:
            containers:
              - securityContext:
                  runAsNonRoot: true
```

In Audit mode, the root pod still runs, but a `PolicyReport` now records the
violation — you can *see* the gap. Change one word to `Enforce`, and the same
`kubectl run rooted ...` is rejected at admission with your message. That one-word
diff is the entire rollout model: observe, then enforce. The lab builds this into a
real baseline — no root, no `:latest` in prod, required limits, required labels.

---

## 5. Hands-on lab

You'll install Kyverno on a kind cluster and apply four real ClusterPolicies —
disallow-root, require-limits, disallow-latest-in-prod, and require-labels — first in
**Audit** to read the reports, then in **Enforce** to watch them block a bad pod and
admit a good one.

➡️ **[Start the lab](./lab/README.md)**

---

## 6. Production considerations

- **The webhook is in the critical path.** If Kyverno is down and a policy uses
  `failurePolicy: Fail`, admissions for matched resources are blocked. Run it
  highly-available (multiple replicas), set sensible `webhookTimeoutSeconds`, and
  decide per policy whether `Fail` (secure) or `Ignore` (available) is correct — a
  real availability-vs-security trade-off.
- **Scope matches narrowly.** Over-broad `match` blocks or heavy mutation on every
  request adds admission latency and blast radius. Exclude system namespaces
  (`kube-system`) deliberately; match the kinds you mean.
- **Policies are code — test them.** Use the Kyverno CLI (`kyverno test`,
  `kyverno apply`) in CI against fixture manifests so a bad policy fails the pipeline,
  not production. Ship policies via GitOps (Project 2) like any other change.
- **Exceptions must be governed.** `PolicyException` is powerful; without RBAC on who
  can create them and review in Git, your guardrails leak. Treat an exception like a
  signed waiver with an expiry.
- **Reports need a home.** Pipe `PolicyReport` data into your observability/ compliance
  stack (Policy Reporter UI, dashboards) so violations are visible and trend down.
- **Version and migrate.** New stricter policies follow the same Audit → communicate →
  Enforce path you'd use for any breaking platform change.

---

## 7. Common mistakes

- **Shipping `Enforce` on day one.** A new strict policy against legacy workloads
  causes instant, widespread admission failures and an incident. *Fix:* always start
  in `Audit`, read the reports, fix owners, *then* enforce.
- **No escape hatch.** A policy with zero exception mechanism forces teams to route
  around the platform (or around *you*) when they hit a legitimate edge case. *Fix:*
  governed `PolicyException` resources, in Git, reviewed and time-boxed.
- **Mutating when you should validate (or vice-versa).** Silently mutating a security
  field can hide a real problem; validating something you could safely default adds
  friction. *Fix:* mutate safe defaults, validate (reject) genuine policy breaches.
- **Forgetting `failurePolicy` math.** Leaving everything on `Fail` turns a Kyverno
  outage into a cluster-wide admission outage; leaving security policies on `Ignore`
  lets bad resources through when the engine hiccups. *Fix:* choose per policy,
  deliberately, and make Kyverno HA.
- **Policies that never get tested.** Hand-editing YAML in the cluster until it "looks
  right." *Fix:* `kyverno test` in CI with pass/fail fixtures.
- **Treating Kyverno as the only layer.** Admission can't see what a *running* pod
  does. *Fix:* pair policy (prevent) with runtime detection (Module 13.7, detect).

---

## 8. Assessment

**Knowledge checks**

1. At what point in the API request lifecycle does Kyverno act, and why does that make
   its guarantee hard to bypass?
2. What is the difference between `Audit` and `Enforce`, and why do you always start
   with the former?
3. Give a good use for each of validate, mutate, and generate.
4. When would you reach for OPA/Gatekeeper instead of Kyverno?

**Concept exercise**

> Explain how a platform guarantees every workload is non-root and has resource
> limits **without using the words "Kyverno," "admission webhook," or "policy
> engine."** Describe the mechanism and the guarantee, not the product.

**Trade-off / debugging exercise**

> You enforce a new `require-limits` ClusterPolicy at 09:00. By 09:05, Argo CD syncs
> are failing across six teams and nobody can deploy. Walk through what happened, how
> `failurePolicy` and `Audit` mode each relate to it, and the exact sequence you'd use
> to roll this out safely next time — including how you'd handle the legacy workloads
> that don't set limits yet.

<details>
<summary>Discussion (open after you've answered)</summary>

- **When/why:** Kyverno runs as a mutating+validating **admission webhook**, after
  authn/authz and before the object is written to etcd. Every write path — humans, CI,
  Argo CD, other controllers — goes through admission, so there is no side door.
- **Audit vs Enforce:** Audit records violations in policy reports but still admits the
  resource; Enforce rejects it. You start in Audit to measure the gap and fix owners
  before anything can break.
- **Uses:** validate — reject root pods / missing limits; mutate — inject
  `seccompProfile: RuntimeDefault` or default labels; generate — create a default-deny
  NetworkPolicy and quota when a namespace is created.
- **Gatekeeper:** when you need Rego's expressiveness for complex, cross-resource logic
  and your team is comfortable maintaining a policy language.
- **Debugging:** the `Enforce` policy rejected every pod without limits at admission;
  because Argo CD's applies hit the webhook, its syncs failed. With `Audit` first you'd
  have seen the violation count without breakage; `failurePolicy` governs what happens
  when Kyverno itself is unavailable (Fail = block, Ignore = allow). Safe rollout:
  deploy the policy as `Audit`, read `PolicyReport`s, give teams a deadline + a mutate
  rule or defaults to add limits, optionally add time-boxed `PolicyException`s for
  stragglers, then flip to `Enforce`.

</details>

---

## 9. Further reading

- Kyverno — [Documentation](https://kyverno.io/docs/) and [Policies library](https://kyverno.io/policies/)
- Kyverno — [Writing policies: validate / mutate / generate](https://kyverno.io/docs/writing-policies/)
- Open Policy Agent — [Gatekeeper](https://open-policy-agent.github.io/gatekeeper/website/docs/)
- Kubernetes — [Dynamic Admission Control](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
- Kubernetes — [Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)
- CNCF — [Policy Reporter](https://kyverno.github.io/policy-reporter/) (visualizing policy reports)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 13.2 — Kubernetes RBAC Deep Dive](../02-kubernetes-rbac-deep-dive/)
· _Next:_ [Module 13.4 — Secret Management →](../04-secret-management/)
