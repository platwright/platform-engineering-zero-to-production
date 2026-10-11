# Lab — Audit and lock down RBAC

> You'll put on a platform-security hat: audit a cluster for the three RBAC findings that cause real
> incidents (wildcards, `cluster-admin` holders, cluster-wide ServiceAccounts), answer "who can do X?"
> for sensitive actions, grow a capability with an **aggregated ClusterRole**, and build a
> **least-privilege CI/CD ServiceAccount** you *prove* — granted and denied — with `kubectl auth can-i`.
> Local kind cluster only.

**Estimated time:** ~45–60 minutes
**Type:** Discovery / build
**Deliverable:** An RBAC risk-audit finding list (wildcards, `cluster-admin` holders, cluster-wide
ServiceAccounts) plus a least-privilege CI ServiceAccount proven with a table of `auth can-i` results.

## Objectives

- Audit a live cluster for over-broad grants and record them as a finding list (OWASP K03).
- Answer "who can `<verb> <resource>`?" for sensitive actions, with or without the `who-can` plugin.
- Grow an aggregated ClusterRole by adding one labeled role — with no edit to the aggregate.
- Build and **prove** a least-privilege CI/CD ServiceAccount with impersonation.

## Prerequisites

- [`00-orientation/environment-setup.md`](../../../00-orientation/environment-setup.md)
  — Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- `jq` — the audit script is built on it. Install it from your package manager.
- *Optional:* the `kubectl-who-can` krew plugin (`kubectl krew install who-can`). The lab provides a
  pure-`kubectl auth can-i` fallback, so everything runs without it.
- Starter files here: [`rbac-audit.sh`](./rbac-audit.sh), [`who-can-checks.sh`](./who-can-checks.sh),
  [`aggregated-clusterrole.yaml`](./aggregated-clusterrole.yaml), and
  [`cicd-serviceaccount.yaml`](./cicd-serviceaccount.yaml).

## Steps

1. **Create a cluster.**

   ```bash
   kind create cluster --name pe-rbac-audit
   kubectl cluster-info --context kind-pe-rbac-audit
   ```

2. **Run the RBAC audit.** The script sweeps four things: ServiceAccounts bound cluster-wide,
   `cluster-admin` holders, wildcard (`*`) roles, and RoleBinding counts per namespace.

   ```bash
   chmod +x rbac-audit.sh
   ./rbac-audit.sh | tee rbac-findings.txt
   ```

   On a fresh kind cluster the wildcard list is dominated by built-ins (`cluster-admin` and system
   roles). That's your **baseline** — the known-good set. Anything you or a Helm chart adds later that
   shows up here is a finding. Keep `rbac-findings.txt` as the first half of your deliverable.

3. **Manufacture a finding, then catch it.** Deliberately over-grant a ServiceAccount, re-run the audit,
   and watch it surface — exactly the signal you hunt in production:

   ```bash
   kubectl create serviceaccount risky -n default
   kubectl create clusterrolebinding risky-admin \
     --clusterrole=cluster-admin --serviceaccount=default:risky
   ./rbac-audit.sh | tee rbac-findings.txt
   ```

   Sections (a) and (b) now list `default/risky` — a ServiceAccount holding `cluster-admin`. That is
   OWASP **K03**. Record it, then remove it:

   ```bash
   kubectl delete clusterrolebinding risky-admin
   kubectl delete serviceaccount risky -n default
   ```

4. **Ask "who can do X?" for sensitive actions.** Run the checks script — with the `who-can` plugin it
   lists the subjects directly; without it, the script prints the fallback it wants you to use.

   ```bash
   chmod +x who-can-checks.sh
   ./who-can-checks.sh
   ```

   No plugin? Answer the same questions with the authorizer. For example, confirm the built-in group
   `system:masters` can do everything while an ordinary ServiceAccount cannot:

   ```bash
   kubectl auth can-i '*' '*' --as=any --as-group=system:masters              # → yes
   kubectl auth can-i create clusterrolebindings \
     --as=system:serviceaccount:default:default                              # → no
   kubectl auth can-i --list --as=system:serviceaccount:default:default      # effective set
   ```

5. **Grow a capability with an aggregated ClusterRole.** Apply the starter, then confirm the aggregate
   already unions its two labeled roles:

   ```bash
   kubectl apply -f aggregated-clusterrole.yaml
   kubectl describe clusterrole app-team-admin
   ```

   The `Rules` show pods/services/configmaps (read) **and** deployments/replicasets (manage). Now **add
   one labeled role** and watch the aggregate grow — with no edit to `app-team-admin`:

   ```bash
   kubectl create clusterrole app-team-manage-ingress \
     --verb=get,list,watch,create,update,patch \
     --resource=ingresses.networking.k8s.io
   kubectl label clusterrole app-team-manage-ingress \
     rbac.example.com/aggregate-to-app-team-admin=true
   kubectl describe clusterrole app-team-admin
   ```

   `app-team-admin` now **also** lists `ingresses`. You grew a capability by *adding* a small role, never
   by editing the big one — the platform-friendly pattern.

6. **Create the least-privilege CI/CD ServiceAccount.**

   ```bash
   kubectl apply -f cicd-serviceaccount.yaml
   kubectl describe rolebinding cicd-deployer-binding -n team-apps
   ```

7. **Prove what it CAN do (granted).** Re-check the granted actions in `team-apps`:

   ```bash
   SA=system:serviceaccount:team-apps:cicd-deployer
   kubectl auth can-i create deployments --as=$SA -n team-apps   # → yes
   kubectl auth can-i update deployments --as=$SA -n team-apps   # → yes
   kubectl auth can-i get configmaps     --as=$SA -n team-apps   # → yes
   ```

8. **Prove what it CANNOT do (the point of least privilege).** Every one should return `no`:

   ```bash
   SA=system:serviceaccount:team-apps:cicd-deployer
   kubectl auth can-i get secrets        --as=$SA -n team-apps   # → no (never granted)
   kubectl auth can-i delete namespaces  --as=$SA               # → no (cluster-scoped)
   kubectl auth can-i create deployments --as=$SA -n default     # → no (wrong namespace)
   kubectl auth can-i '*' '*'            --as=$SA -n team-apps   # → no (not admin)
   ```

9. **Do a real impersonated action** to confirm the grant works end-to-end — and that a forbidden one is
   actually blocked, not just reported:

   ```bash
   kubectl create deployment web --image=nginx -n team-apps \
     --as=system:serviceaccount:team-apps:cicd-deployer
   kubectl get deploy -n team-apps
   kubectl get secrets -n team-apps \
     --as=system:serviceaccount:team-apps:cicd-deployer          # → Forbidden
   ```

   The deploy succeeds; the Secrets read is rejected with a clear `Forbidden`. Record your granted/denied
   results as the second half of your deliverable:

   ```text
   action                          namespace    expected   actual
   create deployments              team-apps    yes
   get secrets                     team-apps    no
   delete namespaces               (cluster)    no
   create deployments              default      no
   ```

## Expected result

Two artifacts:

- An **RBAC finding list** (`rbac-findings.txt`) naming wildcard roles, `cluster-admin` holders, and any
  cluster-wide ServiceAccount — including your manufactured `default/risky` finding, seen and removed.
- A **least-privilege CI ServiceAccount** that deploys into `team-apps` and nothing more, proven with an
  `auth can-i` table (granted *and* denied) and one real `Forbidden`.

You're done when someone who never saw your cluster could read the finding list and the proof table and
know *what was over-permissioned* and *exactly what the CI identity can and cannot do*.

## Cleanup

> Always tear down local clusters so they stop holding memory.

```bash
kubectl delete -f cicd-serviceaccount.yaml --ignore-not-found
kubectl delete -f aggregated-clusterrole.yaml --ignore-not-found
kubectl delete clusterrole app-team-manage-ingress --ignore-not-found
kind delete cluster --name pe-rbac-audit
rm -f rbac-findings.txt
```

## Reflection

- Which of the three audit findings would do the most damage if left in place, and why? Rank by blast
  radius, not by count.
- `auth can-i --list --as=…` versus reading Role YAML: why is asking the authorizer the only honest way to
  know a subject's permissions?
- The CI Role has no `secrets` and no `delete`. If this token leaks, what exactly is the attacker *unable*
  to do — and how does that bound the incident?
- Adding `app-team-manage-ingress` grew the aggregate with no edit to `app-team-admin`. How does that change
  who has to review a capability change?

## Stretch goals (optional)

- Run [KubiScan](https://github.com/cyberark/KubiScan) against the cluster and compare its "risky" findings
  with your `jq` audit — what does each catch that the other misses?
- Enable API server **audit logging** on a fresh kind cluster via a `kind` config that mounts an
  `--audit-policy-file` and `--audit-log-path`, then make an RBAC change and find it in the log.
- Write a **time-boxed JIT binding**: grant a subject a Role via a RoleBinding, then delete the binding
  after a timer (`sleep 300 && kubectl delete rolebinding …`) and re-prove with `auth can-i` that the
  access is gone.
