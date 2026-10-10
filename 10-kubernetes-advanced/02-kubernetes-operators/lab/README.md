# Lab — Build the NamespaceProvisioner operator

> You'll run a complete `NamespaceProvisioner` operator against a local kind cluster.
> Apply an `Environment` and watch it provision a namespace, `ResourceQuota`,
> `LimitRange`, and RBAC, report status conditions, **self-heal** when you delete a
> child, and **clean up via a finalizer** on delete. This is the manual onboarding
> runbook from Project 1 turned into software.

**Estimated time:** ~60–90 minutes
**Type:** Build
**Deliverable:** A running operator that reconciles `Environment` resources into real
namespaces with guardrails, plus notes proving self-healing and finalizer cleanup.

## Objectives

- Run a controller-runtime operator locally against kind.
- Observe the reconciliation loop create and **re-heal** child resources.
- Read status conditions written by the controller.
- See a finalizer perform cleanup before the custom resource is deleted.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- **A [Go](https://go.dev/dl/) toolchain (1.22+).** Running the operator compiles Go
  code; the first `make run` downloads modules (needs network). Without Go you can
  still read the controller and apply the CRD from Module 10.1, but the reconcile
  behavior below requires running the controller.
- The operator project, provided here:
  [`namespace-provisioner/`](./namespace-provisioner/). Key files to read:
  [`internal/controller/environment_controller.go`](./namespace-provisioner/internal/controller/environment_controller.go)
  (the `Reconcile` logic),
  [`api/v1alpha1/environment_types.go`](./namespace-provisioner/api/v1alpha1/environment_types.go),
  and [`main.go`](./namespace-provisioner/main.go).
- Concepts from the [module README](../README.md).

> **What requires Go, and what doesn't.** The CRD (`make install`) is plain YAML and
> needs only `kubectl`. The *controller* (`make run`) is a Go program — that's the
> part that needs the toolchain. It runs **out-of-cluster** against your current
> kubeconfig, so it uses your admin credentials and needs no in-cluster RBAC for this
> lab. In production it ships as a container with the least-privilege Role generated
> from the `+kubebuilder:rbac` markers in the controller.

## Steps

1. **Create the cluster and install the CRD.**

   ```bash
   kind create cluster --name pe-operator --config kind-config.yaml
   cd namespace-provisioner
   make install           # kubectl apply -f config/crd/...
   kubectl get crd environments.platform.example.com
   ```

2. **Run the operator (leave it running).** In this terminal the controller runs in
   the foreground and streams logs:

   ```bash
   make run               # go run .  — first run downloads modules
   ```

   Wait for `starting manager` and `Starting workers`. Open a **second terminal** for
   the remaining steps (keep this one running).

3. **Apply an Environment and watch it get provisioned.** In the second terminal:

   ```bash
   kubectl apply -f config/samples/environment-sample.yaml
   kubectl get environments
   kubectl get namespace payments-dev
   kubectl get resourcequota,limitrange,rolebinding -n payments-dev
   ```

   A namespace `payments-dev` now exists with a `ResourceQuota`, a `LimitRange`, and a
   `team-edit` RoleBinding — none of which you created by hand. The operator did the
   whole runbook.

4. **Read the status the controller wrote.**

   ```bash
   kubectl get env payments-dev -o jsonpath='{.status.phase}{"\n"}'
   kubectl get env payments-dev -o jsonpath='{range .status.conditions[*]}{.type}={.status} ({.reason}){"\n"}{end}'
   ```

   You should see `Ready` and a `Ready=True (Provisioned)` condition. Notice the
   controller wrote `status` without you touching `spec`.

5. **Prove it self-heals (level-triggered reconciliation).** Delete a child and watch
   the operator put it back, because it `Owns` the quota:

   ```bash
   kubectl delete resourcequota platform-quota -n payments-dev
   # watch the operator log a reconcile, then:
   kubectl get resourcequota -n payments-dev
   ```

   The quota reappears within a second. You changed *actual* state; the loop restored
   it from *desired* state. Try the same with the RoleBinding.

6. **Prove the finalizer cleans up.** Inspect the finalizer, then delete the
   `Environment`:

   ```bash
   kubectl get env payments-dev -o jsonpath='{.metadata.finalizers}{"\n"}'
   kubectl delete environment payments-dev
   kubectl get namespace payments-dev        # Terminating, then gone
   kubectl get environments                  # empty
   ```

   Deletion paused while the finalizer ran: the controller deleted the namespace
   (cascading to the quota, limits, and RBAC inside it), then removed the finalizer so
   the `Environment` could disappear.

7. **(Optional) See validation from Module 10.1 still apply.** The operator doesn't
   replace the API's validation — try an invalid Environment and watch the API server
   reject it before the controller ever sees it:

   ```bash
   kubectl apply -f - <<'EOF'
   apiVersion: platform.example.com/v1alpha1
   kind: Environment
   metadata: { name: bad }
   spec: { team: payments, tier: prod }
   EOF
   # rejected: prod environments must set spec.owner (and need >= 2 replicas)
   ```

## Expected result

- Applying `payments-dev` creates a namespace with a `ResourceQuota`, `LimitRange`, and
  RoleBinding, and the `Environment` reports `phase: Ready` with `Ready=True`.
- Deleting the `ResourceQuota` triggers an automatic reconcile that recreates it.
- Deleting the `Environment` removes the namespace via the finalizer, and the resource
  disappears only after cleanup completes.
- The operator logs one reconcile per change and does **not** loop continuously on an
  unchanged object.

## Cleanup

> Stop the operator and delete the cluster. Never skip this.

```bash
# In the operator terminal: press Ctrl+C to stop `make run`.
kind delete cluster --name pe-operator
```

## Reflection

- You deleted the `ResourceQuota` and it came back. Explain, in terms of desired vs
  actual state, why the operator didn't need to "see the delete event" to fix it.
- The `Environment` paused in `Terminating` until cleanup finished. What would happen
  if the controller were stopped at that moment, and how would you recover?
- Compare this to the Project 1 onboarding runbook. Which manual steps did the operator
  replace, and what new guarantees do you get that a human runbook can't provide?

## Stretch goals (optional)

- Make the quota depend on `spec.replicas` (scale the pod/CPU budget with it) and
  re-apply an `Environment` with a different `replicas` value to see the quota change.
- Add an `Owns(&corev1.Namespace{})`-free experiment: set an owner reference on the
  namespace instead of using the finalizer, and compare the deletion behavior.
- Emit a Kubernetes `Event` ("Provisioned namespace payments-dev") from `Reconcile`
  using an `EventRecorder`, and find it with `kubectl get events -n payments-dev`.
- Break the controller on purpose (return an error from one `ensure*` step) and watch
  the `Ready=False (…Error)` condition and the exponential-backoff requeues.
