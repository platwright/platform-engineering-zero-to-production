# Module 03.7 — Resource Management

> A Kubernetes cluster is a shared pool of CPU and memory. **Requests** tell the
> scheduler how much to reserve; **limits** tell the kernel the ceiling to enforce.
> Get them wrong and you either waste money or cause outages. This module covers
> requests, limits, QoS, namespace guardrails (LimitRange, ResourceQuota), and the
> autoscalers that grow workloads and nodes on demand.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 03.2](../02-workloads/) and a working `kubectl` +
[kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain the difference between a **request** (scheduling reservation) and a
  **limit** (runtime ceiling), for CPU and memory.
- Predict a Pod's **QoS class** (Guaranteed, Burstable, BestEffort) from its
  requests/limits.
- Use **LimitRange** and **ResourceQuota** to make a namespace fair and bounded.
- Choose the right autoscaler: **HPA** (replicas), **VPA** (size), **KEDA**
  (events), **Cluster Autoscaler / Karpenter** (nodes).
- Diagnose CPU **throttling** vs memory **OOMKilled**.

---

## 1. Concept

### Requests: what the scheduler reserves

A **request** is the amount of CPU/memory a container is *guaranteed*. The
**scheduler** uses requests (not actual usage) to place Pods: it finds a node with
enough **unreserved** capacity to satisfy the request and reserves it. A node with
4 CPU can hold Pods whose requests sum to 4 CPU — even if they're mostly idle. Set
requests too high and you bin-pack poorly and waste money; too low and nodes get
oversubscribed and workloads fight.

### Limits: what the kernel enforces

A **limit** is the ceiling a container may use at runtime, enforced by the Linux
kernel (cgroups) on the node. The two resources behave very differently at the limit:

- **CPU is compressible.** Exceed the CPU limit and the container is **throttled** —
  slowed down, not killed. Symptom: latency, not crashes.
- **Memory is incompressible.** Exceed the memory limit and the kernel **OOMKills**
  the container; Kubernetes restarts it (and you see `OOMKilled`). Symptom: crashes.

This asymmetry is why memory limits must be sized carefully (too low = crash loops)
while CPU limits are often looser or omitted.

### Quality of Service classes

From the relationship between requests and limits, Kubernetes assigns each Pod a
**QoS class** that decides who gets evicted first when a node runs out of memory:

- **Guaranteed** — every container sets requests **equal to** limits for both CPU and
  memory. Highest priority; evicted last. Use for critical workloads.
- **Burstable** — has requests but requests < limits (or only some set). Can use spare
  capacity but may be throttled/evicted under pressure.
- **BestEffort** — no requests or limits at all. First to be evicted under memory
  pressure. Fine for throwaway jobs, dangerous for anything important.

```text
   requests == limits (both)      → Guaranteed   (evicted last)
   some requests, requests<limits → Burstable    (evicted in the middle)
   no requests, no limits         → BestEffort   (evicted first)
```

### Namespace guardrails: LimitRange and ResourceQuota

In a multi-team cluster you can't trust every manifest to set sane resources. Two
namespace-scoped objects enforce fairness:

- **LimitRange** — applies **per-Pod/container** defaults and bounds: a default
  request/limit for containers that omit them, and min/max allowed values. It stops
  "no resources set" (BestEffort surprises) and "one Pod asks for 64 CPU."
- **ResourceQuota** — caps the **namespace total**: the sum of all requests/limits,
  and counts of objects (Pods, Services, PVCs). It stops one team from consuming the
  whole cluster. With a quota in place, **every** Pod must declare resources or it's
  rejected — which is why LimitRange defaults pair naturally with quotas.

### Autoscaling: four different knobs

"Scale" can mean four distinct things; know which one you need:

- **Horizontal Pod Autoscaler (HPA)** — adds/removes **replicas** of a workload based
  on CPU, memory, or custom metrics. The everyday autoscaler for stateless services.
  Needs a metrics source (metrics-server).
- **Vertical Pod Autoscaler (VPA)** — adjusts a workload's **requests/limits** to
  right-size it. Great for picking good numbers; don't run it in aggressive mode on
  the same target as an HPA on the same metric.
- **KEDA** — **event-driven** autoscaling: scale on queue depth, Pub/Sub backlog,
  Kafka lag, or a cron schedule — including **scale-to-zero**. For workers and
  consumers where CPU isn't the real signal.
- **Cluster Autoscaler / Karpenter** — scale the **nodes** themselves. When Pods are
  `Pending` for lack of capacity, these add nodes (and remove underused ones).
  Karpenter provisions right-sized nodes just-in-time. HPA adds Pods; these add the
  machines to run them.

---

## 2. Why it matters for platform engineering

- **This is where cost and reliability meet.** Requests drive how densely you pack
  nodes (the bill); limits and QoS drive what survives under pressure (the outages).
  Tuning them well is one of the highest-leverage things a platform team does.
- **Guardrails enable safe multi-tenancy.** LimitRange + ResourceQuota let you hand a
  namespace to a team knowing they can't starve the cluster or ship resource-less
  Pods. You set these defaults as part of the paved road.
- **Autoscaling is a platform capability you operate.** Teams want "it scales with
  load" without learning HPA/KEDA/Karpenter internals. You provide and tune the
  autoscaling stack and the metrics behind it.
- **Most incidents trace back here.** `OOMKilled` crash loops, CPU throttling
  latency, and `Pending` Pods for insufficient resources are daily occurrences —
  and all are resource-management problems.

---

## 3. Mental model

Separate the two numbers completely: **request = a reservation the scheduler
honors; limit = a ceiling the kernel enforces.**

```text
   NODE (4 CPU, 8Gi)                         AT RUNTIME on the node
   ┌───────────────────────────────┐         CPU over limit  → THROTTLED (slow)
   │ reserved by requests:          │         Mem over limit  → OOMKILLED (restart)
   │  ┌─────┐ ┌─────┐ ┌─────┐       │
   │  │req  │ │req  │ │req  │  free  │         QoS decides eviction order:
   │  │1CPU │ │1CPU │ │0.5  │ (1.5)  │           Guaranteed  evicted LAST
   │  └─────┘ └─────┘ └─────┘       │           Burstable   middle
   │ scheduler packs by REQUESTS,   │           BestEffort  evicted FIRST
   │ not by actual usage            │
   └───────────────────────────────┘

   Scale out → HPA (more Pods) → Pods Pending? → Cluster Autoscaler/Karpenter (more nodes)
   Scale up  → VPA (bigger requests/limits)     Scale on events → KEDA (queue/cron, to zero)
```

Rules to remember:

1. **Scheduler reserves by requests; kernel enforces limits.** Two different numbers,
   two different jobs.
2. **CPU throttles, memory kills.** Size memory limits with care.
3. **Requests == limits → Guaranteed.** QoS decides who dies first under pressure.

---

## 4. Minimal implementation

See QoS fall out of requests/limits, then watch a memory limit do its job. A
Guaranteed Pod (requests == limits):

```bash
kubectl run guaranteed --image=nginx --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"c","image":"nginx","resources":{"requests":{"cpu":"100m","memory":"64Mi"},"limits":{"cpu":"100m","memory":"64Mi"}}}]}}'
kubectl get pod guaranteed -o jsonpath='{.status.qosClass}{"\n"}'   # Guaranteed
```

Now prove memory is incompressible — give a tiny limit and allocate past it:

```bash
kubectl run hungry --image=polinux/stress --restart=Never \
  --overrides='{"spec":{"containers":[{"name":"c","image":"polinux/stress","resources":{"limits":{"memory":"64Mi"}},"command":["stress","--vm","1","--vm-bytes","200M","--vm-hang","1"]}]}}'
kubectl get pod hungry -w        # watch it go OOMKilled, then CrashLoopBackOff
kubectl describe pod hungry | grep -A2 'Last State'   # Reason: OOMKilled
```

The container asked for 200M against a 64Mi ceiling, so the kernel killed it. A CPU
overshoot, by contrast, would merely throttle. That difference drives every
resource-sizing decision.

---

## 5. Hands-on lab

You'll put **LimitRange** defaults and a **ResourceQuota** on a namespace (and watch a
resource-less Pod get rejected), then install metrics-server, autoscale a Deployment
with an **HPA**, and drive real CPU load to watch it scale out and back in. Local kind
cluster only.

➡️ **[Start the lab: Quotas and autoscaling under load](./lab/README.md)**

---

## 6. Production considerations

- **Right-size from real data.** Set requests near the workload's typical usage (use
  VPA recommendations or historical metrics), not round guesses. Over-requesting is
  the top source of silent cloud waste.
- **Set memory requests == limits for critical services.** Guaranteed QoS plus a
  correct memory limit avoids both OOMKills and surprise evictions.
- **Be cautious with CPU limits.** Tight CPU limits throttle and add latency; many
  teams set CPU *requests* for scheduling and leave limits generous or unset for
  latency-sensitive services.
- **Pair quotas with LimitRange defaults.** A ResourceQuota requires every Pod to
  declare resources; without LimitRange defaults, teams' resource-less manifests get
  rejected and they'll be confused. Ship both together.
- **Make HPA and node autoscaling work together.** HPA adds Pods; ensure Cluster
  Autoscaler/Karpenter can add nodes, or scaled-out Pods sit `Pending`. Set sane
  min/max and stabilization windows to avoid flapping.
- **Use KEDA for event-driven and bursty work** (queues, batch) where CPU is a poor
  proxy — and to scale to zero when idle to save money.

---

## 7. Common mistakes

- **No requests/limits at all.** — Pods become BestEffort, get scheduled onto crowded
  nodes, and are first evicted under pressure. *Fix:* set requests/limits (and
  enforce via LimitRange + ResourceQuota).
- **Memory limit set too low.** — The app OOMKills and crash-loops under normal load.
  *Fix:* size memory limits from observed peak usage with headroom; alert on
  `OOMKilled`.
- **Aggressive CPU limits on latency-sensitive services.** — Throttling adds tail
  latency that looks like a mysterious slowdown. *Fix:* loosen or drop CPU limits;
  rely on requests for fair scheduling.
- **HPA with no metrics-server (or no requests).** — The HPA shows `<unknown>` targets
  and never scales, because utilization is a percentage of the **request**. *Fix:*
  install metrics-server and always set CPU requests on HPA targets.
- **Quota without defaults.** — Every resource-less Pod is suddenly rejected and teams
  are blocked. *Fix:* add a LimitRange with sensible default requests/limits.

---

## 8. Assessment

**Knowledge checks**

1. What does the scheduler actually use to place a Pod — its request or its real
   usage? Why does that matter for cost?
2. What happens when a container exceeds its CPU limit? Its memory limit? Why the
   difference?
3. How is a Pod's QoS class determined, and what is QoS used for?
4. What problem does a ResourceQuota solve, and why does it usually need a LimitRange
   alongside it?
5. Match the autoscaler to the job: more replicas on CPU; bigger requests; scale on
   queue depth; more nodes.

**Concept exercise**

> Explain how one team's runaway workload is prevented from starving every other team
> on a shared cluster — **without using the words "ResourceQuota," "LimitRange," or
> "request."** Describe the reservation-and-budget idea in your own words.

**Trade-off / debugging exercise**

> A service is intermittently slow but never crashes; another crashes every few
> minutes with `OOMKilled`. Both have identical traffic. From resource management
> alone, what's the most likely cause of each, and what would you change?

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** The scheduler reserves capacity by **requests**, not live usage. Requests
  set too high bin-pack poorly and waste money; too low oversubscribe nodes.
- **Q2:** Over the CPU limit → **throttled** (slowed), because CPU is compressible.
  Over the memory limit → **OOMKilled** (and restarted), because memory can't be
  reclaimed from the process.
- **Q3:** From requests vs limits: equal for both → Guaranteed; some set → Burstable;
  none → BestEffort. QoS sets eviction order under node memory pressure (BestEffort
  first, Guaranteed last).
- **Q4:** A ResourceQuota caps a namespace's total resource use and object counts so
  one team can't consume the cluster. It makes resource declarations mandatory, so a
  LimitRange supplies defaults for Pods that omit them (otherwise they're rejected).
- **Q5:** More replicas on CPU → HPA; bigger requests → VPA; queue depth → KEDA; more
  nodes → Cluster Autoscaler / Karpenter.
- **Debugging exercise:** The slow-but-stable service is almost certainly **CPU
  throttled** (limit too low) — raise or remove the CPU limit, check throttling
  metrics. The crashing service is **OOMKilled** (memory limit too low or a leak) —
  raise the memory limit to cover peak usage and investigate growth; confirm via
  `kubectl describe pod` → `Last State: OOMKilled`.

</details>

---

## 9. Further reading

- Kubernetes — [Resource Management for Pods and Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- Kubernetes — [Quality of Service for Pods](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/)
- Kubernetes — [Resource Quotas](https://kubernetes.io/docs/concepts/policy/resource-quotas/) and [Limit Ranges](https://kubernetes.io/docs/concepts/policy/limit-range/)
- Kubernetes — [Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
- KEDA — [Documentation](https://keda.sh/docs/latest/) · Karpenter — [Documentation](https://karpenter.sh/docs/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 03.6 — RBAC](../06-rbac/)
· _Next:_ [Module 03.8 — Health, Probes and Scheduling →](../08-health-and-scheduling/)
