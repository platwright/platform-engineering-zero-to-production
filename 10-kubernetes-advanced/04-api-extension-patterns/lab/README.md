# Lab — Make your CRD a first-class API

> You'll upgrade the `Environment` CRD from Module 10.1 into a production-shaped API: add
> the `/scale` subresource and `kubectl scale` it, add field selectors and query by tier,
> add printer columns, apply everything with **Server-Side Apply**, provoke and resolve a
> field **conflict** between two managers, and add a new **CEL** rule. No controller
> needed — these are all API-server features you switch on.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** An `Environment` CRD you can `kubectl scale`, filter with
`--field-selector`, and apply server-side, plus notes on how SSA resolved a conflict.

## Objectives

- Enable and use the `/scale` subresource on a custom resource.
- Query custom resources with server-side field selectors and printer columns.
- Apply resources with Server-Side Apply and resolve a field-ownership conflict.
- Add a CEL validation rule and confirm it rejects bad input.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- **Kubernetes ≥ 1.31** for CRD field selectors (the
  [`kind-config.yaml`](./kind-config.yaml) pins a 1.31 node).
- Starter files: [`environment-crd-v2.yaml`](./environment-crd-v2.yaml),
  [`environment-sample.yaml`](./environment-sample.yaml),
  [`ssa-conflict.yaml`](./ssa-conflict.yaml), and
  [`environments-more.yaml`](./environments-more.yaml).

## Steps

1. **Create the cluster and apply the upgraded CRD (server-side).**

   ```bash
   kind create cluster --name pe-apiext --config kind-config.yaml
   kubectl apply --server-side -f environment-crd-v2.yaml
   kubectl get crd environments.platform.example.com
   ```

2. **Apply a resource with Server-Side Apply, then inspect ownership.**

   ```bash
   kubectl apply --server-side --field-manager=team-a -f environment-sample.yaml
   kubectl get environment payments-dev --show-managed-fields -o yaml \
     | sed -n '/managedFields/,/spec:/p'
   ```

   Each field is tagged with the manager `team-a`. That record is what makes the next
   step detect a clash instead of silently overwriting.

3. **Provoke and resolve a conflict.** `ssa-conflict.yaml` sets a *different*
   `costCenter` as a *different* manager:

   ```bash
   kubectl apply --server-side --field-manager=team-b -f ssa-conflict.yaml
   # Error: Apply failed with 1 conflict: conflict with "team-a": .spec.costCenter
   kubectl apply --server-side --field-manager=team-b --force-conflicts -f ssa-conflict.yaml
   kubectl get environment payments-dev -o jsonpath='{.spec.costCenter}{"\n"}'   # cc-9999
   ```

   The conflict was SSA protecting `team-a`'s field. Forcing it transfers ownership of
   `spec.costCenter` to `team-b` — deliberately, not by accident.

4. **Scale a custom resource with the `/scale` subresource.**

   ```bash
   kubectl scale environment/payments-dev --replicas=5
   kubectl get environment payments-dev -o jsonpath='{.spec.replicas}{"\n"}'     # 5
   kubectl get --raw /apis/platform.example.com/v1alpha1/environments/payments-dev/scale
   ```

   `kubectl scale` worked on a type you defined, because the CRD implements the standard
   scale contract. The same endpoint is what a HorizontalPodAutoscaler would target.

5. **Filter with server-side field selectors.** Add more environments, then query by your
   own fields:

   ```bash
   kubectl apply --server-side --field-manager=team-a -f environments-more.yaml
   kubectl get environments --field-selector spec.tier=prod
   kubectl get environments --field-selector spec.team=shop
   ```

   Only matching objects come back — the API server filtered them, not the client.

6. **See the printer columns.**

   ```bash
   kubectl get environments
   ```

   Expect `TEAM`, `TIER`, `REPLICAS`, `OWNER`, `PHASE`, and `AGE` columns — your schema's
   fields surfaced in `kubectl get`.

7. **Exercise the new CEL rule (and the immutability rule).**

   ```bash
   # dev replica cap: the new rule rejects more than 3 replicas for a dev tier.
   kubectl apply --server-side --field-manager=team-a -f - <<'EOF'
   apiVersion: platform.example.com/v1alpha1
   kind: Environment
   metadata: { name: shop-dev-toobig }
   spec: { team: shop, tier: dev, replicas: 5, costCenter: cc-2003 }
   EOF
   # Error ... dev environments may run at most 3 replicas

   # immutability: changing tier on an existing Environment is rejected.
   kubectl apply --server-side --field-manager=team-a -f - <<'EOF'
   apiVersion: platform.example.com/v1alpha1
   kind: Environment
   metadata: { name: shop-dev }
   spec: { team: shop, tier: staging, replicas: 2, costCenter: cc-2001 }
   EOF
   # Error ... spec.tier is immutable once set
   ```

## Expected result

- `kubectl scale environment/payments-dev --replicas=5` succeeds and `spec.replicas` is 5.
- `--field-selector spec.tier=prod` returns only `shop-prod`.
- `kubectl get environments` shows the custom printer columns.
- The second SSA apply conflicts until `--force-conflicts`, after which `team-b` owns
  `spec.costCenter` (value `cc-9999`).
- The dev-replica-cap and tier-immutability CEL rules reject the bad applies.

## Cleanup

> Delete the cluster. Never skip this.

```bash
kind delete cluster --name pe-apiext
```

## Reflection

- You scaled a resource you invented. What did implementing the standard `/scale`
  contract give you "for free," and why is conforming to a standard better than a custom
  `replicas` field plus a custom tool?
- The conflict in step 3 was an error, not a silent overwrite. Why is that the *safer*
  default when an operator and a human both edit the same object?
- Field selectors returned filtered results from the server. How would this behave
  differently in a cluster with 10,000 Environments if you filtered client-side instead?

## Stretch goals (optional)

- Point a HorizontalPodAutoscaler at `environment/payments-dev` (it will target the
  `/scale` subresource). You don't need it to actually scale anything — inspect
  `kubectl describe hpa` to see it reading the scale endpoint.
- Add a third `selectableField` (e.g. `.spec.owner`), re-apply the CRD, and filter on it.
- Re-run the whole lab against the **Module 10.2 operator**: start the operator, and
  watch it use its own field manager so an SSA apply from you conflicts on the fields it
  owns — the real multi-writer scenario.
- Add a CEL transition rule that only allows `replicas` to *increase*, never decrease, and
  test it.
