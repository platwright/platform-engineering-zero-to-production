# Lab — Enforce a security baseline with Kyverno

> You'll install Kyverno on a local cluster and apply four real ClusterPolicies — no
> root, resource limits required, no `:latest` in production, and required ownership
> labels. You'll run them in **Audit** first to read the policy reports, then flip to
> **Enforce** and watch a bad pod get rejected while a hardened pod sails through.

**Estimated time:** ~50–70 minutes
**Type:** Build
**Deliverable:** Four enforced ClusterPolicies plus evidence (a policy report and a
rejected-vs-admitted pod) proving the baseline holds.

## Objectives

- Install Kyverno and apply validate-type ClusterPolicies.
- Read `PolicyReport`s to measure violations without blocking anything.
- Promote a policy from `Audit` to `Enforce` and observe the difference.
- Prove the baseline by applying a non-compliant and a compliant workload.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/) (to install Kyverno).
- Starter policies here: [`disallow-root.yaml`](./disallow-root.yaml),
  [`require-limits.yaml`](./require-limits.yaml),
  [`disallow-latest-in-prod.yaml`](./disallow-latest-in-prod.yaml),
  [`require-labels.yaml`](./require-labels.yaml); test workloads
  [`bad-pod.yaml`](./bad-pod.yaml) and [`good-pod.yaml`](./good-pod.yaml).

## Steps

1. **Create a cluster and install Kyverno.**

   ```bash
   kind create cluster --name pe-kyverno
   helm repo add kyverno https://kyverno.github.io/kyverno/
   helm repo update
   helm install kyverno kyverno/kyverno -n kyverno --create-namespace
   kubectl -n kyverno rollout status deploy/kyverno-admission-controller
   ```

   Kyverno is now registered as an admission webhook — it will see every pod created
   from here on.

2. **Apply all four policies (they ship in `Audit` mode).** Nothing will break yet;
   violations are only *recorded*:

   ```bash
   kubectl apply -f disallow-root.yaml -f require-limits.yaml \
     -f disallow-latest-in-prod.yaml -f require-labels.yaml
   kubectl get clusterpolicy
   ```

   Confirm each shows `ACTION: Audit` and `READY: True`.

3. **Create the non-compliant workload and watch it get *admitted but reported*.** In
   Audit mode the bad pod still runs — that's the point:

   ```bash
   kubectl apply -f bad-pod.yaml          # runs as root, no limits, :latest, no labels
   kubectl get pod bad-pod                 # it exists — Audit does not block
   ```

4. **Read the policy report — visibility without blocking.** This is the data you use
   to plan a safe rollout:

   ```bash
   kubectl get policyreport -A
   kubectl describe policyreport -n default | grep -A3 -i fail | head -n 40
   ```

   You should see `fail` results for `bad-pod` against `disallow-root`,
   `require-limits`, and `require-labels`. (`disallow-latest-in-prod` only matches
   `env=production` namespaces, so it does not flag a pod in `default` — you test it
   separately in step 8.) That report is how you'd size the gap on a real cluster
   *before* enforcing.

5. **Promote the policies to `Enforce`.** Flip the one field that turns a report into a
   guardrail:

   ```bash
   for p in disallow-root require-limits disallow-latest-in-prod require-labels; do
     kubectl patch clusterpolicy "$p" --type=merge \
       -p '{"spec":{"validationFailureAction":"Enforce"}}'
   done
   kubectl get clusterpolicy      # ACTION now shows Enforce
   ```

6. **Prove enforcement: the bad pod is now rejected.** Delete and re-apply it — this
   time admission refuses it with your policy messages:

   ```bash
   kubectl delete pod bad-pod --ignore-not-found
   kubectl apply -f bad-pod.yaml          # ← REJECTED at admission
   ```

   Read the error: it names each rule the pod violated. That is the guardrail doing
   the review no human had to.

7. **Prove the paved road still works: the hardened pod is admitted.** A compliant
   workload passes cleanly:

   ```bash
   kubectl apply -f good-pod.yaml         # non-root, limits, pinned tag, labels
   kubectl get pod good-pod               # Running
   ```

8. **(Optional) Test the production-only rule.** `disallow-latest-in-prod` only applies
   to namespaces labelled `env=production`. Create one and confirm a `:latest` image is
   blocked there but allowed in `default`:

   ```bash
   kubectl create namespace prod
   kubectl label namespace prod env=production
   kubectl run latest-prod --image=nginx:latest -n prod --restart=Never   # ← REJECTED
   kubectl run latest-dev  --image=nginx:latest --restart=Never            # admitted (not prod)
   ```

## Expected result

With the policies in `Enforce`:

- `bad-pod` is **rejected** at admission, with messages naming the root, limits, and
  label violations.
- `good-pod` is **admitted** and runs.
- A `:latest` image is blocked in the `env=production` namespace but allowed elsewhere.
- `kubectl get policyreport -A` shows pass/fail results you can hand to an auditor.

You've turned a wiki checklist into an enforced, self-documenting baseline.

## Cleanup

> Always tear down local clusters so they stop holding memory.

```bash
kubectl delete -f bad-pod.yaml -f good-pod.yaml --ignore-not-found
kubectl delete -f disallow-root.yaml -f require-limits.yaml \
  -f disallow-latest-in-prod.yaml -f require-labels.yaml --ignore-not-found
kind delete cluster --name pe-kyverno
```

## Reflection

- You changed one field (`Audit` → `Enforce`) to go from "observe" to "block." Why is
  that two-phase rollout the difference between a safe change and an outage?
- `good-pod.yaml` had to declare non-root, limits, a pinned tag, and labels. How much
  of that could a **mutate** policy have added for the team automatically, and which
  parts should stay as hard `validate` rejections?
- A team hits a genuine edge case that one policy forbids. What's the right escape
  hatch, and how do you keep it from becoming a hole?

## Stretch goals (optional)

- Add a **mutate** policy that injects `seccompProfile: RuntimeDefault` and
  `allowPrivilegeEscalation: false`, then relax `good-pod.yaml` and watch Kyverno add
  them for you.
- Add a **generate** policy that creates a default-deny `NetworkPolicy` whenever a new
  namespace is created.
- Write a `PolicyException` for a single named workload and confirm it is now exempt
  from one policy while everything else stays enforced.
- Run `kyverno test` (Kyverno CLI) against the starter policies with pass/fail fixture
  manifests — the beginning of policy CI.
