# Module 10.3 — Admission Webhooks

> CRDs and operators let you *add* resources and *react* to them. Admission control lets
> you *intercept* every write — mutating or validating it **before** it's stored. This
> is how platforms enforce guardrails that can't be skipped: inject the sidecar, require
> the security context, stamp the cost-center label. You'll learn the webhook machinery
> and the newer, server-free **CEL policies** — and when to use which.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** [Module 10.1 — CRDs](../01-custom-resource-definitions/) and [Module 10.2 — Operators](../02-kubernetes-operators/), a local [kind](https://kind.sigs.k8s.io/) cluster (Kubernetes ≥ 1.30 for `ValidatingAdmissionPolicy`), plus `openssl` for the webhook part.

## Learning objectives

By the end of this module you will be able to:

- Place **mutating** and **validating** admission in the request path, and say why
  order matters.
- Write a **`ValidatingAdmissionPolicy`** (pure CEL, no server) to enforce a rule.
- Explain the **webhook server** contract: TLS, `caBundle`, registration, and
  `failurePolicy`.
- Choose **CEL first, webhook only when needed**, and scope admission safely.

---

## 1. Concept

### Admission happens in the request path — before storage

An operator reacts *after* an object is stored, asynchronously. Admission is the
opposite: it runs **synchronously, inside the API request**, before the object is
written to etcd. Every `kubectl apply` travels this pipeline:

```text
request ─► authentication ─► authorization ─► MUTATING admission ─► schema/CEL
          (who are you?)     (may you?)        (change the object)   validation
                                                                        │
          etcd ◄── VALIDATING admission ◄───────────────────────────────┘
          (stored)   (accept or reject; cannot change)
```

Two properties fall out of this and explain everything else:

- **Mutating runs before validating.** You mutate first (add a label, inject a
  sidecar), *then* the final object is validated. A validator always sees the
  post-mutation object.
- **It's in the hot path.** Because admission blocks the request, a slow or broken
  admission component slows or breaks *every* matching write in the cluster. Admission
  buys you un-skippable guardrails at the cost of being on the critical path.

### The four tools, from lightest to heaviest

| Tool | Can it mutate? | Server? | Status |
|------|----------------|---------|--------|
| `ValidatingAdmissionPolicy` (VAP) | No — validate only | **No** (CEL in-process) | GA (1.30) |
| `MutatingAdmissionPolicy` | Yes (CEL) | **No** (CEL in-process) | Alpha (1.32+) |
| `ValidatingWebhookConfiguration` | No — validate only | Yes (your HTTPS server) | GA |
| `MutatingWebhookConfiguration` | Yes (JSON Patch) | Yes (your HTTPS server) | GA |

The trend is clear: move logic **out of webhook servers and into CEL**, which the API
server evaluates itself — no TLS, no deployment, no availability risk. Today, VAP
covers *validation* with no server; CEL-based *mutation* exists but is still alpha, so
mutation in production generally still means a mutating webhook.

### ValidatingAdmissionPolicy: enforcement with no server

A VAP is two objects: the **policy** (the CEL rules) and a **binding** (which resources
it applies to). No certificates, no pods, no `failurePolicy`-induced outages from a
crashed server.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: require-cost-labels
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "'platform.example.com/cost-center' in object.metadata.labels"
      message: "pods must carry a platform.example.com/cost-center label"
```

`object` is the incoming resource; `oldObject`, `request`, and `namespaceObject` are
also available. This is the **no-server option**: reach for it first.

### The webhook contract: TLS, caBundle, registration

When CEL isn't enough (you need to *mutate*, call an external system, or run logic CEL
can't express), you register a webhook. A webhook is an HTTPS server the API server
**calls** with an `AdmissionReview` and that replies with an `AdmissionResponse`:

- **TLS is mandatory.** The API server will only talk HTTPS, and it must trust your
  server's certificate — so the webhook configuration carries a `caBundle` (the CA that
  signed the server cert). A mismatch is the classic `x509: certificate signed by
  unknown authority` failure.
- **A mutating webhook returns a JSON Patch** (base64-encoded) that the API server
  applies to the object. A validating webhook just returns `allowed: true|false` with a
  message.
- **Registration** (`MutatingWebhookConfiguration` / `ValidatingWebhookConfiguration`)
  declares the `rules` (which resources/operations), the `clientConfig` (a Service or
  URL + `caBundle`), and the knobs below.

```yaml
webhooks:
  - name: inject-cost-labels.platform.example.com
    clientConfig:
      service: { name: label-injector, namespace: platform-system, path: /mutate }
      caBundle: <base64 CA cert>
    rules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE"]
        resources: ["pods"]
    namespaceSelector:                 # ONLY team namespaces — limit the blast radius
      matchLabels: { platform.example.com/managed-by: namespace-provisioner }
    failurePolicy: Ignore              # label injection is best-effort, not security
    sideEffects: None
    admissionReviewVersions: ["v1"]
    timeoutSeconds: 5
```

### The dial that decides reliability: `failurePolicy`

If the API server can't reach your webhook (crashed, slow, cert expired), what should
happen to the request?

- **`Fail`** (fail closed) — reject the request. Safe for *security* gates ("no Pod
  without a signed image"), but a non-HA webhook that goes down now **blocks every
  matching write in the cluster**.
- **`Ignore`** (fail open) — allow the request through un-mutated. Right for
  *best-effort* mutation like label injection, where availability matters more than a
  missing label on one Pod.

Choosing this per webhook, and scoping with `namespaceSelector`/`objectSelector`, is
the difference between a guardrail and an outage.

### Testing and certificates

Hand-rolling TLS and keeping `caBundle` in sync is the painful part. In production,
**cert-manager** issues and rotates the webhook certificate and injects the `caBundle`
automatically via an annotation. For unit/integration tests, **envtest** runs a real
API server so you can assert that your webhook mutates/rejects as intended.

---

## 2. Why it matters for platform engineering

- **Un-skippable guardrails.** Policy enforced at admission can't be forgotten in a
  template or bypassed by a hand-written manifest — it applies to *every* write.
- **Invisible paved roads.** A mutating webhook injects the right defaults (sidecar,
  security context, labels) so developers get correct behavior *without doing anything*.
  That's the platform doing the work, not the human.
- **FinOps starts here.** Cost tools attribute spend by label. If every Pod is stamped
  with `team` and `cost-center` automatically, Phase 18's cost reports are accurate by
  construction — no nagging developers to label things.
- **Security and compliance.** Pod Security admission, image-signature checks, and
  "no `:latest`" rules are all admission control. It's where "secure by default"
  becomes literally true.

---

## 3. Mental model

Admission is a **checkpoint on the way into etcd**: first a station that can *change*
your object, then stations that can *reject* it. Nothing is stored until it passes.

```text
   kubectl apply pod.yaml
          │
          ▼
   authn ─► authz ─► ┌───────── MUTATING ─────────┐ ─► schema + CEL ─► ┌──── VALIDATING ────┐ ─► etcd
                     │ mutating webhooks           │     validation     │ VAP (CEL, no server)│
                     │ (JSON Patch: add labels,    │                    │ validating webhooks │
                     │  inject sidecar, defaults)  │                    │ (allow / deny)      │
                     └─────────────────────────────┘                    └─────────────────────┘
                        change it                                          judge the final object
```

Three things to remember: **mutate before validate**, **it blocks the request**, and
**CEL (in-process) beats a webhook (a server you must keep alive) whenever it can
express the rule.**

---

## 4. Minimal implementation

The smallest useful admission control needs **no server at all**. Require that Pods
carry a cost-center label, with a `ValidatingAdmissionPolicy` and its binding:

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata: { name: require-cost-center }
spec:
  matchConstraints:
    resourceRules:
      - apiGroups: [""]
        apiVersions: ["v1"]
        operations: ["CREATE", "UPDATE"]
        resources: ["pods"]
  validations:
    - expression: "'platform.example.com/cost-center' in object.metadata.labels"
      message: "every Pod needs a platform.example.com/cost-center label"
---
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicyBinding
metadata: { name: require-cost-center-binding }
spec:
  policyName: require-cost-center
  validationActions: ["Deny"]
  matchResources:
    namespaceSelector:
      matchLabels: { platform.example.com/managed-by: namespace-provisioner }
```

Apply it, then try to create a bare Pod in a managed namespace: it's rejected with your
message. No TLS, no deployment, no `failurePolicy` outage surface. That's the baseline;
a webhook is what you add only when you must *change* the object (inject the label) or
reach outside the cluster.

---

## 5. Hands-on lab

Two halves. First, the **no-server** path: a `ValidatingAdmissionPolicy` that *requires*
`team` and `cost-center` labels on Pods in managed namespaces, and rejects those that
lack them. Then the **webhook** path: a small mutating webhook that *injects* those
labels from the namespace's annotations — so developers never set them and the VAP
passes automatically. The webhook runs on a stock image via a ConfigMap; a script mints
the TLS cert.

➡️ **[Start the lab: Enforce and inject cost labels](./lab/README.md)**

---

## 6. Production considerations

- **Default to VAP.** It runs in-process: no TLS, no pods, no availability risk, lower
  latency. Use a webhook only for mutation or external calls.
- **Pick `failurePolicy` deliberately, per webhook.** `Fail` for security gates (and
  then make the webhook HA); `Ignore` for best-effort mutation. A `Fail` webhook that
  isn't highly available is a cluster-wide outage waiting to happen.
- **Scope tightly.** Use `namespaceSelector`/`objectSelector` and precise `rules` so you
  match only what you must. **Exclude `kube-system`** and your own control-plane
  namespace to avoid bootstrap deadlocks.
- **Keep it fast and set a low timeout.** Admission is in the hot path; a slow webhook
  taxes every matching write. Set `timeoutSeconds` low and keep the handler cheap.
- **Automate certs with cert-manager.** Manual `caBundle` management breaks on rotation;
  cert-manager issues, rotates, and injects it for you.
- **Declare `sideEffects: None`** (or `NoneOnDryRun`) so dry-run works, and make
  mutations **idempotent** — reinvocation (`reinvocationPolicy`) can call you twice.

---

## 7. Common mistakes

- **`failurePolicy: Fail` on a non-HA webhook.** — The webhook crashes and now *nothing*
  matching it can be created cluster-wide. *Fix:* run the webhook HA, scope it tightly,
  or use `Ignore` for non-security mutation.
- **Matching `kube-system` or the webhook's own namespace.** — You create a bootstrap
  deadlock where the webhook can't start because its own Pods are blocked. *Fix:* exclude
  system namespaces with a `namespaceSelector`.
- **No `namespaceSelector`.** — The webhook fires on every namespace, including CI and
  system workloads you never meant to touch. *Fix:* select only managed namespaces.
- **`caBundle` mismatch.** — `x509: certificate signed by unknown authority`; the API
  server won't trust the server cert. *Fix:* put the signing CA in `caBundle` (let
  cert-manager inject it) and rotate together.
- **Reaching for a webhook when VAP would do.** — A whole TLS server to enforce "label
  must exist." *Fix:* write a `ValidatingAdmissionPolicy`; keep webhooks for mutation.
- **Non-idempotent mutation.** — Appending a sidecar twice because reinvocation called
  you again. *Fix:* check before you add; make the patch a no-op if already applied.

---

## 8. Assessment

**Knowledge checks**

1. In the admission pipeline, does mutating or validating run first, and why does the
   order matter?
2. What can a `ValidatingAdmissionPolicy` do that a validating webhook also does — and
   what can it *not* do that a mutating webhook can?
3. Explain the `Fail` vs `Ignore` `failurePolicy` trade-off with one example of each.
4. Why is a slow admission webhook a cluster-wide problem, not a local one?
5. What is `caBundle` for, and what error do you get when it's wrong?

**Concept exercise**

> Explain how you'd guarantee every Pod in a team's namespace carries a cost-center
> label *without asking developers to add it and without running a server* — then
> explain the one capability that would force you to run a server after all. Do it
> **without using the words "webhook" or "ValidatingAdmissionPolicy."**

**Debugging / trade-off exercise**

> Right after a teammate deploys a new admission webhook, **all** Pod creation in the
> cluster starts failing — including in `kube-system`. List the three most likely causes
> and how you'd confirm and fix each, in the order you'd check them.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Mutating runs first; validating sees the final, post-mutation object, so a
  validator can enforce rules about fields a mutator just added.
- **Q2:** VAP can validate (accept/reject) with CEL and no server; it *cannot* mutate.
  A mutating webhook can change the object (inject labels, sidecars, defaults).
- **Q3:** `Fail` rejects when the webhook is unreachable — correct for a security gate
  like "block unsigned images," but risky without HA. `Ignore` lets the request through
  — correct for best-effort label injection.
- **Q4:** Admission is synchronous and in the request path; a slow webhook adds latency
  to (or times out) every matching write across the whole cluster.
- **Q5:** `caBundle` is the CA cert the API server uses to trust the webhook's TLS
  certificate; if it's wrong you get `x509: certificate signed by unknown authority`.
- **Debugging:** (1) `failurePolicy: Fail` combined with the webhook being down or slow;
  (2) the configuration matches too broadly (no `namespaceSelector`) and hits
  `kube-system`, deadlocking the webhook's own pods; (3) a bad `caBundle`/TLS error.
  Confirm with `kubectl get mutatingwebhookconfiguration -o yaml`, the API server logs,
  and the webhook pod logs; fix by scoping/excluding namespaces, switching to `Ignore`
  while you debug, or correcting the cert.

</details>

---

## 9. Further reading

- Kubernetes — [Dynamic Admission Control (webhooks)](https://kubernetes.io/docs/reference/access-authn-authz/extensible-admission-controllers/)
- Kubernetes — [Validating Admission Policy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/)
- Kubernetes — [Admission Controllers Reference](https://kubernetes.io/docs/reference/access-authn-authz/admission-controllers/)
- Kubernetes — [CEL for admission](https://kubernetes.io/docs/reference/using-api/cel/)
- cert-manager — [Securing webhooks / CA injection](https://cert-manager.io/docs/)
- Kubernetes — [Pod Security Admission](https://kubernetes.io/docs/concepts/security/pod-security-admission/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 10.2 — Kubernetes Operators](../02-kubernetes-operators/)
· _Next:_ [Module 10.4 — API Extension Patterns →](../04-api-extension-patterns/)
