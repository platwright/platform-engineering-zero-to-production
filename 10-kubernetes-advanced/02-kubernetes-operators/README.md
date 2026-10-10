# Module 10.2 — Kubernetes Operators

> In Project 1 you onboarded a team **by hand**: create a namespace, label it, apply a
> `ResourceQuota` and `LimitRange`, wire up RBAC. An **operator** is that runbook
> encoded as software — a controller running the reconciliation loop from Module 03.1,
> but for *your own* `Environment` resource. You did it by hand; now you'll make the
> platform do it, consistently, forever, and self-heal when someone breaks it.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** [Module 10.1 — CRDs](../01-custom-resource-definitions/), the reconciliation loop from [Module 03.1](../../03-kubernetes-fundamentals/01-kubernetes-architecture/), a local [kind](https://kind.sigs.k8s.io/) cluster, and (for the full lab) a [Go](https://go.dev/dl/) toolchain.

## Learning objectives

By the end of this module you will be able to:

- Explain the **operator pattern** — a custom controller that encodes operational
  knowledge for a CRD — and build one with **controller-runtime**.
- Write an idempotent, **level-triggered** `Reconcile` that drives actual state toward
  a resource's `spec`.
- Report progress with **status conditions** and choose sane **requeue** strategies.
- Use **owner references** for garbage collection and **finalizers** for pre-delete
  cleanup.

---

## 1. Concept

### An operator is the reconciliation loop, for your resource

Module 03.1 taught you that built-in controllers watch built-in types and drive actual
state toward desired state. The Deployment controller keeps N Pods running; the Node
controller reacts to nodes dying. Module 10.1 gave you a new *type* — `Environment` —
but warned you nothing reconciles it.

An **operator** fills that gap. It is nothing more exotic than:

```text
operator = one or more CRDs (the nouns)  +  a custom controller (the verb)
```

The controller runs the same loop you already know, aimed at your type:

```text
watch Environment ──► observe desired (spec) ──► observe actual (the real namespace,
      ▲                                           quota, limits, RBAC in the cluster)
      │                                                       │
      └───────────── write status ◄── create/update/delete to close the gap ◄──┘
```

The name comes from SRE: an *operator* encodes what a skilled human operator knows
about running a piece of software — the runbook — as a program. "To give a team an
environment, create a namespace, apply a quota and limits, bind RBAC, and watch for
drift" is exactly such a runbook. An operator makes it executable and tireless.

### controller-runtime: the library everyone builds on

You could talk to the API server by hand, but almost nobody does. **controller-runtime**
(the library beneath both **kubebuilder** and **operator-sdk**) gives you:

- a **Manager** that wires up shared caches, clients, leader election, and metrics;
- **informers/caches** so your controller reads from a local watch-backed cache
  instead of hammering the API server;
- a **work queue** with rate limiting and retries;
- a **Reconciler** interface — you implement one method.

```go
func (r *EnvironmentReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    env := &platformv1alpha1.Environment{}
    if err := r.Get(ctx, req.NamespacedName, env); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err) // already deleted — nothing to do
    }
    // ... ensure namespace, quota, limits, RBAC; then update status ...
    return ctrl.Result{}, nil
}
```

### Level-triggered, not edge-triggered — so it must be idempotent

This is the mistake that bites every beginner. Your `Reconcile` is **not** called with
"a Pod was deleted" or "the spec changed." It's called with *"something about this
object might have changed — go make reality match its spec."* It may be called once, or
fifty times, for the same object. Therefore:

- **Never assume you saw a specific event.** Always read the current state and compute
  the difference.
- **Make every action idempotent.** "Create the namespace" must mean "ensure the
  namespace exists with these labels," not "POST a new namespace" (which fails the
  second time). The helper `controllerutil.CreateOrUpdate` exists for exactly this.

Level-triggered design is *why* Kubernetes self-heals: delete the quota your operator
created and the next reconcile puts it back, because the loop re-derives desired state
from `spec` every time.

### Requeue strategies

`Reconcile` returns `(ctrl.Result, error)`, which tells the queue when to call you again:

- `return ctrl.Result{}, err` — on error, requeue with **exponential backoff**.
- `return ctrl.Result{}, nil` — success; don't requeue *proactively* (you still get
  called when the object or a watched child changes).
- `return ctrl.Result{RequeueAfter: 5 * time.Minute}, nil` — re-check periodically
  (useful when you poll something the cluster can't watch).

Prefer **watches over polling**: `Owns(&corev1.ResourceQuota{})` makes the framework
reconcile the parent `Environment` whenever one of its quotas changes — including when
someone deletes it.

### Status conditions: how your operator talks back

Users and other controllers need to know *how it's going*. The convention is an array of
**conditions**, each with a `type` (e.g. `Ready`), `status` (`True`/`False`/`Unknown`),
`reason`, `message`, `lastTransitionTime`, and `observedGeneration`. Use
`meta.SetStatusCondition`, which only updates `lastTransitionTime` when the state
actually changes — important for avoiding hot loops. Write status through the status
subresource (Module 10.1) so it doesn't bump `generation`.

### Owner references and finalizers

Two mechanisms manage the lifecycle of what your operator creates:

- **Owner references** — stamp "this ResourceQuota is owned by `payments-dev`" on each
  child. Kubernetes **garbage-collects** children when the parent is deleted, and the
  framework uses the reference to map child events back to the parent (`Owns`).
- **Finalizers** — a string in `metadata.finalizers` that **blocks deletion** until your
  operator removes it. That pause is your chance to run cleanup that GC can't do:
  deleting an external cloud resource, deregistering from DNS, or (here) deleting the
  namespace the `Environment` owns. The pattern: when `deletionTimestamp` is set, run
  cleanup, then remove the finalizer so deletion can complete.

### Scaffolding: kubebuilder and operator-sdk

You rarely write all this from scratch. `kubebuilder init` / `operator-sdk init` scaffold
the Manager, a sample API, and a controller; `controller-gen` generates deepcopy code,
the CRD YAML, and RBAC from `// +kubebuilder:...` markers in your Go types. You'll use a
pre-scaffolded project in the lab and focus on the part that matters: `Reconcile`.

---

## 2. Why it matters for platform engineering

- **It turns a runbook into a product.** The manual onboarding doc from Project 1 becomes
  software that never forgets a step and applies the same guardrails every time.
- **It self-heals.** Drift — a deleted quota, a tampered RoleBinding — is corrected on the
  next reconcile. Your platform defends its own invariants.
- **It's self-service at scale.** A team commits an `Environment` and the platform
  provisions everything. No ticket, no human in the critical path, no inconsistency
  between the 3rd and the 300th environment.
- **It's the universal extension pattern.** cert-manager, Argo CD, Crossplane,
  Prometheus Operator, and database operators are all this exact shape. Learn it once and
  you can read — and build — the ecosystem.

---

## 3. Mental model

Picture your operator as a thermostat wired to the cluster. It never trusts its memory;
every tick it *measures* the room (reads actual state), compares to the *dial* (the
`spec`), and acts to close the gap.

```text
            ┌──────────────── Environment (your CRD) ────────────────┐
            │  spec: {team: payments, tier: dev}   status: {...}      │
            └───────────────────────┬────────────────────────────────┘
                                    │ watch (For)
                      ┌─────────────▼─────────────┐
                      │   EnvironmentReconciler    │   level-triggered:
                      │   observe spec vs actual   │   reads real state every time,
                      │   CreateOrUpdate children  │   idempotent, safe to repeat
                      └─────────────┬─────────────┘
         ensure (and re-heal) ┌─────┼───────┬───────────┬───────────┐
                              ▼     ▼       ▼           ▼           ▼
                        Namespace  Quota  LimitRange  RoleBinding  status
                                    ▲       ▲           ▲
                                    └───────┴───────────┘ watch (Owns):
                                      delete one and the loop restores it
```

Three rules: **read actual state every time**, **make every change idempotent**, and
**report what you did in `status`.**

---

## 4. Minimal implementation

The smallest honest operator: fetch the resource, ensure one namespace exists, and
report ready. Everything else (quota, limits, RBAC, finalizers) is "more of the same."

```go
func (r *EnvironmentReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    env := &platformv1alpha1.Environment{}
    if err := r.Get(ctx, req.NamespacedName, env); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }

    ns := &corev1.Namespace{ObjectMeta: metav1.ObjectMeta{Name: env.Spec.Team + "-" + env.Spec.Tier}}
    _, err := controllerutil.CreateOrUpdate(ctx, r.Client, ns, func() error {
        ns.Labels = map[string]string{"platform.example.com/team": env.Spec.Team}
        return nil // idempotent: ensure, don't blindly create
    })
    if err != nil {
        return ctrl.Result{}, err // requeue with backoff
    }

    meta.SetStatusCondition(&env.Status.Conditions, metav1.Condition{
        Type: "Ready", Status: metav1.ConditionTrue, Reason: "Provisioned",
        Message: "namespace ready", ObservedGeneration: env.Generation,
    })
    env.Status.Phase = "Ready"
    env.Status.Namespace = ns.Name
    return ctrl.Result{}, r.Status().Update(ctx, env)
}
```

Run it against kind and `kubectl apply` an `Environment`: a namespace appears, and
`kubectl get env` shows `Ready`. Delete the namespace and watch the loop recreate it.
That's the whole idea; the lab fills in the production details.

---

## 5. Hands-on lab

You'll run a complete `NamespaceProvisioner` operator (the `EnvironmentReconciler`)
against kind. Apply an `Environment` and watch it provision a namespace, `ResourceQuota`,
`LimitRange`, and RBAC, set status conditions, self-heal when you delete a child, and
clean up via a finalizer on delete. The full Go project is provided; the README is honest
about what needs the Go toolchain.

➡️ **[Start the lab: Build the NamespaceProvisioner operator](./lab/README.md)**

---

## 6. Production considerations

- **Idempotency is the whole game.** Use `CreateOrUpdate` or Server-Side Apply (Module
  10.4); never write code that only works the first time.
- **Don't hot-loop on status.** Writing `status` every reconcile even when nothing
  changed re-triggers the watch and spins the CPU. Only update when the computed status
  differs; `meta.SetStatusCondition` helps.
- **Finalizers must be robust.** Cleanup has to be idempotent and must not deadlock; a
  bug that never removes the finalizer leaves objects stuck `Terminating`. Always keep an
  operational escape hatch (how to force-remove a finalizer).
- **Least-privilege RBAC.** The operator runs as a ServiceAccount; generate its Role from
  `+kubebuilder:rbac` markers and grant only what it touches — not `cluster-admin`.
- **Leader election for HA.** Run two replicas with leader election so one is always
  active without two controllers fighting over the same objects.
- **Observability.** controller-runtime exposes reconcile count/latency/error metrics;
  emit Events for human-visible milestones; surface conditions for dashboards.
- **Test with envtest.** Run the controller against a real API server + etcd (no kubelet)
  in CI, so reconcile logic is tested without a full cluster.

---

## 7. Common mistakes

- **Edge-triggered thinking.** — Writing `Reconcile` as if it receives "the thing that
  changed." It doesn't. *Fix:* always read current state and reconcile to `spec`; assume
  you may have missed events.
- **Non-idempotent actions.** — Blindly `Create`-ing children, which errors on the second
  reconcile. *Fix:* `CreateOrUpdate`/SSA so "ensure" is safe to repeat.
- **Status hot loop.** — Unconditionally updating status each pass, which re-queues
  forever and pins a core. *Fix:* compute desired status, compare, and only write on a
  real change.
- **Stuck finalizers.** — Adding a finalizer but a cleanup bug never removes it, so the
  object hangs in `Terminating`. *Fix:* make cleanup idempotent and tolerant of
  already-deleted children; remove the finalizer whenever cleanup is done.
- **Swallowing errors.** — Logging an error and returning `nil`, so the queue thinks it
  succeeded and never retries. *Fix:* return the error to get backoff-and-retry.
- **God-mode RBAC.** — Granting the operator `cluster-admin` "to be safe." *Fix:* scope
  permissions to exactly the resources and verbs it uses.

---

## 8. Assessment

**Knowledge checks**

1. In one sentence, what is an operator, and how does it relate to a CRD?
2. What does "level-triggered" mean for `Reconcile`, and why does it force idempotency?
3. Name the three things a `Reconcile` return value can tell the work queue to do.
4. What problem do **owner references** solve, and what problem do **finalizers** solve —
   and why can't one replace the other?
5. Why should status updates go through the status subresource rather than a normal update?

**Concept exercise**

> Explain how you'd automate team onboarding so that deleting the team's quota by mistake
> is silently repaired — **without using the words "operator," "controller," or
> "reconcile."** Describe it as a control system.

**Debugging / trade-off exercise**

> An `Environment` has been stuck in `Terminating` for an hour; its namespace is already
> gone. What is almost certainly happening, how do you confirm it, and what's the safe
> fix? Separately: your operator's CPU is pinned at 100% and the logs show thousands of
> reconciles per second for one unchanged object — what's the likely cause?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** An operator is a custom controller (plus its CRD) that encodes operational
  knowledge, running the reconciliation loop for a user-defined type.
- **Q2:** `Reconcile` is called to "make reality match spec," not for a specific event; it
  may run many times for one object, so every action must be safe to repeat (idempotent).
- **Q3:** Requeue with backoff (return an error), stop proactive requeue (return
  `Result{}, nil`), or requeue after a delay (`RequeueAfter`).
- **Q4:** Owner references give automatic garbage collection of children when the parent is
  deleted; finalizers pause deletion so the operator can run cleanup GC can't do (external
  resources, ordered teardown). GC can't call your code; finalizers can't auto-delete
  owned objects — you need both.
- **Q5:** The status subresource separates status writes from spec and doesn't bump
  `generation`, so the operator can distinguish user spec changes from its own status
  writes and avoid permission/loop problems.
- **Debugging:** Stuck `Terminating` means a finalizer is never removed — confirm with
  `kubectl get environment X -o jsonpath='{.metadata.finalizers}'`; fix by repairing the
  operator (or, as an escape hatch, patching the finalizer off). The 100% CPU is a status
  hot loop: status is written unconditionally every reconcile, re-triggering the watch.

</details>

---

## 9. Further reading

- Kubernetes — [Operator pattern](https://kubernetes.io/docs/concepts/extend-kubernetes/operator/)
- Kubernetes — [Controllers and the control loop](https://kubernetes.io/docs/concepts/architecture/controller/)
- Kubernetes — [Finalizers](https://kubernetes.io/docs/concepts/overview/working-with-objects/finalizers/) and [Owners and dependents](https://kubernetes.io/docs/concepts/overview/working-with-objects/owners-dependents/)
- The Kubebuilder Book — [Architecture and tutorial](https://book.kubebuilder.io/)
- controller-runtime — [Package reference](https://pkg.go.dev/sigs.k8s.io/controller-runtime)
- Operator SDK — [Go operator tutorial](https://sdk.operatorframework.io/docs/building-operators/golang/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 10.1 — Custom Resource Definitions](../01-custom-resource-definitions/)
· _Next:_ [Module 10.3 — Admission Webhooks →](../03-admission-webhooks/)
