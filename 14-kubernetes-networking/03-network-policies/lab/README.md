# Lab — Lock a namespace to default-deny

> You'll take an open namespace, apply **default-deny**, watch it break (including the
> classic DNS outage), then open exactly the flows that are needed: `frontend →
> backend` plus DNS. You'll prove an "attacker" pod can reach the backend *before* the
> policy and is blocked *after* — the essence of blast-radius containment. All local
> and free (on a policy-capable CNI).

**Estimated time:** ~45–60 minutes
**Type:** Build / security
**Deliverable:** Notes showing the before/after: attacker reaches backend when open,
is denied under default-deny, and only `frontend → backend` (plus DNS) works after the
allow policies.

## Objectives

- Prove namespaces don't isolate network traffic by default.
- Apply default-deny and observe it (including the DNS trap).
- Allow exactly the intended flows and verify everything else stays blocked.

## Prerequisites

- Docker, `kubectl`, [kind](https://kind.sigs.k8s.io/). No cost — all local.
- A **NetworkPolicy-enforcing CNI.** kind's default (kindnet) does **not** enforce
  policy, so this lab installs **Calico** (Module 14.2). If you skip that, the policies
  apply but nothing is blocked — which is itself an instructive failure.
- Starter files here: [`workloads.yaml`](./workloads.yaml),
  [`default-deny.yaml`](./default-deny.yaml), [`allow-dns.yaml`](./allow-dns.yaml),
  [`allow-frontend.yaml`](./allow-frontend.yaml).

## Steps

1. **Create a cluster without the default CNI, then install Calico** (so policy is
   actually enforced):

   ```bash
   cat > /tmp/np-kind.yaml <<'EOF'
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   networking:
     disableDefaultCNI: true
     podSubnet: "192.168.0.0/16"
   EOF
   kind create cluster --name np-lab --config /tmp/np-kind.yaml

   kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml
   kubectl -n kube-system rollout status deploy/calico-kube-controllers --timeout=180s
   kubectl wait --for=condition=ready node --all --timeout=180s
   ```

2. **Deploy the workloads** (frontend, backend, and an attacker pod, all in `team-a`):

   ```bash
   kubectl apply -f workloads.yaml
   kubectl -n team-a wait --for=condition=ready pod --all --timeout=120s
   ```

3. **Prove the namespace is wide open.** Both frontend *and* the attacker can reach the
   backend — nothing isolates them yet:

   ```bash
   kubectl -n team-a exec frontend -- curl -s -m 3 -o /dev/null -w "frontend->backend: %{http_code}\n" http://backend
   kubectl -n team-a exec attacker -- curl -s -m 3 -o /dev/null -w "attacker->backend: %{http_code}\n" http://backend
   # both 200 — lateral movement is possible
   ```

4. **Apply default-deny and watch everything break — including DNS:**

   ```bash
   kubectl apply -f default-deny.yaml
   kubectl -n team-a exec frontend -- sh -c 'nslookup backend 2>&1 | head -2'   # DNS now FAILS
   kubectl -n team-a exec frontend -- curl -s -m 3 http://backend || echo "frontend->backend: denied"
   kubectl -n team-a exec attacker -- curl -s -m 3 http://backend || echo "attacker->backend: denied"
   ```

   Note the DNS failure — default-deny egress cut off CoreDNS. This is the trap.

5. **Restore DNS** with the egress allow, and confirm names resolve again (but traffic
   is still denied):

   ```bash
   kubectl apply -f allow-dns.yaml
   kubectl -n team-a exec frontend -- sh -c 'nslookup backend 2>&1 | head -2'   # resolves now
   kubectl -n team-a exec frontend -- curl -s -m 3 http://backend || echo "still denied (no app policy yet)"
   ```

6. **Open exactly `frontend → backend`** and verify isolation holds for everyone else:

   ```bash
   kubectl apply -f allow-frontend.yaml
   kubectl -n team-a exec frontend -- curl -s -m 3 -o /dev/null -w "frontend->backend: %{http_code}\n" http://backend  # 200
   kubectl -n team-a exec attacker -- curl -s -m 3 http://backend || echo "attacker->backend: DENIED (contained)"
   ```

   The attacker is now blocked while the intended flow works. You've contained the
   blast radius to exactly the allowed path.

## Expected result

- **Before policy:** both frontend and attacker reach the backend (200).
- **After default-deny:** DNS fails and all traffic is denied.
- **After allow-dns:** names resolve, but app traffic is still denied.
- **After allow-frontend:** `frontend → backend` works; `attacker → backend` is denied.

## Cleanup

```bash
kind delete cluster --name np-lab
rm -f /tmp/np-kind.yaml
```

## Reflection

- Namespaces gave `team-a` naming and RBAC isolation, but the attacker still reached
  the backend until you added NetworkPolicy. Why is network isolation a *separate*
  control?
- Step 4's DNS failure is the most common default-deny incident. What would you put in
  a namespace template so no team ever hits it?
- The attacker pod is in the *same* namespace as the backend and was still blocked.
  How would you also block a pod in a *different* namespace (hint: `namespaceSelector`)?

## Stretch goals (optional)

- Add an egress policy allowing the backend to reach an external CIDR, and prove other
  external destinations are blocked (the `ipBlock` selector).
- Try to express "allow egress only to `api.github.com`" with vanilla NetworkPolicy —
  and note why you can't (no FQDN). This motivates Cilium (Module 14.4).
- Enforce default-deny with a Kyverno policy (Module 13.3) that requires every
  namespace to have a `default-deny-all` NetworkPolicy.
