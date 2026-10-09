# Module 05.6 — Crossplane

> Terraform provisions infrastructure *from the outside* — a CLI run from CI, state
> in a bucket, reconciliation only when you run `apply`. **Crossplane** flips this:
> it turns your Kubernetes cluster into a **control plane** that provisions and
> *continuously reconciles* cloud infrastructure using the same API machinery as Pods
> and Services. This module teaches managed resources, composite resources (XRs),
> XRDs, and compositions — and how they enable true `kubectl apply` self-service.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Phase 3 · Kubernetes](../../03-kubernetes-fundamentals/), [`kind`](https://kind.sigs.k8s.io/), `kubectl`, and Helm. The lab runs on a local `kind` cluster with a no-cloud provider — **free**.

## Learning objectives

By the end of this module you will be able to:

- Explain how Crossplane makes Kubernetes a **control plane** for infrastructure.
- Distinguish **managed resources**, **providers**, **composite resources (XR)**,
  **XRDs**, and **compositions**.
- Publish a **self-service API** that developers consume with `kubectl apply`.
- Decide when Crossplane fits and when Terraform is the better tool.

---

## 1. Concept

### The problem: provisioning lives outside the cluster

With Terraform, the desired state is HCL, the record is a state file, and
reconciliation happens only when a pipeline runs `apply`. Between runs, nothing
watches for drift. And "let a developer provision a database" means giving them a
pipeline, a module, and cloud permissions — or a ticket.

Kubernetes already solved "continuously reconcile desired state" for *workloads*: you
declare a Deployment, and a controller works forever to make reality match, healing
drift automatically. **Crossplane extends that exact pattern to cloud
infrastructure.** You declare "an S3 bucket" or "a Cloud SQL instance" as a
Kubernetes object, and a controller continuously reconciles the real cloud resource —
no out-of-band `apply`, no separate state file (the cluster's etcd *is* the state).

### Managed resources and providers

A **provider** is a Crossplane package that teaches the control plane to manage a
cloud's resources (AWS, GCP, Azure, Kubernetes itself, SQL, …). Installing one
registers a set of **managed resources (MRs)** — fine-grained CRDs that map
one-to-one to a real cloud resource.

```yaml
# A managed resource: one CRD == one real cloud resource, reconciled continuously.
apiVersion: storage.gcp.upbound.io/v1beta1
kind: Bucket
metadata:
  name: platform-logs
spec:
  forProvider:
    location: EU
  providerConfigRef:
    name: default
```

Apply that and Crossplane creates the bucket and keeps it reconciled forever. Delete
the object and it deletes the bucket. It's Terraform's reconcile loop, running
always, inside Kubernetes.

### The abstraction problem: MRs are too low-level for developers

You don't want app developers wiring up a bucket *and* an IAM policy *and* a database
*and* a firewall rule correctly every time — that's the cognitive load Phase 1 warned
about. You want to offer them a single, high-level, safe thing: *"give me a
PostgreSQL instance."* Crossplane's composition machinery is how a platform team
builds that abstraction.

### XRDs, composite resources, and claims

- A **CompositeResourceDefinition (XRD)** defines a *new API* — your own CRD — e.g.
  `XPostgreSQLInstance`, with a schema (`storageGB`, `version`). This is the shape of
  the self-service API you offer.
- A **Composite Resource (XR)** is an instance of that API. It's cluster-scoped and
  usually created on a developer's behalf.
- A **Claim** is the *namespaced* developer-facing handle to an XR (kind
  `PostgreSQLInstance`). Developers create claims in their namespace; Crossplane
  creates the matching XR. (Claims are optional in newer Crossplane, but they're the
  classic self-service entry point.)

### Compositions: how an XR becomes real resources

A **Composition** tells Crossplane *how to implement* an XR — which managed resources
to create and how to fill them in from the XR's parameters. One high-level request
fans out into many correctly-wired managed resources.

```text
developer applies            platform team authored
───────────────────          ──────────────────────
PostgreSQLInstance  ──XRD──▶  XPostgreSQLInstance ──Composition──▶  CloudSQLInstance
(claim, namespaced)          (XR, cluster-scoped)                   + Database
  storageGB: 20                                                     + User
  version: "15"                                                     + firewall rule
```

The developer sees one simple object; the platform team's Composition encodes all the
expertise. Modern Crossplane runs Compositions as a **pipeline of composition
functions** (e.g. `function-patch-and-transform`), which patch values from the XR
onto the composed resources.

### Self-service via `kubectl apply` + RBAC

Because everything is a Kubernetes API, **self-service falls out for free**: give a
team RBAC to create `PostgreSQLInstance` claims in their namespace, and they
provision databases with `kubectl apply` — no cloud credentials, no tickets, no
Terraform access. The guardrails live in the Composition; the developer can only ask
for what the XRD allows.

---

## 2. Why it matters for platform engineering

- **It's a self-service engine.** Crossplane is one of the cleanest ways to offer
  "databases/environments/namespaces on demand" as a Kubernetes-native API — the
  literal realization of the Phase 1 paved road.
- **Continuous reconciliation, not periodic applies.** Drift is corrected
  automatically by controllers, the same way Kubernetes heals a crashed Pod — a
  stronger guarantee than "we run `terraform plan` nightly."
- **One control plane, one RBAC model.** Infrastructure and workloads share
  Kubernetes' auth, policy, and GitOps tooling (Phase 6). Your ArgoCD already knows
  how to deploy a `PostgreSQLInstance`.
- **Abstraction is first-class.** XRDs + Compositions are a native way to encode
  platform opinions and expose a minimal interface — modules, but as live APIs.

## 3. Mental model

**Crossplane is a Kubernetes controller for the cloud; your XRD is a new "kind," your
Composition is its controller logic.**

```text
  ┌──────────────────────── your Kubernetes cluster (the control plane) ─────────┐
  │                                                                              │
  │  developer:  kubectl apply PostgreSQLInstance (claim)                        │
  │                     │                                                        │
  │                     ▼                                                        │
  │     XRD defines the API ──▶ XR created ──▶ Composition (functions) selects   │
  │                                            and patches managed resources     │
  │                                                 │                            │
  │                                                 ▼                            │
  │     Provider controllers reconcile ──────▶ real cloud resources  ◀─ drift ──┐│
  │     (continuously, forever)                 (DB, bucket, user)    auto-heal  ││
  └──────────────────────────────────────────────────────────────────────────────┘
```

Rules to keep:

- **MRs are the atoms; XRs are the molecules.** Developers touch molecules; the
  platform team composes them from atoms.
- **The cluster is the state.** etcd + controllers replace the state file + periodic
  apply.
- **The XRD is the contract.** Developers can only request what it allows — guardrails
  by schema.

## 4. Minimal implementation

The smallest end-to-end Crossplane abstraction, using a **no-cloud provider** so it
costs nothing, is four objects: a provider, a function, an XRD, and a Composition —
then a developer applies a claim.

```yaml
# 1) a provider that creates fake "managed resources" (no cloud, no credentials)
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-nop
spec:
  package: xpkg.upbound.io/crossplane-contrib/provider-nop:v0.4.0
```

```yaml
# 2) the function that patches composed resources
apiVersion: pkg.crossplane.io/v1
kind: Function
metadata:
  name: function-patch-and-transform
spec:
  package: xpkg.upbound.io/crossplane-contrib/function-patch-and-transform:v0.8.2
```

With the XRD and Composition applied (see the lab), a developer does exactly this —
and nothing else:

```yaml
apiVersion: platform.example.com/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: my-app-db
spec:
  parameters:
    storageGB: 20
    version: "15"
  compositionSelector:
    matchLabels:
      environment: production
```

```bash
kubectl apply -f my-app-db.yaml
kubectl get postgresqlinstance,xpostgresqlinstance    # claim → XR
kubectl get managed                                   # the composed resource(s)
```

The developer requested a database in nine lines; the platform team's Composition
turned it into correctly-wired managed resources. Swap `provider-nop` for
`provider-gcp` and the same claim provisions a real Cloud SQL instance — the
developer's YAML doesn't change.

## 5. Hands-on lab

You'll install Crossplane on a local `kind` cluster, install a **no-cloud provider**,
define an **XRD** and a **Composition**, and then play the developer: `kubectl apply`
a `PostgreSQLInstance` claim and watch Crossplane compose and reconcile the backing
(fake) managed resources. Everything is free and local; cloud credentials are
**optional** and clearly marked.

➡️ **[Start the lab: Self-service databases with Crossplane](./lab/README.md)**

## 6. Production considerations

- **Protect the control plane.** It now holds credentials that can create cloud
  infrastructure. Treat the Crossplane cluster as tier-0: locked-down RBAC, audited,
  isolated from workloads.
- **Version providers, functions, and XRDs.** They're packages and APIs; pin
  versions and roll out upgrades deliberately, exactly like Terraform modules.
- **Design XRD schemas like product APIs.** Minimal inputs, safe defaults, validated
  fields. A sloppy XRD is a sloppy platform API every team must live with.
- **Plan for day-two.** Updates, field immutability, deletion policies
  (`Delete` vs `Orphan`), and what happens to real resources when a claim is deleted
  are critical — a stray `kubectl delete` must not nuke a production database by
  accident.
- **Observe it.** Composed-resource readiness, reconciliation errors, and provider
  health need dashboards and alerts like any controller (Phase 8).
- **GitOps the claims.** Don't let humans `kubectl apply` prod infrastructure by hand;
  drive claims through Git + ArgoCD/Flux (Phase 6) for review and audit.

## 7. Common mistakes

- **Exposing managed resources directly to developers.** Making teams wire up
  buckets, IAM, and databases themselves re-creates the cognitive load. *Fix:* offer
  XRs/claims; compose the atoms for them.
- **Treating Crossplane as "Terraform in YAML."** It's a *continuous control plane*,
  not a one-shot apply. *Fix:* design for always-on reconciliation and controller
  semantics, not pipeline runs.
- **Ignoring deletion/immutability policies.** Defaults can delete real
  infrastructure when a claim is removed, or fail updates on immutable fields. *Fix:*
  set deletion policies deliberately; document which fields are immutable.
- **Giving the control plane cloud-admin and forgetting it.** It becomes the softest
  path to your whole cloud. *Fix:* least-privilege provider credentials, isolation,
  auditing.
- **One mega-Composition with dozens of toggles.** Same anti-pattern as the
  mega-module. *Fix:* small, composable XRs; multiple Compositions selected by label.

## 8. Assessment

**Knowledge checks**

1. How does Crossplane's reconciliation model differ from `terraform apply`?
2. What's the difference between a managed resource, an XR, and a claim?
3. What does an XRD define, and what does a Composition define?
4. How does `kubectl apply` self-service work without handing developers cloud
   credentials?
5. Name one scenario where Crossplane is a better fit than Terraform, and one where
   it isn't.

**Concept exercise**

> Explain how a developer can "ask for a database and get one safely" **without using
> the words "Crossplane," "Composition," or "Kubernetes."** Describe the
> request/fulfilment model and the guardrails.

**Architecture / trade-off exercise**

> Your org already runs all infrastructure in Terraform. A team wants fully
> self-service, auto-reconciling dev databases via `kubectl`. Make the case for
> introducing Crossplane *for that use case* while keeping Terraform for the
> foundational estate (networks, clusters, IAM). What boundary would you draw between
> the two tools, and why is "use both" often the right answer?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Terraform reconciles only when a pipeline runs `apply`, with state in a
  file. Crossplane runs controllers that reconcile *continuously*, auto-healing drift,
  with the cluster's etcd as the record of state.
- **Q2:** A managed resource maps 1:1 to a real cloud resource (low-level). An XR is a
  high-level, cluster-scoped composite your platform defines (via an XRD) that fans
  out into managed resources. A claim is the namespaced, developer-facing handle to an
  XR.
- **Q3:** An XRD defines a new API/CRD (its name, schema, claim) — the *interface*. A
  Composition defines how an XR of that type is *implemented* — which managed
  resources to create and how to patch them from the XR's parameters.
- **Q4:** Everything is a Kubernetes API, so you grant RBAC to create *claims* in a
  namespace. The cloud credentials live only in the control plane's providers;
  developers never see them and can only request what the XRD schema allows.
- **Q5:** Crossplane shines for self-service, continuously-reconciled, abstracted
  resources (dev databases, namespaces, ephemeral environments) in Kubernetes-centric
  orgs. Terraform is often better for foundational, one-time-ish, cross-cutting estate
  (account/org setup, networks, the clusters themselves — including the one Crossplane
  runs on) and for teams without a Kubernetes control plane.
- **Trade-off:** Draw the boundary at "foundational vs self-service / app-adjacent."
  Terraform bootstraps the cluster, networks, and IAM (including Crossplane's own
  install and credentials); Crossplane offers the day-to-day, developer-requested
  resources on top. Using both plays to each tool's strengths: Terraform's maturity
  for the base, Crossplane's continuous self-service for the paved road.

</details>

## 9. Further reading

- Crossplane — [Documentation](https://docs.crossplane.io/) and
  [Concepts](https://docs.crossplane.io/latest/concepts/)
- Crossplane — [Composition functions](https://docs.crossplane.io/latest/concepts/compositions/)
  and [CompositeResourceDefinitions](https://docs.crossplane.io/latest/concepts/composite-resource-definitions/)
- Crossplane — [`function-patch-and-transform`](https://github.com/crossplane-contrib/function-patch-and-transform)
- Crossplane Contrib — [`provider-nop`](https://github.com/crossplane-contrib/provider-nop)
  (no-cloud provider for testing)
- Upbound — [Upbound Marketplace (providers & functions)](https://marketplace.upbound.io/)
- CNCF — [Crossplane (graduated project)](https://www.cncf.io/projects/crossplane/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 05.5 — Terraform Testing and Quality](../05-terraform-testing-and-quality/) · _Next:_ [Module 05.7 — IaC Patterns for Platform Teams →](../07-iac-patterns-for-platform-teams/)
