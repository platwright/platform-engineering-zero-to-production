# Lab — Segment a two-cluster fleet

> You'll run **two** local kind clusters — a management cluster and a workload
> cluster — and register the workload cluster with ArgoCD **carrying segment labels**
> (`environment`, `region`). Then you'll deploy with an **ApplicationSet cluster
> generator plus a label selector**, so the app lands on the matching segment only —
> not blindly on every cluster. Finally you'll change a label and watch fleet
> membership change with **zero** edits to the app. Everything runs free and local.

**Estimated time:** ~60–80 minutes
**Type:** Build
**Deliverable:** A two-cluster fleet where a label-targeted ApplicationSet deploys an
app to a chosen segment, and re-labelling a cluster adds or removes it from the target
set automatically.

## Objectives

- Register a workload cluster with ArgoCD and attach **segment labels**.
- Target a **subset** of the fleet with a cluster generator `selector`.
- Flow a segment label into per-segment config (the destination namespace).
- Prove that membership is driven by labels: re-label a cluster and watch the
  Application appear or disappear.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker (enough RAM for **two** small clusters), `kubectl`, and
  [kind](https://kind.sigs.k8s.io/).
- The [`argocd` CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/), plus
  `docker` and GNU `base64` (Linux/WSL2) for [`register-workload.sh`](./register-workload.sh).
- [Module 10.5's lab](../../../10-kubernetes-advanced/05-multi-cluster-kubernetes/lab/)
  (the two-kind-cluster + ArgoCD setup this builds on) and
  [Module 08.3 · ApplicationSets](../../../08-gitops/03-argocd-applicationsets/).
- Starter files: [`mgmt-cluster.yaml`](./mgmt-cluster.yaml),
  [`workload-cluster.yaml`](./workload-cluster.yaml),
  [`applicationset-by-label.yaml`](./applicationset-by-label.yaml),
  [`register-workload.sh`](./register-workload.sh), and
  [`clustermesh-global-service.illustrative.yaml`](./clustermesh-global-service.illustrative.yaml).

## Steps

### Part 1 — register a segment and target it

1. **Create both clusters and list the contexts.**

   ```bash
   kind create cluster --name pe-mgmt --config mgmt-cluster.yaml
   kind create cluster --name pe-prod-eu --config workload-cluster.yaml
   kubectl config get-contexts | grep pe-
   ```

   One kubeconfig now holds `kind-pe-mgmt` (management) and `kind-pe-prod-eu`
   (a workload cluster that will represent the `prod` / `eu` segment).

2. **Install ArgoCD on the management cluster and log in.** In one terminal:

   ```bash
   kubectl --context kind-pe-mgmt create namespace argocd
   kubectl --context kind-pe-mgmt apply -n argocd \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl --context kind-pe-mgmt -n argocd rollout status deploy/argocd-server --timeout=180s
   ```

   In a second terminal, port-forward and log in with the initial admin password:

   ```bash
   kubectl --context kind-pe-mgmt -n argocd port-forward svc/argocd-server 8080:443
   # leave that running; in a third terminal:
   PASS=$(kubectl --context kind-pe-mgmt -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath='{.data.password}' | base64 -d)
   argocd login localhost:8080 --username admin --password "$PASS" --insecure
   ```

3. **Register the workload cluster with segment labels.** The script adds the cluster,
   attaches `environment=prod` and `region=eu`, and rewrites its endpoint to the shared
   docker network (read its header for *why* — same kind quirk as Module 10.5):

   ```bash
   bash register-workload.sh
   # confirm the labels landed on the cluster secret:
   kubectl --context kind-pe-mgmt -n argocd get secret \
     -l argocd.argoproj.io/secret-type=cluster \
     -o custom-columns=NAME:.metadata.name,ENV:.metadata.labels.environment,REGION:.metadata.labels.region
   ```

4. **Apply the label-targeted ApplicationSet.** Its selector is
   `environment: prod`, so it targets the workload cluster — **not** the management
   cluster (whose `in-cluster` entry has no such label):

   ```bash
   kubectl --context kind-pe-mgmt apply -f applicationset-by-label.yaml
   argocd app list
   ```

   You should see exactly **one** Application — `web-pe-prod-eu` — and none targeting
   the management cluster. The selector excluded the unlabelled `in-cluster`. That is
   segmentation: config reaches the chosen segment, not everything.

5. **See the segment label flow into config.** The template sets the destination
   namespace from the cluster's `environment` label (`web-{{metadata.labels.environment}}`):

   ```bash
   kubectl --context kind-pe-prod-eu get ns | grep web-
   kubectl --context kind-pe-prod-eu -n web-prod get deploy
   ```

   The app landed in `web-prod` on the workload cluster — the namespace was derived from
   the segment, not hard-coded.

### Part 2 — membership follows labels, not edits

1. **Re-label the cluster out of the segment.** Simulate re-segmenting the cluster to
   `staging` and watch the Application disappear (it no longer matches the selector):

   ```bash
   SECRET=$(kubectl --context kind-pe-mgmt -n argocd get secret \
     -l argocd.argoproj.io/secret-type=cluster -o name | head -1)
   kubectl --context kind-pe-mgmt -n argocd label "$SECRET" environment=staging --overwrite
   sleep 10
   argocd app list        # web-pe-prod-eu is gone — the cluster left the prod segment
   ```

2. **Re-label it back and watch it return.** Membership is declarative — driven by the
   label, with no change to `applicationset-by-label.yaml`:

   ```bash
   kubectl --context kind-pe-mgmt -n argocd label "$SECRET" environment=prod --overwrite
   sleep 10
   argocd app list        # web-pe-prod-eu is back
   ```

   You just changed what the fleet deploys by changing one label — the segmentation
   strategy made executable.

3. **(Conceptual) read the Cluster Mesh sketch.** Open
   [`clustermesh-global-service.illustrative.yaml`](./clustermesh-global-service.illustrative.yaml).
   It is **not** meant to be applied here — it shows how a Service becomes **global**
   across Cilium-meshed clusters (the `service.cilium.io/global` annotation). Cross-cluster
   discovery needs a real multi-node network and a Cilium Cluster Mesh, which is why this
   free, single-host lab keeps it conceptual. Note how little you add to a Service — and
   remember the lesson's warning: reach for it only when you can name the need.

## Expected result

- After Part 1, `argocd app list` shows a single Application (`web-pe-prod-eu`) targeting
  the workload cluster, `Synced`/`Healthy`, in namespace `web-prod` — and nothing on the
  management cluster.
- The cluster secret carries `environment=prod` and `region=eu` labels.
- In Part 2, re-labelling the cluster to `staging` removes the Application within seconds;
  re-labelling to `prod` restores it — with no edit to the ApplicationSet.
- You can explain why the `in-cluster` entry was never targeted.

## Cleanup

> Stop the port-forward and delete both clusters. Never skip this.

```bash
# Ctrl+C the port-forward terminal, then:
kind delete cluster --name pe-prod-eu
kind delete cluster --name pe-mgmt
```

## Reflection

- The selector targeted `environment=prod`. How would you deploy a *different* overlay to
  `environment=dev` clusters at the same time — one ApplicationSet or two, and why?
- In Part 2 you changed fleet membership by editing a label. What is the operational risk
  of that power, and how would GitOps-managing the cluster secrets reduce it?
- The app never needed to call a Service in the other cluster. Trace what you would have had
  to add (networking, DNS, a mesh) if it did — and argue for a design that avoids it.

## Stretch goals (optional)

- Add a third kind cluster labelled `environment=dev,region=eu`, register it, and apply a
  second ApplicationSet with selector `environment=dev` pointing at a different overlay —
  two segments, two paved roads, one fleet.
- Switch the generator template to also set a Helm value or kustomize overlay path from
  `{{metadata.labels.region}}`, and confirm per-region config without touching the app.
- Add `region=us` to a cluster and change the selector to `matchExpressions` targeting
  `region In (eu, us)` to practise expression-based segment selection.
- Read the [Cilium Cluster Mesh prerequisites](https://docs.cilium.io/en/stable/network/clustermesh/clustermesh/)
  and sketch (on paper) what it would take to make the stretch dev and prod clusters share
  a global Service.
