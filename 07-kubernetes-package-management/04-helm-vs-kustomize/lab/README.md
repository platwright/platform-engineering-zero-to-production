# Lab — Deploy one app three ways

> You'll deploy the **same** app three ways on kind — Helm only, Kustomize only, and a
> Helm-rendered base with a Kustomize overlay — then compare the source shape,
> maintainability, and cognitive load of each. The point isn't that one wins; it's
> feeling *why* you'd pick each. No cloud cost.

**Estimated time:** ~45–60 minutes
**Type:** Build + compare
**Deliverable:** The same workload running in three namespaces via three methods, plus
your own notes on which approach fit which situation.

## Objectives

- Produce identical manifests from a Helm chart and from a Kustomize overlay.
- Combine the two: render with Helm, patch the deltas with Kustomize.
- Compare the three by source shape and maintainability, not just the running result.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- [Helm](https://helm.sh/docs/intro/install/) installed. (Commands assume a bash-like
  shell; on Windows use WSL2 so `>` redirection writes UTF-8.)
- Starter files in this folder: [`helm-app/`](./helm-app/) (a chart),
  [`kustomize-app/`](./kustomize-app/) (base + prod overlay), and
  [`helm-kustomize/`](./helm-kustomize/) (the combination).

## Steps

1. **See the three sources side by side.** Same app, three representations:

   ```bash
   find helm-app kustomize-app helm-kustomize -type f | sort
   ```

   `helm-app` is a *template* (not valid YAML on its own). `kustomize-app` is *real
   YAML* plus an overlay. `helm-kustomize` is a small overlay that patches Helm's
   output.

2. **Render each locally and compare the shape.** Look at what you had to read to
   understand each:

   ```bash
   helm template web ./helm-app                      # template + values → YAML
   kubectl kustomize kustomize-app/overlays/prod     # real YAML in → real YAML out
   ```

   Note: the Helm source has `{{ }}` you must mentally execute; the Kustomize source is
   plain YAML a reviewer reads directly.

3. **Create a cluster.** One node is enough for all three:

   ```bash
   kind create cluster --name pe-three-ways
   ```

4. **Method 1 — Helm only.** Install the chart as a release in its own namespace:

   ```bash
   helm install web ./helm-app \
     --namespace three-helm --create-namespace --wait
   kubectl get deploy,svc -n three-helm --show-labels
   ```

   You get lifecycle management for free (`helm history web -n three-helm`,
   `helm rollback`). The trade-off: the repo source is a template, not YAML.

5. **Method 2 — Kustomize only.** Apply the overlay into its own namespace:

   ```bash
   kubectl create namespace three-kustomize
   kubectl apply -k kustomize-app/overlays/prod -n three-kustomize
   kubectl get deploy,svc -n three-kustomize --show-labels
   ```

   Everything you applied was plain YAML — no templating to reason about. The
   trade-off: no release/rollback/history and no package to distribute.

6. **Method 3 — Helm + Kustomize.** Render the chart to a base, then let Kustomize
   patch the environment delta (scale to 3, relabel) on top:

   ```bash
   kubectl create namespace three-combo
   helm template web ./helm-app > helm-kustomize/rendered.yaml
   kubectl kustomize helm-kustomize            # inspect: Deployment now replicas=3
   kubectl apply -k helm-kustomize -n three-combo
   kubectl get deploy,svc -n three-combo --show-labels
   ```

   The Helm chart stayed the versioned base; the overlay expressed only the deltas —
   no fork, no extra chart values. This is what Argo CD can do natively.

7. **Compare the running result.** All three deployed the *same* app; the
   `deployed-with` label records how:

   ```bash
   kubectl get deploy -A -l app=web \
     -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,REPLICAS:.spec.replicas,VIA:.metadata.labels.deployed-with'
   ```

   You should see three Deployments: `helm` (2 replicas), `kustomize` (3),
   `helm-plus-kustomize` (3) — one workload, three delivery mechanisms.

8. **Compare the sources, not just the output.** Re-open each method's files and jot
   down, for each: How many files? Is the source valid YAML? Could a new teammate read
   it without running a renderer? Does it give you rollback/versioning? This is the
   real deliverable — the decision framework made concrete.

## Expected result

The same app runs in `three-helm`, `three-kustomize`, and `three-combo`, produced by a
Helm chart, a Kustomize overlay, and a Helm-rendered base patched by Kustomize. You can
articulate the trade-off each made: Helm gave you packaging and lifecycle at the cost of
a template language; Kustomize gave you plain-YAML clarity at the cost of
packaging/lifecycle; the combination kept a versioned base while expressing environment
deltas as a tiny overlay.

## Cleanup

> Tear everything down. Never skip this.

```bash
helm uninstall web -n three-helm
kubectl delete -k kustomize-app/overlays/prod -n three-kustomize --ignore-not-found
kubectl delete -k helm-kustomize -n three-combo --ignore-not-found
kubectl delete namespace three-helm three-kustomize three-combo --ignore-not-found
rm -f helm-kustomize/rendered.yaml
kind delete cluster --name pe-three-ways
```

## Reflection

- For *your* day job, which method would you choose for (a) distributing a workload to
  many teams, and (b) configuring three environments of an app you own? Why?
- The combination kept the chart as a versioned base and used a three-line overlay for
  the delta. When is that better than adding another value to the chart?
- Which source would you least want to hand a brand-new teammate at 2 a.m. during an
  incident, and what does that tell you about cognitive load as a design input?

## Stretch goals (optional)

- Make the *same* one-field change (set replicas to 5) in all three methods. Count the
  edits and the mental steps each required.
- Try the native inflation path: add a `helmCharts:` block to a kustomization and run
  `kustomize build --enable-helm`. Compare it to the `helm template > rendered.yaml`
  approach you used here.
- Point an Argo CD Application (Phase 8) at each source in turn and confirm it renders
  all three — proving the packaging choice is per-app, not a platform mandate.
