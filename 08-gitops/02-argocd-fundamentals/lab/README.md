# Lab — Install Argo CD and run an auto-syncing Application

> You'll install Argo CD on a kind cluster, deploy the public guestbook app as a
> declarative `Application` with automated sync, watch self-heal revert drift,
> promote a change by editing Git-declared state, and inspect everything with the
> `argocd` CLI. This is the real version of the hand-built loop from Module 08.1.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A running Argo CD instance plus a `guestbook` Application that
reaches **Synced + Healthy**, self-heals drift, and shows its history in the CLI.

## Objectives

- Install Argo CD from upstream manifests on a local cluster.
- Create an `Application` declaratively and reach Synced + Healthy.
- Observe self-heal and prune in action.
- Read sync status, health, and history with the `argocd` CLI.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- The [`argocd` CLI](https://argo-cd.readthedocs.io/en/stable/cli_installation/)
  (optional but used below).
- Starter manifest in this folder: [`application.yaml`](./application.yaml).

## Steps

1. **Create a cluster and install Argo CD.**

   ```bash
   kind create cluster --name pe-argocd
   kubectl create namespace argocd
   kubectl apply -n argocd \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   kubectl -n argocd rollout status deploy/argocd-server --timeout=180s
   ```

   Every Argo CD component now runs *inside* the cluster — no external credentials
   involved.

2. **Log in to the API (optional but recommended).** Get the bootstrap password and
   port-forward the UI/API:

   ```bash
   kubectl -n argocd port-forward svc/argocd-server 8080:443 >/dev/null 2>&1 &
   ARGO_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath='{.data.password}' | base64 -d)
   argocd login localhost:8080 --username admin --password "$ARGO_PWD" --insecure
   ```

   Open <https://localhost:8080> in a browser to watch syncs visually (accept the
   self-signed cert).

3. **Create the Application declaratively.** Apply the starter manifest — the
   `Application` itself is GitOps:

   ```bash
   kubectl apply -f application.yaml
   kubectl -n argocd get applications
   ```

   Within a minute the `guestbook` app progresses to **Synced** and **Healthy**.

4. **Inspect it with the CLI.** Read both statuses and the resource tree:

   ```bash
   argocd app get guestbook
   argocd app resources guestbook
   kubectl -n guestbook get deploy,svc,pods
   ```

   Note the two distinct fields: **Sync Status** (matches Git?) and **Health Status**
   (actually working?).

5. **Introduce drift and watch self-heal.** Scale out of band; Argo CD reverts it:

   ```bash
   kubectl -n guestbook scale deployment guestbook-ui --replicas=5
   argocd app get guestbook        # momentarily OutOfSync, then self-healed to 1
   kubectl -n guestbook get deploy guestbook-ui -w   # Ctrl-C after it returns to 1
   ```

   Because `selfHeal: true` is set, the controller reconciles the live object back to
   the Git-declared replica count.

6. **See prune in action (safely).** Delete a managed resource and watch it return,
   then observe how removing it from Git would prune it:

   ```bash
   kubectl -n guestbook delete service guestbook-ui
   argocd app get guestbook        # controller re-creates the Service from Git
   ```

7. **Switch to manual sync, then promote a change.** Turn automation off so *you*
   drive sync, then point the app at a different path in the same public repo. With
   auto-sync disabled it stays OutOfSync until you act:

   ```bash
   argocd app set guestbook --sync-policy none    # manual control from here
   argocd app set guestbook --path kustomize-guestbook
   argocd app get guestbook        # OutOfSync: Git moved ahead, no auto-sync now
   argocd app sync guestbook       # you reconcile, by hand
   argocd app history guestbook    # every sync is a recorded, revertible revision
   ```

   `argocd app set` edits the live `Application`; in production that edit is a commit
   to the config repo instead (Module 08.3 automates exactly this).

8. **Roll back.** With automation off, a rollback sticks (auto-sync would otherwise
   immediately roll you forward again):

   ```bash
   argocd app rollback guestbook 0
   argocd app get guestbook
   ```

## Expected result

A `guestbook` Application that is **Synced + Healthy**, reverts drift within seconds,
re-creates deleted resources, records every sync in its history, and rolls back on
command. You've operated the production reconcile loop and read its two status
dimensions correctly.

## Cleanup

> Tear everything down so nothing lingers. Never skip this.

```bash
# Stop the port-forward if it's still running:
# find it with: jobs -l   then: kill %1   (or close the terminal)
kubectl delete -f application.yaml --ignore-not-found
kubectl delete namespace guestbook --ignore-not-found
kind delete cluster --name pe-argocd
```

## Reflection

- You deployed guestbook by editing an `Application`, never by running `kubectl
  apply` against the guestbook workload. Which GitOps principle does that enforce?
- The app was briefly **OutOfSync + Healthy** after you changed the path. Why is that
  pair a *delivery* state rather than an *application* problem?
- The `Application` manifest was applied with `kubectl`. How would you manage the
  `Application` itself via GitOps so even *it* is declared in a repo? (That's the
  next module.)

## Stretch goals (optional)

- Re-enable automation (`argocd app set guestbook --sync-policy automated --self-heal`)
  and confirm drift heals again; then disable just self-heal
  (`argocd app set guestbook --self-heal=false`), scale the Deployment manually, and
  confirm the drift now *persists*.
- Create an `AppProject` that restricts `guestbook` to the `guestbook` namespace and
  the example repo, then try (and fail) to point the app at a different namespace.
- Break the app on purpose (`argocd app set guestbook --revision does-not-exist`) and
  watch the status fields — note how sync fails while health stays last-known.
