# Lab — Base and overlays with Kustomize

> You'll build one environment-agnostic **base** and two **overlays** (`dev`, `prod`)
> that patch it differently — replicas, image tag, namespace, labels, a generated
> ConfigMap, and an HPA — then apply both to a kind cluster with `kubectl apply -k`
> and confirm the same base produced two distinct live variants. No templating, no
> cloud cost.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A `base` + `overlays/dev` + `overlays/prod` tree you've built and
applied, with dev and prod running side by side from a single source of truth.

## Objectives

- Build overlays locally with `kubectl kustomize` and read the transformed output.
- See strategic-merge patches, a JSON patch, transformers, and a generator in action.
- Apply overlays to a cluster and compare the two environments.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/). Kustomize is built into
  `kubectl` (`kubectl version` prints a `Kustomize Version`).
- Starter files in this folder: [`base/`](./base/), [`overlays/dev/`](./overlays/dev/),
  and [`overlays/prod/`](./overlays/prod/).

## Steps

1. **Look at the structure.** One base, two overlays:

   ```bash
   find base overlays -type f | sort
   ```

   The base holds valid, environment-agnostic manifests; each overlay references the
   base and layers on differences.

2. **Build the dev overlay — no cluster needed.** `kubectl kustomize` prints the final
   YAML:

   ```bash
   kubectl kustomize overlays/dev
   ```

   Scan the output and confirm the overlay's effects:

   - every name is prefixed `dev-` and lands in namespace `web-dev`
   - `replicas: 1` (the `replicas` transformer) and image tag `6.7.0` (the `images`
     transformer)
   - a ConfigMap named `dev-web-config-<hash>` (the generator's content hash), and the
     container's `envFrom` rewritten to that exact hashed name
   - the strategic-merge patch's annotation `example.com/environment: dev`

3. **Build the prod overlay and spot the differences.**

   ```bash
   kubectl kustomize overlays/prod | grep -E 'kind:|name:|replicas:|newTag|environment:|part-of|PODINFO_UI_MESSAGE'
   ```

   Note what prod does that dev doesn't: `replicas: 3`, image `6.7.1`, the
   `app.kubernetes.io/part-of`/`environment` labels on every object, an added
   `HorizontalPodAutoscaler`, and a `PODINFO_UI_MESSAGE` env var injected by a **JSON
   patch**. Notice the HPA's `scaleTargetRef.name` was automatically rewritten to
   `prod-web` — Kustomize tracks name references for you.

4. **Watch the content-hash rollout mechanism.** Note the current ConfigMap name, then
   change the generated config and rebuild:

   ```bash
   kubectl kustomize overlays/dev | grep 'name: dev-web-config'
   sed -i 's/LOG_LEVEL=debug/LOG_LEVEL=trace/' overlays/dev/kustomization.yaml
   kubectl kustomize overlays/dev | grep 'name: dev-web-config'
   ```

   The hash — and the `envFrom` reference to it — changed. On a cluster that forces a
   new rollout, which is how Kustomize prevents stale-config pods. Revert it:

   ```bash
   sed -i 's/LOG_LEVEL=trace/LOG_LEVEL=debug/' overlays/dev/kustomization.yaml
   ```

5. **Create a cluster and the two namespaces.** The overlays target namespaces, so
   create them first:

   ```bash
   kind create cluster --name pe-kustomize
   kubectl create namespace web-dev
   kubectl create namespace web-prod
   ```

6. **Apply both overlays.** `apply -k` builds the overlay and applies the result in one
   step:

   ```bash
   kubectl apply -k overlays/dev
   kubectl apply -k overlays/prod
   ```

7. **Compare the two live environments.** Same base, two outcomes:

   ```bash
   kubectl get deploy,svc,cm -n web-dev
   kubectl get deploy,svc,hpa -n web-prod
   ```

   `web-dev` runs one replica of `dev-web` with a hashed ConfigMap; `web-prod` runs
   three replicas of `prod-web` with an HPA — and you never copied the base.

8. **Prove the base is the single source of truth.** Confirm both Deployments trace
   back to the same base image repository, just different tags:

   ```bash
   kubectl get deploy dev-web -n web-dev -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
   kubectl get deploy prod-web -n web-prod -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'
   ```

## Expected result

From one base you built and deployed two environments that differ only where you
declared a difference: `dev` is a single replica on an older tag with debug config;
`prod` is three replicas on a newer tag, labelled, with an HPA and an injected env
var. The base YAML was never copied or templated — overlays described the deltas and
Kustomize combined them.

## Cleanup

> Tear everything down. Never skip this.

```bash
kubectl delete -k overlays/prod --ignore-not-found
kubectl delete -k overlays/dev --ignore-not-found
kind delete cluster --name pe-kustomize
```

## Reflection

- The base contained no namespace and no environment-specific image tag. Why is
  keeping the base environment-agnostic the single most important Kustomize habit?
- Changing one literal changed the ConfigMap's name. How does that one behavior
  eliminate a whole class of "I updated config but nothing changed" incidents?
- You used a strategic-merge patch in dev and a JSON patch in prod. For each, say why
  that patch style fit the change you were making.

## Stretch goals (optional)

- Add a `staging` overlay that is like prod but with two replicas and no HPA. How much
  new YAML did it actually take?
- In the prod overlay, add a `commonAnnotations` entry and rebuild — notice it lands on
  every object, selectors included or not depending on the transformer.
- Pipe a build into a policy check or a diff: `kubectl kustomize overlays/prod |
  kubectl diff -f -` against the running cluster to preview a change before applying.
