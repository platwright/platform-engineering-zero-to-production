# Lab — Deployments, rollouts, and StatefulSets

> You'll run a stateless app as a Deployment, perform a zero-downtime rolling update
> and an instant rollback while watching the ReplicaSets swap, then run a StatefulSet
> and prove its Pods keep stable, ordered identities across deletion. Local kind
> cluster only — no cloud cost.

**Estimated time:** ~45–60 minutes
**Type:** Build
**Deliverable:** A Deployment you've updated and rolled back, and a StatefulSet whose
Pod identities you've verified as stable.

## Objectives

- Observe the Deployment → ReplicaSet → Pod ownership chain.
- Run a rolling update and roll it back.
- Contrast Deployment Pods ("cattle") with StatefulSet Pods ("pets").

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- Starter manifests in this folder: [`deployment.yaml`](./deployment.yaml) and
  [`statefulset.yaml`](./statefulset.yaml).

## Steps

1. **Create a cluster.** A single node is enough for this lab:

   ```bash
   kind create cluster --name pe-workloads
   ```

2. **Deploy the stateless app and see the ownership chain.** Apply the Deployment and
   look at what reconciliation built:

   ```bash
   kubectl apply -f deployment.yaml
   kubectl rollout status deployment/web
   kubectl get deploy,rs,pods -l app=web
   ```

   One Deployment owns one ReplicaSet, which owns three Pods with random name
   suffixes (cattle — any Pod is as good as any other).

3. **Roll out a new version.** Change the image and watch the update progress. The
   strategy (`maxSurge: 1, maxUnavailable: 0`) adds a new Pod before removing an old
   one, so capacity never dips:

   ```bash
   kubectl set image deployment/web nginx=nginx:1.27
   kubectl rollout status deployment/web
   kubectl get rs -l app=web
   ```

   You'll now see **two** ReplicaSets: the old one scaled to `0`, the new one at `3`.
   The old one is kept so you can roll back.

4. **Roll back instantly.** Suppose 1.27 misbehaves. Revert to the previous
   ReplicaSet — no rebuild, no re-pull of a new image:

   ```bash
   kubectl rollout undo deployment/web
   kubectl rollout status deployment/web
   kubectl rollout history deployment/web
   kubectl get pods -l app=web -o jsonpath='{.items[0].spec.containers[0].image}{"\n"}'
   ```

   The image is back to `nginx:1.25`. Then remove the Deployment to keep the next
   step's output clean:

   ```bash
   kubectl delete -f deployment.yaml
   ```

5. **Deploy a StatefulSet.** Apply the headless Service + StatefulSet and watch Pods
   come up **in order**:

   ```bash
   kubectl apply -f statefulset.yaml
   kubectl get pods -l app=web-sts -w     # web-0 Ready, THEN web-1, THEN web-2; Ctrl+C
   ```

   The Pods are named `web-0`, `web-1`, `web-2` — ordinal identities, not random
   suffixes.

6. **Prove identity is stable.** Delete the middle Pod and watch its replacement come
   back with the **same name**:

   ```bash
   kubectl delete pod web-1
   kubectl get pods -l app=web-sts -w     # a new web-1 appears (same name); Ctrl+C
   ```

   Confirm each Pod resolves to a stable DNS name via the headless Service:

   ```bash
   kubectl run dnstest --image=busybox:1.36 --restart=Never -it --rm -- \
     nslookup web-0.web.default.svc.cluster.local
   ```

7. **Compare the two mental models.** A Deployment replaced a deleted Pod with a
   *different* name; the StatefulSet replaced it with the *same* name. That's the
   cattle-vs-pets distinction made concrete.

## Expected result

You updated a Deployment and watched a new ReplicaSet take over with no capacity dip,
rolled back to the exact previous version, and confirmed a StatefulSet's Pods keep
ordered, stable names (`web-0..2`) and DNS identities across deletion.

## Cleanup

> Tear everything down so the cluster doesn't hold memory open. Never skip this.

```bash
kubectl delete -f statefulset.yaml --ignore-not-found
kind delete cluster --name pe-workloads
```

## Reflection

- During the rolling update, why did having `maxUnavailable: 0` matter for a
  user-facing service? What would `maxUnavailable: 1` change?
- The StatefulSet's replacement Pod kept the name `web-1`. Why does a database care
  about that but a stateless web server doesn't?
- `kubectl rollout undo` was instant. What made an instant rollback possible (hint:
  what was the old ReplicaSet still doing)?

## Stretch goals (optional)

- Add a bad image (`kubectl set image deployment/web nginx=nginx:doesnotexist`),
  watch the rollout *stall* instead of breaking the running app, then `rollout undo`.
- Create a `CronJob` that runs `date` every minute
  (`kubectl create cronjob clock --image=busybox:1.36 --schedule="*/1 * * * *" --
  /bin/date`) and watch Jobs appear with `kubectl get jobs -w`.
- Add an `initContainer` to `deployment.yaml` that `sleep`s for 5 seconds and
  observe the Pod wait in `Init:` state before the app container starts.
