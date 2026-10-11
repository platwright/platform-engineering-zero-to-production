# Lab — See and shape traffic with Cilium + Hubble

> You'll install Cilium (with Hubble) on a local cluster, *watch* network flows in real
> time, then apply an **L7** policy that allows `GET /` but drops other HTTP methods —
> and see Hubble report each verdict with the HTTP detail. This is the capability (and
> visibility) that vanilla NetworkPolicy can't give you. All local and free.

**Estimated time:** ~50–70 minutes
**Type:** Build / observability
**Deliverable:** Hubble output showing an allowed `GET` and a dropped non-GET to the
same backend, under one L7 CiliumNetworkPolicy.

## Objectives

- Install Cilium as the CNI with Hubble enabled.
- Observe allowed and dropped flows in real time.
- Enforce an L7 (HTTP-method) policy and verify it with Hubble.

## Prerequisites

- Docker, `kubectl`, [kind](https://kind.sigs.k8s.io/), and the
  [Cilium CLI](https://docs.cilium.io/en/stable/gettingstarted/k8s-install-default/#install-the-cilium-cli).
  No cost — all local.
- Starter file here: [`l7-policy.yaml`](./l7-policy.yaml). The workloads reuse
  [`../../03-network-policies/lab/workloads.yaml`](../../03-network-policies/lab/workloads.yaml).

## Steps

1. **Create a cluster without a default CNI, then install Cilium + Hubble:**

   ```bash
   cat > /tmp/cilium-kind.yaml <<'EOF'
   kind: Cluster
   apiVersion: kind.x-k8s.io/v1alpha4
   networking:
     disableDefaultCNI: true
     kubeProxyMode: "none"
   nodes:
     - role: control-plane
     - role: worker
   EOF
   kind create cluster --name cilium-lab --config /tmp/cilium-kind.yaml

   cilium install --set kubeProxyReplacement=true
   cilium status --wait
   cilium hubble enable
   ```

2. **Deploy the workloads** (frontend, backend, attacker in `team-a`):

   ```bash
   kubectl apply -f ../../03-network-policies/lab/workloads.yaml
   kubectl -n team-a wait --for=condition=ready pod --all --timeout=120s
   ```

3. **Watch flows live with Hubble.** In a second terminal, port-forward Hubble and
   observe:

   ```bash
   cilium hubble port-forward &
   hubble observe --namespace team-a --follow
   ```

   In the first terminal, generate traffic and watch it appear as FORWARDED flows:

   ```bash
   kubectl -n team-a exec frontend -- curl -s -o /dev/null -w "%{http_code}\n" http://backend
   ```

4. **Apply the L7 policy** (allow only `GET /`):

   ```bash
   kubectl apply -f l7-policy.yaml
   ```

5. **Prove L7 enforcement — a GET is allowed, a DELETE is dropped**, to the *same* port
   on the *same* pod:

   ```bash
   kubectl -n team-a exec frontend -- curl -s -o /dev/null -w "GET: %{http_code}\n" http://backend/
   kubectl -n team-a exec frontend -- curl -s -o /dev/null -w "DELETE: %{http_code}\n" -X DELETE http://backend/
   # GET succeeds; DELETE is denied by L7 policy (403 / dropped)
   ```

6. **See the verdicts in Hubble** — note it shows the HTTP method and the L7 decision,
   not just "port 8080":

   ```bash
   hubble observe --namespace team-a --protocol http --last 20
   # You'll see GET ... FORWARDED and DELETE ... DROPPED (or 403), with the path.
   ```

   This is the whole point: a policy decision based on the **HTTP method**, and the
   **visibility** to confirm it — neither possible with vanilla NetworkPolicy.

## Expected result

- `cilium status` shows Cilium healthy with kube-proxy replacement.
- Hubble streams `team-a` flows live.
- Under the L7 policy, `GET /` is FORWARDED (200) and `DELETE /` is DROPPED/403 to the
  same backend, visible in Hubble with the HTTP method.

## Cleanup

```bash
# stop the background port-forward if still running:  kill %1  (or find it with: jobs)
kind delete cluster --name cilium-lab
rm -f /tmp/cilium-kind.yaml
```

## Reflection

- In Module 14.3 you could only guess whether a connection was blocked. How does Hubble
  change the debugging loop for a 40-team platform?
- The L7 policy distinguished GET from DELETE on the same port. Why is that impossible
  with vanilla NetworkPolicy, and when is it genuinely worth the extra proxy hop?
- Cilium replaced kube-proxy here (`kubeProxyMode: none`). What problem at scale does
  that solve (recall Module 14.1's iptables note)?

## Stretch goals (optional)

- Open the **Hubble UI** (`cilium hubble ui`) and watch the service map render flows
  and verdicts graphically.
- Add a `toFQDNs` egress rule allowing the backend to reach only one external hostname,
  and confirm other hostnames are blocked — the FQDN capability vanilla policy lacks.
