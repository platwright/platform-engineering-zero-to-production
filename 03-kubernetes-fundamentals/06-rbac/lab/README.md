# Lab — Least-privilege RBAC for CI/CD

> You'll build the identity a deploy pipeline uses: a ServiceAccount that can manage
> Deployments in its own namespace but **cannot** read Secrets, delete the namespace,
> or touch any other namespace. Then you'll prove every boundary with `kubectl auth
> can-i` — turning "I think it's locked down" into "I verified it." Local kind cluster
> only.

**Estimated time:** ~40–50 minutes
**Type:** Build
**Deliverable:** A scoped CI/CD ServiceAccount plus a table of `auth can-i` results
proving what it can and cannot do.

## Objectives

- Create a ServiceAccount, Role, and RoleBinding by hand.
- Prove granted and denied actions with impersonation (`--as`).
- Internalize least privilege: grant the minimum, verify the rest is denied.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- Starter manifests here: [`namespace.yaml`](./namespace.yaml),
  [`cicd-serviceaccount.yaml`](./cicd-serviceaccount.yaml),
  [`cicd-role.yaml`](./cicd-role.yaml), and
  [`cicd-rolebinding.yaml`](./cicd-rolebinding.yaml).

## Steps

1. **Create a cluster.**

   ```bash
   kind create cluster --name pe-rbac
   ```

2. **Create the namespace and the ServiceAccount, then confirm default-deny.** Before
   any grant, the account can do almost nothing:

   ```bash
   kubectl apply -f namespace.yaml
   kubectl apply -f cicd-serviceaccount.yaml

   SA=system:serviceaccount:my-app:cicd-deployer
   kubectl auth can-i create deployments --as=$SA -n my-app      # → no
   kubectl auth can-i list pods --as=$SA -n my-app              # → no
   ```

3. **Grant least-privilege permissions.** Apply the Role (what can be done) and the
   RoleBinding (who can do it, where):

   ```bash
   kubectl apply -f cicd-role.yaml
   kubectl apply -f cicd-rolebinding.yaml
   kubectl describe rolebinding cicd-deployer-binding -n my-app
   ```

4. **Prove what the pipeline CAN do.** Re-check the granted actions in `my-app`:

   ```bash
   SA=system:serviceaccount:my-app:cicd-deployer
   kubectl auth can-i create deployments --as=$SA -n my-app      # → yes
   kubectl auth can-i update deployments --as=$SA -n my-app      # → yes
   kubectl auth can-i get pods --as=$SA -n my-app               # → yes
   ```

5. **Prove what it CANNOT do (the point of least privilege).** Every one of these
   should return `no`:

   ```bash
   SA=system:serviceaccount:my-app:cicd-deployer
   kubectl auth can-i get secrets        --as=$SA -n my-app      # → no (never granted)
   kubectl auth can-i delete deployments --as=$SA -n my-app      # → no (no delete verb)
   kubectl auth can-i delete namespaces  --as=$SA               # → no (cluster-scoped)
   kubectl auth can-i create deployments --as=$SA -n default     # → no (wrong namespace)
   ```

6. **Do a real end-to-end deploy as the ServiceAccount.** Confirm the permissions
   actually work for a genuine action, not just the checker:

   ```bash
   kubectl create deployment web --image=nginx -n my-app \
     --as=system:serviceaccount:my-app:cicd-deployer
   kubectl get deployment -n my-app

   # ...and confirm a forbidden action is actually blocked, not just reported:
   kubectl get secrets -n my-app --as=system:serviceaccount:my-app:cicd-deployer
   ```

   The deploy succeeds; the Secrets read is rejected with a clear `Forbidden` error.

7. **Record your results.** Fill in a quick table (granted vs denied) — this is
   exactly the evidence a security review asks for:

   ```text
   action                          namespace   expected   actual
   create deployments              my-app      yes
   get secrets                     my-app      no
   delete namespaces               (cluster)   no
   create deployments              default     no
   ```

## Expected result

A ServiceAccount that can deploy into `my-app` and nothing more: Secrets reads,
deletes, namespace deletion, and cross-namespace access are all denied — and you
proved each with `auth can-i` and one real `Forbidden` response. That is least
privilege, demonstrated.

## Cleanup

> Tear everything down so the cluster stops holding memory. Never skip this.

```bash
kubectl delete -f cicd-rolebinding.yaml --ignore-not-found
kubectl delete -f cicd-role.yaml --ignore-not-found
kubectl delete -f cicd-serviceaccount.yaml --ignore-not-found
kubectl delete -f namespace.yaml --ignore-not-found
kind delete cluster --name pe-rbac
```

## Reflection

- Why is `kubectl auth can-i --as=...` safer and faster than "try it and see" for
  verifying access?
- The Role has no `delete` verb and no `secrets` resource. In an incident where this
  token leaks, how does that limit the damage?
- What would change if you had used a `ClusterRoleBinding` instead of a
  `RoleBinding`? Why is that usually the wrong default?

## Stretch goals (optional)

- Create a read-only auditor: a `ClusterRole` with only `get,list,watch` on common
  resources and a `ClusterRoleBinding` to a new ServiceAccount; verify it can `list`
  everywhere but `create` nothing.
- Add `delete` for `deployments` to the Role, re-apply, and watch
  `auth can-i delete deployments` flip to `yes` — permissions update live.
- Run a Pod with `serviceAccountName: cicd-deployer` and, from inside it, call the
  API with the mounted token to see the same permissions apply to the workload.
