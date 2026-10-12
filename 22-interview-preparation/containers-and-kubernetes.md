# Interview Prep — Containers and Kubernetes

> This domain tests whether you understand what actually happens beneath
> `kubectl` — how containers isolate, how the control plane turns a manifest into
> running pods, and how to debug when it breaks. Interviewers probe for mental
> models (the reconciliation loop, probes, requests and limits), not memorized
> flags. Practice explaining each mechanism out loud before reading the answer.

## Containers

### Q: How does a container differ from a VM?

**What they're really asking:** Do you understand the shared-kernel model and its isolation trade-off?

A VM virtualizes **hardware**: a hypervisor runs a full guest OS with its own
kernel. Strong isolation, but heavy — gigabytes, seconds to boot. A container
virtualizes the **operating system**: it shares the host kernel and is isolated by
kernel features (namespaces and cgroups). Lightweight — megabytes, milliseconds to
start — but the shared kernel is a weaker security boundary.

- Containers package an app and its userspace dependencies, not a kernel.
- For untrusted or hostile workloads, close the gap with microVMs (Firecracker) or sandboxed runtimes (gVisor, Kata).

**Going deeper:** [02.1 · Container Fundamentals](../02-containerization/01-container-fundamentals/)

**Red flags:** "A container is a lightweight VM." Missing that containers share the host kernel.

### Q: What actually isolates a container?

**What they're really asking:** Can you name the kernel primitives, not just say "Docker does it"?

There is no single "container" object in the kernel — it is a process wrapped in
several isolation features:

- **Namespaces** scope what a process can *see*: PID, network, mount, UTS, IPC, and user namespaces give it its own process tree, interfaces, and filesystem view.
- **cgroups** limit what it can *use*: CPU, memory, I/O, and PIDs.
- **Capabilities, seccomp, and LSMs** (AppArmor/SELinux) restrict what it can *do*: drop root powers, filter syscalls, and confine access.

It is still the host kernel underneath, which is why kernel hardening matters.

**Going deeper:** [02.1 · Container Fundamentals](../02-containerization/01-container-fundamentals/) and [02.5 · Container Security](../02-containerization/05-container-security/)

### Q: What makes a good production container image?

**What they're really asking:** Do you build lean, secure, reproducible images?

- **Multi-stage build** so compilers and build dependencies never reach the final image.
- **Minimal base** (distroless or slim) to shrink attack surface and size.
- **Non-root `USER`** and a read-only root filesystem where possible.
- **Pinned base image by digest** and no secrets baked into layers (layers are cacheable and extractable).
- **Scanned** for CVEs in CI and ideally **signed** so consumers can verify provenance.

**Going deeper:** [02.2 · Dockerfile and Image Building](../02-containerization/02-dockerfile-and-image-building/) and [02.7 · Multi-Stage Builds and Optimization](../02-containerization/07-multi-stage-builds-and-optimization/)

**Red flags:** `latest` tags, running as root, secrets in `ENV`, or a 2 GB image built from a full OS base.

## Control plane and controllers

### Q: What happens when you run `kubectl apply` on a Deployment?

**What they're really asking:** Do you know the end-to-end path through the control plane?

1. `kubectl` sends the manifest to the **API server**, which authenticates you, runs **RBAC** authorization, then passes it through **mutating and validating admission** controllers.
2. The validated object is persisted to **etcd** — the only component that writes there.
3. The **Deployment controller** (in kube-controller-manager) sees the new object via a watch and creates a **ReplicaSet**; the ReplicaSet controller creates **Pod** objects to meet the replica count.
4. The **scheduler** filters and scores nodes and binds each Pod to one.
5. The **kubelet** on that node pulls the image via the container runtime (containerd/CRI), starts the container, and reports status; the **CNI** wires pod networking and EndpointSlices update if a Service selects it.

The theme: you declared desired state; independent controllers reconciled reality to match it.

**Going deeper:** [03.1 · Kubernetes Architecture](../03-kubernetes-fundamentals/01-kubernetes-architecture/) and [03.2 · Workloads](../03-kubernetes-fundamentals/02-workloads/)

**Red flags:** "kubectl creates the pods." Missing the API server, controllers, scheduler, and kubelet division of labor.

### Q: What is a Kubernetes controller and the reconciliation loop?

**What they're really asking:** Do you understand the pattern that underpins Kubernetes (and GitOps and Crossplane)?

A controller is a loop that watches **desired state** (an object's `spec`) and the
**observed state** (`status`), computes the difference, and takes action to converge
them — then repeats forever. It is **level-triggered**, not edge-triggered: it acts
on the current state, not on a one-time event, so it is self-healing and idempotent.
Delete a pod a ReplicaSet owns and the controller notices the gap and makes another.

- This is the same pattern as an ArgoCD sync and a Crossplane claim: declare intent, let a loop reconcile.
- Custom controllers (operators) extend it to your own resources via CRDs.

**Going deeper:** [03.1 · Kubernetes Architecture](../03-kubernetes-fundamentals/01-kubernetes-architecture/) and [10.2 · Kubernetes Operators](../10-kubernetes-advanced/02-kubernetes-operators/)

### Q: What is the difference between a Deployment, StatefulSet, and DaemonSet?

**What they're really asking:** Can you match a workload controller to a workload shape?

- **Deployment** — stateless, interchangeable replicas with rolling updates. The default for web services and APIs.
- **StatefulSet** — stable network identity and stable per-pod storage, with ordered, predictable rollout. For databases, brokers, and anything that needs sticky identity.
- **DaemonSet** — exactly one pod per (matching) node. For node-level agents: log shippers, the CNI, node exporters, CSI drivers.

**Going deeper:** [03.2 · Workloads](../03-kubernetes-fundamentals/02-workloads/)

## Networking and services

### Q: How does Kubernetes networking work at the pod level?

**What they're really asking:** Do you know the flat-network model (deep dive lives in the networking bank)?

The model is one rule: **every pod gets its own IP and can reach every other pod
directly, with no NAT**, as if on one flat network. Within a pod, containers share
the network namespace and talk over `localhost`. The **CNI plugin** is responsible
for making that flat network real — wiring each pod's interface and routing pod IPs
across nodes.

**Going deeper:** [03.3 · Services and Networking](../03-kubernetes-fundamentals/03-services-and-networking/) and [14 · Kubernetes Networking](../14-kubernetes-networking/)

### Q: How does traffic actually reach a pod behind a Service?

**What they're really asking:** Do you understand that a ClusterIP is virtual and gets DNAT'd?

A Service's ClusterIP is a **stable virtual IP** with no interface behind it.
**CoreDNS** resolves the Service name to that ClusterIP. A node-level component —
classically **kube-proxy** programming `iptables`/`IPVS`, or **eBPF** with Cilium —
then **DNATs** the Service IP to one of the healthy backing pod IPs listed in the
Service's **EndpointSlices**. So the name gives you a stable address, and the kernel
load-balances each connection to a real pod.

**Going deeper:** [03.3 · Services and Networking](../03-kubernetes-fundamentals/03-services-and-networking/)

## Running workloads reliably

### Q: What is the difference between a liveness, readiness, and startup probe?

**What they're really asking:** Do you know which probe does what, and the classic misconfiguration?

- **Liveness** — "is the container wedged?" On failure the kubelet **restarts** it. For deadlocks only.
- **Readiness** — "can it serve traffic right now?" On failure the pod is **removed from Service endpoints** (no traffic) but **not** restarted. For warm-up and dependency checks.
- **Startup** — for slow starters; it **gates** liveness/readiness until the app has booted, so a long startup is not mistaken for a hang and killed.

The classic mistake: a **liveness** probe that checks a downstream dependency (a database). When the dependency blips, every replica fails liveness and restarts together — turning a small issue into an outage. Keep liveness local and cheap; put dependency checks in readiness.

**Going deeper:** [03.8 · Health and Scheduling](../03-kubernetes-fundamentals/08-health-and-scheduling/)

**Red flags:** Using liveness to check dependencies, or no readiness probe so traffic hits pods before they are ready.

### Q: How do you debug a pod stuck in CrashLoopBackOff?

**What they're really asking:** Do you have a systematic method, not random guessing?

`CrashLoopBackOff` means the container keeps **exiting** and the kubelet is backing
off between restarts (exponential, capped at five minutes). It is a symptom; find
the exit cause:

- `kubectl describe pod` — events, exit code, last state, and reason.
- `kubectl logs --previous` — the crashed container's own logs (the most important step).
- Read the **exit code**: `137` is SIGKILL (often OOMKilled or a failed liveness probe), `139` is a segfault, non-zero generally means the app errored.
- Check config: missing env var, bad ConfigMap/Secret mount, wrong command/entrypoint, missing migration, or a dependency it cannot reach.
- Rule out a too-aggressive **liveness** probe and a too-low **memory limit**.

Distinguish from `ImagePullBackOff`, which is a *pull* problem — wrong tag, private registry, or missing credentials — not a crash.

**Going deeper:** [03.9 · Debugging and Troubleshooting](../03-kubernetes-fundamentals/09-debugging-and-troubleshooting/)

**Red flags:** Jumping to "delete the pod" without reading logs or the exit code.

### Q: What are resource requests and limits, QoS classes, and OOMKilled?

**What they're really asking:** Do you understand scheduling, throttling, and eviction?

- **Request** — the amount the scheduler reserves to place the pod; it is the guaranteed floor.
- **Limit** — the hard ceiling. Over the **CPU** limit the container is **throttled**; over the **memory** limit it is **OOMKilled** (exit 137), because memory is incompressible.
- **QoS classes** derive from these: **Guaranteed** (requests equal limits for every container), **Burstable** (some requests set), **BestEffort** (none). Under node memory pressure the kubelet evicts **BestEffort** first, then **Burstable**, protecting **Guaranteed**.

Set memory request close to limit for predictability; be cautious with CPU limits, which can cause latency through throttling.

**Going deeper:** [03.7 · Resource Management](../03-kubernetes-fundamentals/07-resource-management/)

### Q: How does a rolling update work, and how do you roll back?

**What they're really asking:** Do you know how Deployments ship changes safely?

Updating a Deployment's pod template creates a **new ReplicaSet**. The Deployment
controller scales the new one up and the old one down gradually, bounded by
**`maxSurge`** (how many extra pods above desired) and **`maxUnavailable`** (how many
can be missing). **Readiness probes gate progress** — a new pod must become Ready
before the rollout continues — so a broken image stalls instead of taking down the
service. The old ReplicaSet is retained, so `kubectl rollout undo` scales the
previous revision back up.

- Use `kubectl rollout status` to watch and `kubectl rollout undo` to revert.
- For richer strategies (canary, blue-green), reach for Argo Rollouts or a service mesh.

**Going deeper:** [03.2 · Workloads](../03-kubernetes-fundamentals/02-workloads/)

**Red flags:** No readiness probe (so rollouts "succeed" into a broken state), or thinking a rolling update edits pods in place.
