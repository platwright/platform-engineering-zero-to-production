# Lab — Build a GitOps reconcile loop by hand

> You'll become a GitOps agent. Using a local Git "remote," a working clone, and a
> 20-line shell loop, you'll reconcile a kind cluster toward Git — then prove the
> two behaviours that define GitOps: it heals out-of-band drift, and the only
> durable way to change the cluster is to change Git. No Argo CD yet; that's the
> point.

**Estimated time:** ~40–50 minutes
**Type:** Build
**Deliverable:** A running hand-built reconcile loop that reverts drift and applies
Git-driven changes, plus your notes on what it does and does not handle.

## Objectives

- Store declarative desired state in Git and reconcile a cluster to it in a loop.
- Observe self-healing: out-of-band `kubectl` changes are reverted automatically.
- Observe pull-based delivery: a change merged to the "remote" reaches the cluster
  without anyone pushing to it.
- Feel exactly which production concerns this toy agent is missing.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, [kind](https://kind.sigs.k8s.io/), `git`, and a Bash shell
  (Linux/macOS, or WSL2 on Windows).
- Starter files in this folder: [`reconcile.sh`](./reconcile.sh) and
  [`manifests/web.yaml`](./manifests/web.yaml).
- Two terminals open to this `lab/` directory — one runs the loop, one introduces
  drift.

## Steps

1. **Create a cluster.**

   ```bash
   kind create cluster --name pe-gitops-principles
   ```

2. **Create a local Git "remote" and a working clone.** The bare repo stands in for
   GitHub; the clone is what the agent reconciles from.

   ```bash
   git init --bare ./config-remote.git
   git clone ./config-remote.git ./config
   cp -r ./manifests ./config/manifests
   git -C ./config add .
   git -C ./config commit -m "initial desired state: web @ 2 replicas"
   git -C ./config push -u origin HEAD
   ```

   `./config` now holds the declared desired state (a namespace and a 2-replica
   Deployment), versioned in Git.

3. **Start the reconcile loop (terminal 1).** Leave it running; it is your GitOps
   agent.

   ```bash
   INTERVAL=10 bash ./reconcile.sh ./config
   ```

   It pulls from the remote, runs `kubectl apply`, and prints the commit it
   reconciled to every 10 seconds. Within one tick the namespace and Deployment
   appear.

4. **Confirm the initial sync (terminal 2).**

   ```bash
   kubectl get deploy,pods -n gitops-demo
   ```

   You should see the `web` Deployment with 2 ready replicas.

5. **Introduce drift and watch it heal (terminal 2).** Scale out of band, the way a
   late-night hotfix would:

   ```bash
   kubectl -n gitops-demo scale deployment web --replicas=7
   kubectl -n gitops-demo get deploy web -w   # watch; Ctrl-C after it returns to 2
   ```

   The count jumps to 7, then the loop's next `apply` restores the declared `2`.
   Nobody told it to — it is closing the gap between actual and desired.

6. **Delete a managed resource and watch it come back (terminal 2).**

   ```bash
   kubectl -n gitops-demo delete deployment web
   # within one interval the loop re-creates it from the manifest
   kubectl -n gitops-demo get deploy web
   ```

   Self-healing covers deletions too: if it's in Git, the agent restores it.

7. **Try the "right" way to change the system: edit Git.** Simulate a merged pull
   request by committing to the remote from a *second* clone, then let the agent
   pull it.

   ```bash
   git clone ./config-remote.git ./promote
   sed -i 's/replicas: 2/replicas: 4/' ./promote/manifests/web.yaml
   git -C ./promote commit -am "promote: scale web to 4 replicas"
   git -C ./promote push
   kubectl -n gitops-demo get deploy web -w   # watch it converge to 4, then Ctrl-C
   ```

   This change *sticks*, because it changed desired state. The agent pulled it and
   reconciled — pull-based delivery, end to end.

8. **Record what's missing.** In a comment or notes file, list capabilities this
   loop lacks that a real agent needs (for example: health assessment, pruning
   removed resources, ordering/dependencies, drift alerts, a UI, multi-cluster,
   RBAC). You'll meet each one in the next modules.

## Expected result

A loop that keeps the cluster pinned to Git: every out-of-band change (scale,
delete, image edit) is reverted within one interval, and the only change that
persists is the one you committed and pushed. You have implemented all four GitOps
principles — declarative, versioned, pulled, continuously reconciled — in a script
you can read top to bottom.

## Cleanup

> Always tear down so the cluster and local repos don't linger. Never skip this.

```bash
# Stop the loop in terminal 1 with Ctrl-C, then:
kubectl delete namespace gitops-demo --ignore-not-found
kind delete cluster --name pe-gitops-principles
rm -rf ./config ./config-remote.git ./promote
```

## Reflection

- Your loop reverts a manual scale within seconds. During a real incident, how would
  you make an emergency change *stick* without fighting the agent?
- The loop never deletes resources you remove from Git (it only `apply`s). Why is
  "pruning" a separate, riskier capability that production agents gate behind a flag?
- You ran the agent with your own kubeconfig. In production the agent runs *inside*
  the cluster. What attack surface does that remove compared with a CI job that runs
  `kubectl apply`?

## Stretch goals (optional)

- Add crude pruning: have the loop `kubectl apply --prune -l app=web` and then remove
  the Deployment from Git — watch it get deleted. Notice how much more dangerous this
  flag is than plain `apply`.
- Change the image tag in the `./promote` clone (`nginx:1.27-alpine` →
  `nginx:1.26-alpine`), push, and confirm the rollout reconciles — then `git revert`
  the commit, push, and watch the rollback happen by itself.
- Point the loop at a second kind cluster's context and reconcile both from the same
  Git remote — a one-line taste of multi-cluster GitOps.
