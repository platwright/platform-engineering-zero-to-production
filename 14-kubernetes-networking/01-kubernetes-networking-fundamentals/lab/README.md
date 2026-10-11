# Lab — Trace a request from pod to Service to pod

> You'll follow a single request through the whole Kubernetes networking stack on a
> local two-node cluster: DNS resolves the name, the Service lists real pods as
> EndpointSlices, and an iptables DNAT rule rewrites the ClusterIP to a pod IP. Then
> you'll break DNS to feel the difference between a *name* problem and a *routing*
> problem. All local and free.

**Estimated time:** ~40–60 minutes
**Type:** Discovery / debug
**Deliverable:** Notes showing the DNS answer, the EndpointSlice pod IPs, and the
iptables rule that rewrites the Service IP — plus what changed when DNS broke.

## Objectives

- Resolve a Service name and see it map to a ClusterIP.
- List the real pod IPs behind a Service (EndpointSlices).
- Find the kernel DNAT rule that implements the Service.
- Distinguish a DNS failure from a routing failure.

## Prerequisites

- Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/).
- Starter files here: [`kind-config.yaml`](./kind-config.yaml),
  [`frontend-backend.yaml`](./frontend-backend.yaml). No cost — all local.

## Steps

1. **Create a two-node cluster and deploy the apps.**

   ```bash
   kind create cluster --name netlab --config kind-config.yaml
   kubectl apply -f frontend-backend.yaml
   kubectl wait --for=condition=ready pod -l app=backend --timeout=90s
   kubectl wait --for=condition=ready pod/frontend --timeout=90s
   ```

2. **See the flat pod network.** List pod IPs and which node each is on — note the
   backend pods may be on different nodes, yet share one flat address space:

   ```bash
   kubectl get pods -o wide
   ```

3. **Resolve the Service name (DNS).** From the frontend pod:

   ```bash
   kubectl exec frontend -- nslookup backend
   # Returns the Service's ClusterIP, e.g. 10.96.x.x
   kubectl get svc backend          # confirm it matches
   ```

4. **List the real pods behind the Service (EndpointSlices).**

   ```bash
   kubectl get endpointslices -l kubernetes.io/service-name=backend -o wide
   # The addresses are the backend POD IPs — the Service load-balances across them.
   ```

5. **Make the request and prove it reaches a pod.**

   ```bash
   kubectl exec frontend -- curl -s -o /dev/null -w "%{http_code}\n" http://backend
   # 200 — name -> ClusterIP -> DNAT -> a real pod
   ```

6. **Find the DNAT rule that IS the Service.** Look at a node's NAT table:

   ```bash
   SVC_IP=$(kubectl get svc backend -o jsonpath='{.spec.clusterIP}')
   docker exec netlab-worker iptables -t nat -L KUBE-SERVICES -n | grep "$SVC_IP"
   # The matching rule jumps to a chain that DNATs the ClusterIP to a pod IP.
   ```

   > On a Cilium cluster this rule wouldn't exist — eBPF does the same job
   > (Module 14.4). On kind's default CNI, kube-proxy wrote this rule.

7. **Watch endpoints update when a pod dies.**

   ```bash
   kubectl delete pod -l app=backend --field-selector 'status.phase=Running' --wait=false
   kubectl get endpointslices -l kubernetes.io/service-name=backend -o wide -w
   # Ctrl-C after you see the address set change — the Service self-heals its backends.
   ```

8. **Break DNS to tell a name problem from a routing problem.** Curl a *pod IP*
   directly (works) versus a bogus *name* (fails at resolution):

   ```bash
   POD_IP=$(kubectl get pod -l app=backend -o jsonpath='{.items[0].status.podIP}')
   kubectl exec frontend -- curl -s -o /dev/null -w "%{http_code}\n" http://$POD_IP:8080  # 200 (routing fine)
   kubectl exec frontend -- curl -s http://backendd 2>&1 | head -1                         # name fails to resolve
   ```

   The pod IP working while the name fails is the signature of a **DNS** problem, not a
   network problem — the single most useful discrimination in networking incidents.

## Expected result

- `nslookup backend` returns the ClusterIP; `kubectl get svc` matches it.
- EndpointSlices list the backend pod IPs, and they change when a pod is replaced.
- An iptables rule in `KUBE-SERVICES` matches the ClusterIP.
- Curling the pod IP succeeds while a bad *name* fails — localizing faults to DNS vs
  routing.

## Cleanup

```bash
kind delete cluster --name netlab
```

## Reflection

- You found the Service's behavior encoded as an **iptables rule**. What breaks about
  that approach when a cluster has tens of thousands of Services (Module 14.4)?
- Step 8 is the highest-value debugging reflex in this whole phase. Why does testing
  the name *and* the IP instantly cut the problem space in half?
- The backend pods may have been on different nodes, yet the frontend reached them the
  same way. Which networking-model requirement made that true?

## Stretch goals (optional)

- Inspect the veth/bridge plumbing on a node:
  `docker exec netlab-worker ip link` and look for `veth*` and the bridge.
- Deploy a **headless** Service (`clusterIP: None`) for the backend and compare what
  `nslookup backend` returns (pod IPs directly, not a ClusterIP).
