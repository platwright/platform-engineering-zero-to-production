# Module 10.1 — Custom Resource Definitions

> Kubernetes ships with Pods, Deployments, and Services — but your platform thinks in
> `Environment`s, `Database`s, and `TenantApp`s. A **Custom Resource Definition**
> teaches the API server a new noun, so your own concepts become first-class API
> objects that `kubectl`, RBAC, GitOps, and admission all understand. This is the
> foundation every operator and most of the CNCF ecosystem is built on.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 03.1 — Kubernetes Architecture](../../03-kubernetes-fundamentals/01-kubernetes-architecture/) (the reconciliation loop, `spec`/`status`) and a local [kind](https://kind.sigs.k8s.io/) cluster.

## Learning objectives

By the end of this module you will be able to:

- Explain what a CRD adds to a cluster — and, crucially, what it does **not** add.
- Read a CRD in terms of **group, version, kind, scope, and schema**.
- Validate custom resources with an **OpenAPI v3 structural schema** and **CEL**
  (`x-kubernetes-validations`) rules, and say when CEL replaces a webhook.
- Reason about **CRD versioning** (`v1alpha1 → v1beta1 → v1`), served vs stored
  versions, and conversion.
- Explain why the **status subresource** splits spec writes from status writes.

---

## 1. Concept

### The problem: your platform's nouns don't exist yet

Your platform has concepts. "Give team-payments a **dev environment**." "Provision a
**database** for this service." But the Kubernetes API has never heard of an
`Environment` or a `Database`. So where does that state live?

- **In a ConfigMap?** It's an unvalidated blob of YAML-in-a-string. No typing, no
  required fields, no `kubectl get environments`, and every tool has to re-parse it.
- **In an external database?** Now you have two sources of truth, no `kubectl`, no
  RBAC, no `watch`, no audit log — you've left the platform.

Both lose the things that make Kubernetes good: a typed, validated, watchable,
access-controlled API.

### What a CRD actually does

A **CustomResourceDefinition** registers a new resource *type* with the API server.
Apply one, and the API server immediately:

- serves a new REST endpoint, e.g. `/apis/platform.example.com/v1alpha1/environments`;
- stores instances (**custom resources**, or CRs) in etcd, the same way it stores Pods;
- gives you `kubectl get/describe/apply/delete`, labels and selectors, RBAC, admission,
  the audit log, and `watch` — **for free**, because everything flows through the one
  hub you met in Module 03.1.

```bash
kubectl apply -f environment-crd.yaml       # register the "Environment" type
kubectl get crds | grep environments        # the API now knows the noun
kubectl explain environment.spec            # schema-driven docs, like any built-in
```

### The point you must not miss: a CRD is data, not behavior

Here is the idea that sets up the entire phase. A CRD adds **storage and validation**
— a new noun — and **nothing else**. There is no controller. When you create an
`Environment`, its `spec` sits in etcd and *nothing happens*: no namespace is created,
no `status` is driven toward anything. The reconciliation loop from Module 03.1 is
**not** running for your type, because you haven't written one yet.

```text
Built-in Deployment                    Your Environment CRD (alone)
───────────────────                    ────────────────────────────
spec  ─┐                               spec  ─┐
       ├─► Deployment controller            ├─► (nobody is watching)
status ┘   drives status→spec          status ┘   status stays empty forever
```

- **CRD** = the data model (the noun, its schema). *This module.*
- **Operator** = the behavior (the control loop for that noun). *Module 10.2.*

Keeping these separate is deliberate: it means you can validate and store your API
before you've written a line of controller code, and different controllers can watch
the same type.

### CRD anatomy: group, version, kind, scope, schema

```yaml
spec:
  group: platform.example.com     # your API group — use a domain you own
  names:
    kind: Environment             # CamelCase type name used in YAML
    plural: environments          # the REST path segment
    singular: environment
    shortNames: [env]             # kubectl get env
  scope: Namespaced               # or Cluster (no namespace)
  versions:
    - name: v1alpha1
      served: true                # exposed on the API
      storage: true               # persisted to etcd in THIS version (exactly one)
      schema:
        openAPIV3Schema: { ... }  # the structural schema (below)
```

### Validation 1 — the OpenAPI v3 structural schema

For a v1 CRD the schema is **required** and must be *structural*: every field is
typed, and the API server **prunes** (drops) anything you didn't declare. That is what
makes a CR trustworthy — you can't smuggle untyped data into it. Structural schemas
give you per-field validation familiar from JSON Schema: `type`, `enum`, `pattern`,
`minimum`/`maximum`, `minLength`, `required`, and `default`.

```yaml
spec:
  type: object
  required: [team, tier]
  properties:
    team:
      type: string
      pattern: '^[a-z][a-z0-9-]{1,30}$'
    tier:
      type: string
      enum: [dev, staging, prod]
    replicas:
      type: integer
      minimum: 1
      default: 1
```

### Validation 2 — CEL rules that span fields

OpenAPI validates one field at a time. Real rules relate fields ("prod environments
need an owner") or forbid changes ("tier is immutable"). Historically you reached for
a **validating webhook** — a TLS server you build, deploy, and keep alive — for this.
Since Kubernetes 1.25+, **CEL** (Common Expression Language) rules embedded in the
schema via `x-kubernetes-validations` handle most of these with **no server at all**:

```yaml
x-kubernetes-validations:
  - rule: "self.tier != 'prod' || has(self.owner)"
    message: "prod environments must set spec.owner"
  - rule: "self.tier == oldSelf.tier"       # a transition rule (compares to old value)
    message: "tier is immutable once set"
```

`self` is the object being validated; `oldSelf` is the previous version (available on
updates — a *transition rule*). CEL runs inside the API server, synchronously, with no
certificates to rotate. **Reach for CEL first; reach for a webhook only when CEL
genuinely can't express the rule** (Module 10.3).

### Versioning: served vs stored

APIs evolve. You start at `v1alpha1` (anything may change), graduate to `v1beta1`,
then `v1` (stable). A CRD can serve several versions at once:

- **`served: true`** — clients can read/write this version.
- **`storage: true`** — exactly **one** version is the one written to etcd. Other
  served versions are converted to/from it on the fly.

For simple, additive changes, the built-in `None` conversion strategy suffices. For
renames or restructures you register a **conversion webhook** that translates between
versions. The golden rule: **never make a breaking change to an already-served
version** — add a new version instead.

### The status subresource

Enabling `subresources.status: {}` splits the object into two independently writable
halves: clients write `spec`, controllers write `status` via a separate endpoint. This
matters because it lets RBAC grant "update status" without "update spec", and because
status writes don't bump `metadata.generation` — so a controller can tell *user edits*
from its *own* status updates. You'll switch this on and exploit it fully in Module
10.4; know it exists now.

---

## 2. Why it matters for platform engineering

- **Your platform gets a declarative API.** Instead of a ticket ("please make me a
  dev environment"), a team commits an `Environment` manifest and GitOps applies it.
  The platform's capabilities become `kubectl`-and-Git-native.
- **Everything else comes for free.** RBAC, admission, audit, labels/selectors,
  `watch`, and every dashboard that speaks to the API now work on *your* types,
  because they're real API objects — not a side database.
- **Validation moves left.** A malformed request is rejected at the API boundary with
  a clear message, long before it becomes a 2am incident.
- **It's the industry pattern.** cert-manager `Certificate`s, Argo CD `Application`s,
  Crossplane `Composition`s, Prometheus `ServiceMonitor`s — all CRDs. Learn the
  pattern once and the whole ecosystem reads the same way.

---

## 3. Mental model

A CRD is **teaching the API server a new word**. Once it knows the word, instances of
that word travel the same hub-and-spoke path as every built-in object — validated on
the way in, stored in etcd, and available to anything that watches.

```text
   kubectl apply environment.yaml
             │
             ▼
   ┌──────────────────────── API SERVER ────────────────────────┐
   │  1. Is "Environment" a known type?  ── yes (CRD registered) │
   │  2. OpenAPI structural schema       ── types / enums / regex │
   │  3. CEL x-kubernetes-validations    ── cross-field + oldSelf  │
   │  4. (admission plugins, Module 10.3)                         │
   └───────────────────────────┬────────────────────────────────┘
                               │ store
                               ▼
                             etcd            ...and then?  NOTHING —
                                             no controller watches it yet.
                                             (That is Module 10.2.)
```

Remember the split: **CRD defines the noun; a controller gives it a verb.**

---

## 4. Minimal implementation

Let's prove both halves of the claim: a CRD gives you a real, validated API *and* does
nothing on its own. The smallest useful CRD:

```yaml
# environment-crd.yaml (abridged — full version in the lab)
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: environments.platform.example.com
spec:
  group: platform.example.com
  names: { kind: Environment, plural: environments, singular: environment, shortNames: [env] }
  scope: Cluster
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [team, tier]
              properties:
                team: { type: string }
                tier: { type: string, enum: [dev, staging, prod] }
```

Register it and create an instance:

```bash
kubectl apply -f environment-crd.yaml
kubectl apply -f - <<'EOF'
apiVersion: platform.example.com/v1alpha1
kind: Environment
metadata: { name: payments-dev }
spec: { team: payments, tier: dev }
EOF

kubectl get environments            # payments-dev is there — a real API object
kubectl get namespace payments-dev  # NotFound — nothing was created
```

The CR exists and is queryable, but **no namespace appeared**, because nothing is
reconciling it. Now watch validation do its job:

```bash
kubectl apply -f - <<'EOF'
apiVersion: platform.example.com/v1alpha1
kind: Environment
metadata: { name: bad }
spec: { team: payments, tier: production }   # not in the enum
EOF
# Error: spec.tier: Unsupported value: "production": supported values: "dev","staging","prod"
```

You built a typed, self-validating API endpoint with a single YAML file — and saw
exactly where behavior will have to be added next.

---

## 5. Hands-on lab

You'll author a complete, production-shaped `Environment` CRD — structural schema,
enums, regex, defaults, a CEL cross-field rule, a CEL transition (immutability) rule,
printer columns, and the status subresource — then apply it to kind and prove it
accepts valid resources and rejects invalid ones with clear messages.

➡️ **[Start the lab: Design and validate an Environment CRD](./lab/README.md)**

---

## 6. Production considerations

- **Own your API group.** `platform.example.com` is fine for docs, but in production
  use a domain you actually control to avoid collisions with other installed CRDs.
- **Structural schemas are non-negotiable.** Avoid blanket
  `x-kubernetes-preserve-unknown-fields: true`; it disables pruning and validation and
  becomes a dumping ground. Type every field.
- **Treat a served version as a contract.** Never make breaking changes to it. Add
  `v1beta1`/`v1`, keep old versions served, and migrate storage with a conversion
  strategy. Alpha versions are your only license to break things.
- **Enable the status subresource from day one.** Retrofitting it later means
  reworking RBAC and controllers.
- **CRDs are cluster-scoped and destructive.** Installing or deleting one is a
  privileged, cluster-wide act, and **deleting a CRD cascades to every CR of that
  type**. Gate CRD management behind tight RBAC and GitOps review.
- **Mind etcd.** CRs live in etcd like everything else; don't model high-volume,
  high-churn data (metrics, events) as custom resources.
- **Budget CEL cost.** The API server enforces a per-rule and per-request CEL cost
  limit; keep rules simple, and prefer them over webhooks for latency and reliability.

---

## 7. Common mistakes

- **Storing platform state in ConfigMaps or annotations.** — It "works" but gives up
  typing, validation, and discoverability, and every consumer re-invents parsing.
  *Fix:* model the concept as a CRD and let the API server validate it.
- **Blanket `preserve-unknown-fields`.** — Copied from an old example, it disables
  pruning so typos and junk silently persist. *Fix:* write a full structural schema;
  only preserve unknown fields on a specific sub-tree you deliberately keep open.
- **Breaking a served version.** — Renaming or retyping a field in `v1alpha1` that
  users already depend on breaks their manifests on upgrade. *Fix:* add a new version
  and convert; treat each served version as frozen.
- **Forgetting the status subresource.** — Controllers then fight `generation` bumps
  and you can't separate "user changed spec" from "controller wrote status." *Fix:*
  set `subresources: { status: {} }` from the start.
- **Reaching for a webhook when CEL would do.** — A TLS server to enforce "prod needs
  an owner" is a lot of moving parts to keep alive. *Fix:* express it as an
  `x-kubernetes-validations` rule; keep webhooks for logic CEL can't do.
- **Using someone else's API group.** — Reusing `example.com` or a vendor's group
  risks clashing with an installed CRD of the same name. *Fix:* use a group under a
  domain you own.

---

## 8. Assessment

**Knowledge checks**

1. After you `kubectl apply` a CRD and create one custom resource, what exactly has
   happened in the cluster — and what has **not**?
2. In a CRD's `versions` list, what's the difference between `served` and `storage`,
   and how many versions can set `storage: true`?
3. Give one validation rule that OpenAPI v3 *can't* express but CEL can, and write it.
4. What two concrete benefits does enabling the status subresource give you?
5. What happens to existing custom resources when you delete their CRD?

**Concept exercise**

> Explain how you would add a brand-new "Environment" concept to a cluster so that
> `kubectl`, RBAC, the audit log, and GitOps all work on it — **without using the
> words "CRD" or "CustomResourceDefinition."** Describe the capability, not the tool.

**Debugging / trade-off exercise**

> A teammate applies an `Environment` CR and complains: "I created it but no namespace
> showed up — the CRD is broken." Explain why this is expected behavior, what's
> actually missing, and which module fixes it. Then: when would you choose a
> *conversion webhook* over a CEL rule?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** The API server now serves a new type and has stored one instance in etcd;
  it's queryable with `kubectl` and governed by RBAC/admission. What has *not* happened
  is any action — no controller is reconciling it, so `status` stays empty and nothing
  is created in the world.
- **Q2:** `served` means clients may read/write that version; `storage` means etcd
  persists in that version. Exactly **one** version may be `storage: true`; others are
  converted to/from it.
- **Q3:** Any cross-field or transition rule, e.g.
  `self.tier != 'prod' || has(self.owner)` (cross-field), or
  `self.tier == oldSelf.tier` (immutability). OpenAPI validates fields in isolation
  and has no `oldSelf`.
- **Q4:** (a) RBAC can grant "update status" separately from "update spec"; (b) status
  writes don't bump `metadata.generation`, so a controller can distinguish user spec
  edits from its own status updates.
- **Q5:** Deleting the CRD **cascades**: all custom resources of that type are deleted
  too. It's a destructive, cluster-wide operation.
- **Trade-off:** The "broken" CRD isn't broken — there's simply no controller; Module
  10.2 adds the operator that reconciles it. Choose a conversion webhook when versions
  differ structurally enough that a mechanical/`None` conversion can't map them (field
  renames, restructures); use CEL for in-version validation, not cross-version shape
  changes.

</details>

---

## 9. Further reading

- Kubernetes — [Custom Resources and CRDs (concepts)](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- Kubernetes — [Extend the API with CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
- Kubernetes — [Specifying a structural schema](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#specifying-a-structural-schema)
- Kubernetes — [Validation rules (CEL in CRDs)](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/#validation-rules)
- Kubernetes — [Versions in CustomResourceDefinitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definition-versioning/)
- Kubernetes — [CEL language overview](https://kubernetes.io/docs/reference/using-api/cel/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 8 · Kubernetes Advanced](../README.md)
· _Next:_ [Module 10.2 — Kubernetes Operators →](../02-kubernetes-operators/)
