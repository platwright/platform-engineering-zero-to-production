# Lab — Design and validate an Environment CRD

> You'll author a complete, production-shaped `Environment` CustomResourceDefinition —
> structural schema, enums, regex, defaults, CEL cross-field and immutability rules,
> printer columns, and the status subresource — apply it to a local kind cluster, and
> prove it accepts valid resources and rejects invalid ones with clear messages. You'll
> also see first-hand that a CRD stores data but runs no behavior.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A registered `environments.platform.example.com` CRD on kind that
validates custom resources, plus notes on which rule caught each invalid resource.

## Objectives

- Register a custom type and confirm the API server now serves it.
- Observe that a CRD adds **data and validation** but **no behavior**.
- Trigger OpenAPI schema rejections and CEL rule rejections, and read the messages.
- Use the status subresource to write `status` independently of `spec`.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl` (≥ 1.25 for CEL rules and `--subresource`), and
  [kind](https://kind.sigs.k8s.io/).
- Starter files here: [`kind-config.yaml`](./kind-config.yaml),
  [`environment-crd.yaml`](./environment-crd.yaml),
  [`environment-sample.yaml`](./environment-sample.yaml), and
  [`environment-invalid.yaml`](./environment-invalid.yaml).
- Concepts from the [module README](../README.md).

## Steps

1. **Create the cluster.**

   ```bash
   kind create cluster --name pe-crd --config kind-config.yaml
   kubectl cluster-info --context kind-pe-crd
   ```

   A single-node cluster is plenty — CRDs live in the control plane.

2. **Register the Environment type.**

   ```bash
   kubectl apply -f environment-crd.yaml
   kubectl get crd environments.platform.example.com
   kubectl explain environment.spec --recursive | head -n 20
   ```

   `kubectl explain` reads your schema — the API server now documents your type the
   same way it documents built-ins. The new noun exists.

3. **Create valid resources and inspect the printer columns.**

   ```bash
   kubectl apply -f environment-sample.yaml
   kubectl get environments          # or: kubectl get env
   ```

   You should see `payments-dev` and `payments-prod` with the `TEAM`, `TIER`, `PHASE`,
   and `AGE` columns you defined. `PHASE` is empty — nothing has written `status` yet.

4. **Prove a CRD is data, not behavior.**

   ```bash
   kubectl get namespace payments-dev
   # Error from server (NotFound): namespaces "payments-dev" not found
   ```

   The `Environment` exists, but **no namespace was created**. There is no controller
   watching the type — that's exactly what you'll build in Module 10.2.

5. **Trigger every validation rule.** Each resource in the invalid file breaks exactly
   one rule. Apply them and read the rejection:

   ```bash
   kubectl apply -f environment-invalid.yaml
   ```

   Because the file holds four bad resources, `apply` reports multiple errors. Expect,
   in order: an **enum** rejection (`tier: production`), a **pattern** rejection
   (`team: Payments_Team`), and two **CEL** rejections (prod without `owner`; prod with
   one replica). Write down which mechanism — OpenAPI schema or CEL — caught each.

6. **Prove the immutability (transition) rule.** The CEL rule
   `self.tier == oldSelf.tier` only runs on updates. Try to change a tier:

   ```bash
   kubectl patch environment payments-dev --type=merge -p '{"spec":{"tier":"staging"}}'
   # Error ... spec.tier is immutable once set
   ```

   Create-time validation can't express this; a transition rule can, because it sees
   `oldSelf`.

7. **Use the status subresource.** Normal `apply` can't write `status` (it's a separate
   endpoint). Write it explicitly, then watch the printer column update:

   ```bash
   kubectl patch environment payments-dev --subresource=status --type=merge \
     -p '{"status":{"phase":"Ready","namespace":"payments-dev"}}'
   kubectl get env payments-dev
   ```

   `PHASE` now shows `Ready`. In Module 10.2 a controller will write this for you after
   it actually provisions the namespace.

## Expected result

- `kubectl get crd environments.platform.example.com` shows the CRD as `Established`.
- `kubectl get env` lists `payments-dev` and `payments-prod` with custom columns.
- No `payments-dev` namespace exists — confirming a CRD runs no controller.
- All four invalid resources are rejected, and you can name whether OpenAPI or CEL
  rejected each. The tier patch is rejected as immutable.
- After the status patch, `PHASE` reads `Ready`.

## Cleanup

> Tear the cluster down so it stops holding resources. Never skip this.

```bash
kind delete cluster --name pe-crd
```

## Reflection

- Which rules were enforceable with the OpenAPI schema alone, and which genuinely
  needed CEL? What does that tell you about when a webhook would still be required?
- You applied a valid `Environment` and nothing happened in the world. In your own
  words, what is missing, and what will it take to make the `Environment` *do* something?
- The status patch used a different endpoint than the spec. Why is separating those two
  writes useful once a controller is involved?

## Stretch goals (optional)

- Add a second served version `v1beta1` (with `served: true`, `storage: false`) that
  renames `costCenter` to `finops.costCenter`, and read about what a conversion strategy
  would need to do. (You don't have to implement the webhook.)
- Add a CEL rule that forbids `staging` and `prod` from sharing the same `team` + a
  reserved name, or that caps `replicas` for `dev` at 3. Re-apply and test it.
- Add `additionalPrinterColumns` for `OWNER` and `REPLICAS`, re-apply the CRD, and
  confirm `kubectl get env -o wide` shows them.
