# Lab — Two clusters, one fleet

> You'll run **two** local kind clusters — a hub and a spoke — and manage both from one
> kubeconfig. First you'll deploy an app to each **by hand** (and feel why that drifts).
> Then you'll install Argo CD on the hub, register the spoke, and apply an **ApplicationSet
> cluster generator** that deploys and self-heals an app across the whole fleet from one
> declarative object. Cluster API stays conceptual; everything you run is free and local.

**Estimated time:** ~75–100 minutes
**Type:** Build
**Deliverable:** A hub + spoke managed from one kubeconfig, and an ApplicationSet that
fans an app out to both clusters with self-heal.

## Objectives

- Run two clusters and switch between them with kubeconfig contexts.
- Experience imperative multi-cluster deployment and its drift.
- Install Argo CD on a hub and register a second cluster.
- Fan one app out to every registered cluster with an ApplicationSet, and watch it
  self-heal.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker (enough RAM for **two** small clusters), `kubectl`, and
  [kind](https://kind.sigs.k8s.io/).
- **Part 2 also needs** the [`argocd` CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/),
  plus `docker` and GNU `base64` (Linux/WSL2) for [`register-spoke.sh`](./register-spoke.sh).
- Starter files: [`hub-cluster.yaml`](./hub-cluster.yaml),
  [`spoke-cluster.yaml`](./spoke-cluster.yaml), [`demo-app.yaml`](./demo-app.yaml),
  [`applicationset.yaml`](./applicationset.yaml), [`register-spoke.sh`](./register-spoke.sh),
  and [`capi-workload-cluster.illustrative.yaml`](./capi-workload-cluster.illustrative.yaml).

## Steps

### Part 1 — two clusters by hand (feel the drift)

1. **Create both clusters and list the contexts.**

   ```bash
   kind create cluster --name pe-hub --config hub-cluster.yaml
   kind create cluster --name pe-spoke --config spoke-cluster.yaml
   kubectl config get-contexts | grep pe-
   ```

   One kubeconfig now holds two contexts: `kind-pe-hub` and `kind-pe-spoke`.

2. **Deploy the demo app to each cluster — imperatively.**

   ```bash
   kubectl --context kind-pe-hub   apply -f demo-app.yaml
   kubectl --context kind-pe-spoke apply -f demo-app.yaml
   kubectl --context kind-pe-hub   get deploy demo
   kubectl --context kind-pe-spoke get deploy demo
   ```

   It works — but it's two commands for two clusters, with nothing keeping them in sync.
   Change the image on one and forget the other, and they silently diverge. That's the
   problem Part 2 solves.

### Part 2 — one fleet, declaratively

1. **Install Argo CD on the hub and log in.** In one terminal:

   ```bash
   kubectl --context kind-pe-hub create namespace argocd
   kubectl --context kind-pe-hub apply -n argocd \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl --context kind-pe-hub -n argocd rollout status deploy/argocd-server --timeout=180s
   ```

   In a second terminal, port-forward and log in with the initial admin password:

   ```bash
   kubectl --context kind-pe-hub -n argocd port-forward svc/argocd-server 8080:443
   # leave that running; in a third terminal:
   PASS=$(kubectl --context kind-pe-hub -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath='{.data.password}' | base64 -d)
   argocd login localhost:8080 --username admin --password "$PASS" --insecure
   ```

2. **Apply the ApplicationSet.** With only the hub registered (Argo CD always knows its own
   `in-cluster`), the generator already deploys guestbook to the hub:

   ```bash
   kubectl --context kind-pe-hub apply -f applicationset.yaml
   argocd app list
   kubectl --context kind-pe-hub -n guestbook get deploy
   ```

3. **Register the spoke, then watch the fleet grow.** The script adds the spoke and
   rewrites its endpoint to the shared docker network (read its header for why):

   ```bash
   bash register-spoke.sh
   argocd cluster list                       # in-cluster + pe-spoke
   # the generator now templates a second Application automatically:
   argocd app list
   kubectl --context kind-pe-spoke -n guestbook get deploy
   ```

   You added a cluster and the app appeared on it with **no edit to the ApplicationSet** —
   that's the cluster generator doing the fan-out.

4. **Prove fleet self-heal.** Delete the app on the spoke and watch Argo CD restore it from
   Git:

   ```bash
   kubectl --context kind-pe-spoke -n guestbook delete deploy guestbook-ui
   # within ~1 minute (or: argocd app sync guestbook-pe-spoke)
   kubectl --context kind-pe-spoke -n guestbook get deploy
   ```

   The reconciliation loop you've used all phase is now running at the *fleet* level: Git is
   desired state, and drift on any cluster is corrected.

5. **(Conceptual) read the Cluster API manifest.** Open
   [`capi-workload-cluster.illustrative.yaml`](./capi-workload-cluster.illustrative.yaml).
   It is **not** meant to be applied — it shows how CAPI would define this spoke as a
   declarative `Cluster` reconciled by a management cluster. Note the shape: a `Cluster`, a
   control plane, worker machines, and an infrastructure ref — the same spec/status loop,
   aimed at clusters themselves.

## Expected result

- Part 1: `demo` runs on both clusters, deployed by two separate imperative commands.
- Part 2: `argocd app list` shows one Application per registered cluster
  (`guestbook-in-cluster` and `guestbook-pe-spoke`), each `Synced`/`Healthy`.
- Deleting the guestbook Deployment on the spoke triggers an automatic re-sync that
  recreates it.
- You can explain why `register-spoke.sh` had to rewrite the API endpoint for kind.

## Cleanup

> Stop the port-forward and delete both clusters. Never skip this.

```bash
# Ctrl+C the port-forward terminal, then:
kind delete cluster --name pe-spoke
kind delete cluster --name pe-hub
```

## Reflection

- In Part 1 you ran two commands for two clusters. Extrapolate to 50 clusters: what
  specifically goes wrong, and which of those failure modes does the ApplicationSet remove?
- `register-spoke.sh` rewrote the spoke's API endpoint. What does that tell you about
  multi-cluster networking, and why does the problem vanish on real cloud clusters?
- Argo CD on the hub holds credentials to the spoke. What's the blast-radius risk, and how
  would a **pull-based** agent on each spoke change it?

## Stretch goals (optional)

- Add a third kind cluster, register it, and confirm the ApplicationSet deploys to it with
  **zero** changes to `applicationset.yaml`.
- Switch the generator to a `clusters` generator with a label selector, label only some
  clusters (e.g. `environment=prod`), and target just those.
- Change the guestbook source to a path you control and roll out a change to the whole
  fleet by committing once.
- Read the [Cluster API Quick Start](https://cluster-api.sigs.k8s.io/user/quick-start) and
  (optionally, on a capable machine) bring up a CAPI **Docker**-provider workload cluster
  with `clusterctl` to see declarative cluster lifecycle for real.
