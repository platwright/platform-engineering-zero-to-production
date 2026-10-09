# Lab — Self-Service Databases with Crossplane (Local & Free)

> You'll turn a local `kind` cluster into an infrastructure **control plane**: install
> Crossplane, install a **no-cloud provider**, publish a self-service API (**XRD**)
> and its implementation (**Composition**), then play the developer and provision a
> "database" with a single `kubectl apply`. No cloud account, no cost.

**Estimated time:** ~60–90 minutes
**Type:** Build
**Deliverable:** A `PostgreSQLInstance` claim that reaches `READY=True`, backed by a
composed managed resource you can inspect.

## Objectives

- Install Crossplane and a provider on a local cluster.
- Define an **XRD** (the self-service API) and a **Composition** (its implementation).
- Create a **claim** as a developer would and watch Crossplane compose + reconcile it.
- Inspect **managed resources** and understand the claim → XR → MR chain.

## Prerequisites

- [`kind`](https://kind.sigs.k8s.io/docs/user/quick-start/), `kubectl`, and
  [Helm](https://helm.sh/docs/intro/install/) (see
  [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)).
- Docker running (for `kind`).
- Internet access to pull the Crossplane, provider, and function images.
- Starter manifests in this folder, applied in order:
  [`01-provider-nop.yaml`](./01-provider-nop.yaml),
  [`02-function-patch-and-transform.yaml`](./02-function-patch-and-transform.yaml),
  [`03-xrd.yaml`](./03-xrd.yaml), [`04-composition.yaml`](./04-composition.yaml),
  [`05-claim.yaml`](./05-claim.yaml).

> **Cost note:** This lab uses `provider-nop`, which creates *fake* managed resources
> that never touch a cloud — **zero spend, no credentials needed.** Cloud providers
> (GCP/AWS/Azure) are **optional**; see "Going real (optional)" at the end. If you do
> use a cloud provider, destroy everything immediately after (see Cleanup).

## Steps

1. **Create a local cluster.**

   ```bash
   kind create cluster --name crossplane-lab
   kubectl cluster-info --context kind-crossplane-lab
   ```

2. **Install Crossplane** via Helm into its own namespace:

   ```bash
   helm repo add crossplane-stable https://charts.crossplane.io/stable
   helm repo update
   helm install crossplane crossplane-stable/crossplane \
     --namespace crossplane-system --create-namespace --wait
   kubectl get pods -n crossplane-system
   ```

3. **Install the no-cloud provider and the function.** Apply and wait until both
   report `HEALTHY=True` (image pulls take a minute):

   ```bash
   cd 05-infrastructure-as-code/06-crossplane/lab
   kubectl apply -f 01-provider-nop.yaml
   kubectl apply -f 02-function-patch-and-transform.yaml

   kubectl get providers.pkg.crossplane.io
   kubectl get functions.pkg.crossplane.io
   # wait for HEALTHY=True on both:
   kubectl wait --for=condition=Healthy provider.pkg.crossplane.io/provider-nop --timeout=180s
   kubectl wait --for=condition=Healthy function.pkg.crossplane.io/function-patch-and-transform --timeout=180s
   ```

4. **Publish the self-service API (XRD).** This creates your new `PostgreSQLInstance`
   and `XPostgreSQLInstance` kinds:

   ```bash
   kubectl apply -f 03-xrd.yaml
   kubectl get xrd
   kubectl wait --for=condition=Established xrd/xpostgresqlinstances.platform.example.com --timeout=120s
   ```

5. **Apply the Composition.** This is the platform team's implementation — how an XR
   turns into managed resources:

   ```bash
   kubectl apply -f 04-composition.yaml
   kubectl get composition
   ```

6. **Be the developer: request a database.** This is the *entire* developer
   experience — nine lines of YAML:

   ```bash
   kubectl apply -f 05-claim.yaml
   ```

   Watch the claim → XR → managed resource chain come up (the NopResource turns Ready
   after ~5s):

   ```bash
   kubectl get postgresqlinstance,xpostgresqlinstance
   kubectl get managed
   kubectl wait --for=condition=Ready postgresqlinstance/my-app-db --timeout=120s
   ```

7. **Inspect the chain.** See how one claim fanned out:

   ```bash
   kubectl describe postgresqlinstance my-app-db        # the developer's claim
   kubectl get nopresources.nop.crossplane.io -o yaml | grep -A3 engineVersion
   ```

   Notice `engineVersion: "15"` was **patched** from the claim's `version` parameter
   onto the composed resource — the Composition did the wiring.

## Expected result

- `kubectl get postgresqlinstance my-app-db` shows `SYNCED=True` and `READY=True`.
- `kubectl get managed` lists a `NopResource` created on the claim's behalf.
- The composed `NopResource` has `engineVersion: "15"`, proving the Composition
  patched the developer's requested version through.
- You can trace **claim → XR → managed resource** and explain each hop.

## Cleanup

> Always tear down — delete the claim first so Crossplane removes composed resources,
> then delete the cluster. (With a real cloud provider this is what prevents charges.)

```bash
kubectl delete -f 05-claim.yaml
kubectl get managed        # confirm composed resources are gone
kind delete cluster --name crossplane-lab
```

## Reflection

- You gave the developer the power to provision infrastructure with `kubectl apply`,
  yet they never saw a cloud credential or a Composition. Where did the guardrails
  live, and why is "they can only request what the XRD allows" such a powerful safety
  property?
- Delete the composed `NopResource` by hand
  (`kubectl delete nopresource <name>`) and re-check `kubectl get managed`. What
  does Crossplane do, and how is that different from `terraform apply` catching drift?
- The developer's claim YAML wouldn't change if you swapped `provider-nop` for a real
  cloud provider. Why is that stable interface the whole point of XRDs?

## Stretch goals (optional)

- Add a second Composition labelled `environment: development` that composes a
  *different* NopResource config, and switch the claim's `compositionSelector` to it.
- Extend the XRD schema with a `region` parameter and patch it onto the composed
  resource.
- **Going real (optional, cloud cost):** install `provider-gcp`/`provider-aws`,
  configure a `ProviderConfig` with credentials, and point the Composition at a real
  managed resource (e.g. a storage bucket). **Cost warning:** this creates billable
  cloud resources — destroy them immediately with `kubectl delete` and verify in the
  cloud console.
