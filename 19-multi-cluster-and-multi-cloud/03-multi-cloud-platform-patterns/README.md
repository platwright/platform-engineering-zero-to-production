# Module 19.3 — Multi-Cloud Platform Patterns

> Multi-cloud is the most over-specified requirement in platform engineering. It arrives
> as a mandate — "we must avoid lock-in" — far more often than as a solved problem, and it
> almost always costs **more** than one cloud: more expertise, more tooling, more
> networking, more egress fees, and a lowest-common-denominator tax on the managed services
> you can use. This module does the unglamorous work of separating the few real drivers
> from the many weak ones, shows how Crossplane and Kubernetes keep the developer interface
> sane *if* you genuinely need it, and argues that for most teams the right goal is
> **exit-readiness**, not actively running everywhere.

**Estimated effort:** ~2–2.5 hours (theory + decision exercise)
**You'll need:** [Module 05.6 · Crossplane](../../05-infrastructure-as-code/06-crossplane/) and [Phase 14 · FinOps](../../18-finops-and-cost-engineering/). No cloud accounts — this is a decision lab.

## Learning objectives

By the end of this module you will be able to:

- Separate **real** multi-cloud drivers (regulatory, acquisition, a unique service,
  provider-failure DR) from **weak** ones (vague lock-in fear, résumé architecture).
- Name the concrete **costs** of multi-cloud: duplicated expertise and tooling, inter-cloud
  networking, egress, and the lowest-common-denominator tax.
- Use **Crossplane XRDs and Compositions** as a portability abstraction, and see where it
  leaks.
- Use **Kubernetes as the portability layer**, and identify what it does *not* make
  portable.
- Make a defensible **portability-ready vs actively-multi-cloud** decision with a framework.

---

## 1. Concept

### Say what you actually mean

"Multi-cloud" is used for several different things; the economics differ wildly:

- **Incidental / polycloud.** Different, *independent* workloads happen to run on different
  clouds (often after an acquisition). Each workload is single-cloud; you just have more
  than one. Manageable.
- **Portability-ready.** You run on **one** cloud today, but deliberately keep switching
  costs low — standardize on Kubernetes, use IaC and open formats, avoid deep proprietary
  coupling — so you *could* move. Cheap insurance.
- **Actively multi-cloud.** A single workload (or platform) runs across **two or more**
  clouds simultaneously, with data and traffic spanning them. This is the expensive, hard
  case people usually imagine — and rarely the one they actually need.

Most "we need multi-cloud" conversations want portability-ready and accidentally ask for
actively-multi-cloud. Naming which one you mean is 80% of the decision.

### The drivers: a short real list and a long weak one

**Drivers that can justify actively multi-cloud:**

- **Regulatory / sovereignty.** A jurisdiction requires a specific provider or a sovereign
  cloud for certain data. A hard external constraint.
- **A genuinely unique service.** One cloud has a capability with no real equivalent (a
  specific ML/data product) that is core to your product.
- **Acquisition / contractual reality.** You bought a company on another cloud, or a large
  customer contractually requires their cloud. The world handed you the constraint.
- **Provider-failure disaster recovery.** You must survive an *entire cloud provider*
  failing — rare, and extremely expensive to do for real (you duplicate everything).

**Weak drivers (sound good, usually aren't):**

- **"Avoid lock-in."** A fear, not a requirement, until you quantify the switching cost you
  are buying down and the premium you are paying for it.
- **"Negotiating leverage."** Enterprise discounts rarely move enough to offset running two
  clouds, and vendors know whether you can actually leave.
- **"Best-of-breed everything."** Stitching the best service from each cloud sounds optimal
  and produces an integration and data-egress nightmare.
- **Résumé-driven architecture.** The most expensive reason, never written down.

If you cannot write the driver in one sentence that names an external constraint, you are
probably buying complexity, not value.

### The costs are real and mostly hidden

Single-cloud teams underestimate every one of these:

- **Duplicated expertise.** Your team must now be genuinely good at *two* clouds' IAM,
  networking, quotas, and failure modes — or hire twice.
- **Duplicated tooling and automation.** Every pipeline, module, and runbook needs a second
  implementation and a second set of tests.
- **Inter-cloud networking.** Connecting VPCs across providers needs a VPN,
  **Cloud Interconnect** (GCP), **Direct Connect** (AWS), or **ExpressRoute** (Azure) —
  real money, real latency, and a new failure domain.
- **Data egress.** Moving data *out* of a cloud is billed per gigabyte, every time.
  Chatty cross-cloud traffic turns into a silent, growing line item. **Data has gravity:**
  it is the hardest and most expensive thing to make multi-cloud.
- **The lowest-common-denominator tax.** To stay portable you can only lean on the
  *intersection* of what the clouds offer — so you give up the best managed databases,
  queues, and serverless that made a single cloud productive, and rebuild them yourself.

This is why the honest default is: **multi-cloud usually costs more than single-cloud.**
The question is never "is it cool?" but "does a named driver justify this premium?"

### The abstraction layer: Crossplane XRDs (one API, many clouds)

If you *do* need it, you do not want developers writing cloud-specific manifests. This is
exactly the Crossplane move from [Module 05.6](../../05-infrastructure-as-code/06-crossplane/):
publish **one** self-service API with a **CompositeResourceDefinition (XRD)**, and back it
with **a Composition per cloud**. The developer asks for a bucket; the platform's
Composition decides whether that is an S3 bucket or a GCS bucket.

```text
developer asks for          platform authored                       real resource
──────────────────          ─────────────────                       ─────────────
ObjectBucket (claim)        XObjectStorage (XRD)  ──Composition-aws──▶  S3 Bucket + policy
  name: reports             one API, two backings  ──Composition-gcp──▶  GCS Bucket + IAM
  versioned: true
```

The power is a stable developer contract across clouds. The catch — and you must say it out
loud — is that **the XRD can only expose what both clouds share.** Every cloud-specific
feature you surface leaks the abstraction, and someone maintains N Compositions forever.
Crossplane makes multi-cloud *tolerable*; it does not make it *cheap*.

### Kubernetes as the portability layer (the practical 80%)

The most pragmatic portability strategy is the one you have been building all course:
**standardize on Kubernetes.** The Kubernetes API is the same on EKS, GKE, and AKS, so the
same Helm charts and manifests deploy anywhere. Your *application layer* becomes genuinely
portable, which buys down most switching cost without running two clouds.

What Kubernetes does **not** make portable is the part that actually locks you in: the
**managed services** around the cluster — the database, the queue, the object store, the
IAM. A Helm chart moves in an afternoon; a 4 TB managed Postgres with ten dependent
services does not. So the realistic posture for most platforms is:

- **Portable by default** at the app layer (Kubernetes + Helm + IaC).
- **Deliberately coupled** to a few best managed services, with the coupling isolated
  behind a narrow interface (a Crossplane XRD, a repository abstraction) so a future move is
  *bounded*, not *catastrophic*.
- **Federated identity** (OIDC / workload identity federation) so one identity model spans
  clouds if you ever go there.

That is **exit-readiness**: not running everywhere, but making sure you *could* leave for a
bounded cost. It is cheap, and it is usually the right answer.

---

## 2. Why it matters for platform engineering

- **It is the headline over-engineering trap.** Speculative multi-cloud abstractions are a
  classic way to pour months of platform effort into complexity no developer asked for —
  the opposite of the Thinnest Viable Platform.
- **It is a cost decision (Phase 14).** Multi-cloud quietly multiplies egress, networking,
  and operational spend. A platform team that cannot articulate that premium should not be
  signing up for it.
- **Exit-readiness is a real, cheap deliverable.** "We standardized on Kubernetes and
  isolated our cloud coupling" is defensible, valuable platform work. "We run on three
  clouds to avoid lock-in" usually is not.
- **If you must, keep the interface sane.** When a genuine driver exists, Crossplane and
  Kubernetes are how you stop multi-cloud complexity from reaching developers.

## 3. Mental model

**Treat multi-cloud as a dial, not a switch — and set it by naming the driver.** Almost
everyone belongs near "portability-ready"; only a named external constraint pushes you to
"actively multi-cloud," and you pay for every notch.

```text
  cheap ◀─────────────────────────────────────────────────────────────▶ expensive

  single cloud        portability-ready            actively multi-cloud
  (deep coupling)     (K8s + IaC + isolated        (one workload across clouds,
   │                   managed-service coupling)     data + traffic spanning them)
   │                        │                               │
   lock-in risk,       most teams live here           needs a NAMED driver:
   fast + cheap        exit-readiness, low cost        regulation, acquisition,
                                                       unique service, provider DR
                              ▲
                     "name the driver in one sentence
                      that references an external constraint,
                      or stay to the left."
```

Rules to keep: **data has gravity** (it anchors you to a cloud more than compute ever will);
**portability lives at the Kubernetes layer, lock-in lives in the managed services**; and
**the cheapest multi-cloud is the one you are *ready* for but do not run.**

## 4. Minimal implementation

There is nothing to provision — the "implementation" is a decision and a thin abstraction.
First, Kubernetes already gives you app-layer portability for free:

```bash
# the same chart deploys to any conformant cluster — EKS, GKE, AKS, or kind
helm install web ./charts/web --kube-context eks-prod
helm install web ./charts/web --kube-context gke-prod
```

Second, when a managed resource genuinely must be portable, hide it behind one XRD and let
a per-cloud Composition implement it (sketches you'll read in the lab):

```bash
# developer interface is identical regardless of which cloud backs it
kubectl apply -f - <<'EOF'
apiVersion: platform.example.org/v1alpha1
kind: ObjectBucket
metadata: { name: reports }
spec: { versioned: true }
EOF
```

The developer never names a cloud. That is the whole deliverable of a portability layer —
and the lab's job is to decide whether building it is worth it for a given scenario.

## 5. Hands-on lab

This is a **decision lab**. You'll read a Crossplane **XRD** and **two Compositions** (AWS
and GCP) that back one `ObjectBucket` API, and pinpoint where the abstraction leaks. Then
you'll complete a **multi-cloud decision worksheet** for a scenario (and, ideally, your own
org): name the driver, estimate the cost premium, and choose a point on the
portability-ready ↔ actively-multi-cloud dial — with a written recommendation.

➡️ **[Start the lab: Decide multi-cloud honestly](./lab/README.md)**

## 6. Production considerations

- **Budget egress and model data gravity first.** Before any multi-cloud design, map where
  data lives and what crosses a cloud boundary. Egress and cross-cloud chatter are the
  costs that surprise teams; data location decides what is even feasible.
- **Pay the lowest-common-denominator tax knowingly.** If portability forbids the best
  managed service, write down what you are giving up and what rebuilding it costs. Often the
  single-cloud managed service plus exit-readiness is cheaper overall.
- **Federate identity and standardize policy.** One identity provider, consistent RBAC and
  policy-as-code across clouds; otherwise security drifts per cloud and audits become
  impossible.
- **Isolate cloud coupling behind narrow interfaces.** A Crossplane XRD or a repository
  interface turns a future migration from "rewrite everything" into "write one new
  Composition/adapter." That is the real value, whether or not you go multi-cloud now.
- **Double the operational plan.** On-call, runbooks, quota management, and upgrades all
  exist per cloud. Make sure the team is staffed and trained for two, not one.
- **Prefer portability-ready.** For most organizations, standardizing on Kubernetes and
  keeping exit costs bounded delivers the real benefit (reduced risk) without the real cost
  (running everywhere).

## 7. Common mistakes

- **Multi-cloud "to avoid lock-in" with no named driver.** — A fear mandates an expensive
  architecture nobody can justify in one sentence. *Fix:* require a written, external driver;
  otherwise choose portability-ready.
- **Abstracting to the lowest common denominator.** — Giving up the best managed services to
  stay portable, then rebuilding them at great cost. *Fix:* use the best single-cloud service
  and isolate the coupling; only abstract what a real driver requires.
- **Ignoring egress and data gravity.** — Designing chatty cross-cloud traffic and a
  split dataset, then getting a shocking bill. *Fix:* model egress and keep data (and its
  compute) co-located per cloud.
- **Building a portability abstraction nobody uses.** — Months spent on a speculative
  multi-cloud XRD layer for a single-cloud reality. *Fix:* TVP — build the abstraction when a
  driver is real, not in anticipation.
- **Assuming Kubernetes equals portable.** — Shipping to "any cloud" while bound to one
  cloud's managed database, queue, and IAM. *Fix:* recognize the lock-in is in the managed
  services; isolate it deliberately.
- **Underestimating the operational doubling.** — Planning compute for two clouds but not
  the people, runbooks, and on-call. *Fix:* budget the human and process cost explicitly.

## 8. Assessment

**Knowledge checks**

1. Distinguish incidental, portability-ready, and actively-multi-cloud. Which do most teams
   actually need?
2. Give two drivers that can justify actively multi-cloud and two weak reasons that usually
   cannot.
3. What is the "lowest-common-denominator tax," and how does it interact with managed
   services?
4. In a Crossplane portability layer, what is portable and where does the abstraction leak?
5. Standardizing on Kubernetes makes the app layer portable — what does it *not* make
   portable, and why does that matter most?

**Concept exercise**

> Explain how a platform can keep the cost of leaving its current cloud **bounded and
> affordable**, without actually running on more than one cloud — **and without using the
> words "multi-cloud," "lock-in," or "Crossplane."** Describe it as reducing switching cost.

**Architecture / trade-off exercise**

> A new CTO announces: "We will be multi-cloud by next year so we're never locked in." You
> run a profitable product entirely on one cloud, heavily using its managed Postgres and
> queue. Write the one-page response: what you would ask, the cost drivers you would surface
> (egress, lowest-common-denominator, operational doubling), and the portability-ready plan
> you would propose instead — plus the conditions under which you *would* agree to go
> actively multi-cloud.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Incidental = separate single-cloud workloads on different clouds; portability-ready
  = one cloud now, low switching cost by design; actively-multi-cloud = one workload spanning
  clouds with data/traffic crossing. Most teams need portability-ready.
- **Q2:** Justifiable: regulatory/sovereignty, acquisition/contractual, a genuinely unique
  service, surviving a whole-provider failure. Weak: vague "avoid lock-in," imagined
  negotiating leverage, best-of-breed stitching, résumé architecture.
- **Q3:** To stay portable you may use only what all target clouds share, forfeiting each
  cloud's best managed services and rebuilding that functionality yourself — often more
  expensive than the single-cloud service plus exit-readiness.
- **Q4:** The developer-facing API (the XRD/claim) is portable; it leaks wherever you expose
  cloud-specific features, and the platform still maintains one Composition per cloud.
- **Q5:** It does not make the surrounding managed services (database, queue, object store,
  IAM) portable — and those, especially data, are where real lock-in and migration cost live;
  a Helm chart moves in an afternoon, a multi-terabyte managed database does not.
- **Trade-off:** Ask for the written driver and the budget owner. Surface egress and
  cross-cloud networking cost, the lowest-common-denominator tax on your Postgres/queue, and
  doubled operations. Propose portability-ready: standardize on Kubernetes, keep IaC and open
  formats, isolate the managed-service coupling behind a narrow interface so a future move is
  bounded. Agree to actively multi-cloud only if a regulatory, contractual, acquisition, or
  provider-DR driver appears — and then scope it to the workload that needs it, not the whole
  platform.

</details>

## 9. Further reading

- Crossplane — [Compositions and CompositeResourceDefinitions](https://docs.crossplane.io/latest/concepts/compositions/)
- Gregor Hohpe — [Don't get locked up into avoiding lock-in](https://martinfowler.com/articles/oss-lockin.html)
- Google Cloud — [Cross-Cloud Interconnect](https://cloud.google.com/network-connectivity/docs/interconnect/concepts/cross-cloud-interconnect)
- AWS — [Data transfer (egress) pricing](https://aws.amazon.com/ec2/pricing/on-demand/#Data_Transfer)
- CNCF — [Cluster API and the case for Kubernetes as a portability layer](https://www.cncf.io/blog/)
- Martin Fowler — [How to think about cloud portability (bliki)](https://martinfowler.com/bliki/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 19.2 — Fleet Management with Cluster API](../02-fleet-management-with-cluster-api/) · _Next:_ [Module 19.4 — Global Load Balancing and Edge →](../04-global-load-balancing-and-edge/)
