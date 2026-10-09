# Module 03.8 — Health, Probes and Scheduling

> Kubernetes can't see inside your container — it only knows what your **probes**
> tell it. And it can't place Pods well unless you express where they should (and
> shouldn't) go. This module covers both halves of keeping workloads healthy and
> correctly placed: liveness/readiness/startup probes, and the scheduling controls
> (affinity, taints, Pod Disruption Budgets, PriorityClasses) that decide *where*
> Pods run and *when* they're allowed to be disrupted.

**Estimated effort:** ~2.5–3 hours (theory + lab)
**You'll need:** [Module 03.2](../02-workloads/), [Module 03.3](../03-services-and-networking/),
and a working `kubectl` + [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Distinguish **liveness**, **readiness**, and **startup** probes and configure each
  correctly.
- Pick the right probe mechanism: HTTP, TCP, exec, or gRPC.
- Steer placement with **nodeSelector**, **node affinity**, and **pod
  (anti-)affinity**.
- Use **taints and tolerations** to reserve nodes, and **PriorityClasses** for
  preemption.
- Protect availability during node drains with a **PodDisruptionBudget**.

---

## 1. Concept

### Part A — Health probes: telling Kubernetes what "healthy" means

A running container is not the same as a *working* one. A process can be alive but
deadlocked, or started but not yet ready to serve. Kubernetes can only know your
app's real state if you expose it through **probes** — periodic checks the kubelet
runs against each container. There are three, with distinct jobs:

- **Liveness probe** — *"Is this container wedged? If so, restart it."* On failure,
  the kubelet **kills and restarts** the container. Use it to recover from
  deadlocks/hangs that a restart fixes. A bad liveness probe is dangerous: too
  aggressive and it restarts healthy containers in a loop.
- **Readiness probe** — *"Should this Pod receive traffic right now?"* On failure, the
  Pod is **removed from Service endpoints** ([Module 03.3](../03-services-and-networking/))
  but **not** restarted. Use it for warm-up, loss of a dependency, or temporary
  overload — the Pod stays up and silently stops receiving requests until it recovers.
- **Startup probe** — *"Has this slow app finished booting yet?"* While it's running,
  liveness and readiness are **held off**. Use it for apps with long or variable
  startup (JVMs, migrations) so a slow boot isn't mistaken for a hang and killed.

The crucial distinction: **liveness restarts; readiness de-routes.** Confusing them
causes outages — a readiness-style check wired to liveness will restart a Pod that
merely lost a dependency, turning a blip into a crash loop.

Each probe can use one of four **mechanisms**:

- **HTTP GET** — a 2xx/3xx on a path means healthy (most common for web apps).
- **TCP socket** — the port accepts a connection (for non-HTTP services).
- **exec** — a command inside the container exits `0` (flexible, heavier).
- **gRPC** — a native gRPC health check.

Key timing knobs: `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`,
`failureThreshold`, `successThreshold`. (Prefer a startup probe over a large
`initialDelaySeconds`.)

### Part B — Scheduling: deciding where Pods run

By default the scheduler places a Pod on any node with enough free requests
([Module 03.7](../07-resource-management/)). Often you need more control:

- **nodeSelector** — the simplest: schedule only onto nodes carrying a label
  (`disktype: ssd`). A hard match, nothing fancy.
- **Node affinity** — a richer nodeSelector with `required...` (hard: must match) and
  `preferred...` (soft: try to match, but schedule anyway). Lets you express "prefer
  GPU nodes, but run elsewhere if none."
- **Pod affinity / anti-affinity** — place a Pod relative to **other Pods**. Affinity
  co-locates ("run near the cache"); **anti-affinity** spreads ("don't put two
  replicas of me on the same node/zone"), which is how you survive a node failure.
- **Taints and tolerations** — the inverse of affinity. A **taint** on a node
  *repels* all Pods ("GPU nodes: keep off"); only Pods with a matching **toleration**
  may land there. Taints reserve nodes for specific workloads (GPU, special
  hardware); the control plane taints are why ordinary Pods don't run on control-plane
  nodes.
- **PriorityClass** — assigns a priority number to Pods. When the cluster is full, a
  higher-priority Pod can **preempt** (evict) lower-priority Pods to get scheduled.
  Reserve high priority for genuinely critical workloads.

### Part C — Protecting availability: PodDisruptionBudgets

Pods get disrupted two ways: **involuntary** (a node crashes — nothing to negotiate)
and **voluntary** (you drain a node for an upgrade, the autoscaler removes a node). A
**PodDisruptionBudget (PDB)** constrains *voluntary* disruptions: "keep at least
`minAvailable` replicas (or at most `maxUnavailable` down) at all times." When you
`kubectl drain` a node, Kubernetes evicts Pods **only as fast as the PDB allows**, so
a rolling node upgrade never takes your service below its floor. A PDB doesn't stop a
node from crashing — it stops *you* from accidentally taking too much down at once.

---

## 2. Why it matters for platform engineering

- **Probes are the contract for safe deploys and self-healing.** Readiness gates
  traffic during rollouts; liveness recovers hung Pods; startup protects slow
  boots. The platform's zero-downtime promise depends on teams wiring these
  correctly — so you template them and teach the liveness-vs-readiness distinction.
- **Placement is reliability and cost.** Anti-affinity spreads replicas so one node
  (or zone) failure doesn't take the whole service down. Taints reserve expensive
  hardware (GPUs) for the workloads that need it. These are platform-level guarantees
  you design.
- **PDBs make cluster maintenance safe.** You (or the autoscaler) will drain nodes
  constantly for upgrades and scaling. PDBs are what let that happen without paging
  anyone — a core operability feature of a multi-tenant platform.
- **PriorityClasses keep the platform itself alive.** Critical system components
  should preempt best-effort batch jobs under pressure, not the other way around.

---

## 3. Mental model

Two pictures. First, **which probe does what** when it fails:

```text
   LIVENESS fails   → kubelet KILLS + RESTARTS the container   (fix a hang)
   READINESS fails  → Pod removed from Service endpoints       (stop traffic, stay up)
   STARTUP running  → liveness/readiness are PAUSED            (let slow apps boot)
```

Second, the **scheduling forces** acting on a Pod:

```text
   PULL toward nodes            PUSH away from nodes
   ─────────────────            ────────────────────
   nodeSelector / affinity      taint (node repels) ── needs matching toleration to land
   pod affinity (co-locate)     pod anti-affinity (spread replicas apart)

   PriorityClass → higher priority can preempt lower when the cluster is full
   PodDisruptionBudget → caps how many replicas VOLUNTARY disruption may remove
```

Rules to remember:

1. **Liveness restarts, readiness de-routes, startup waits.** Never wire a dependency
   check to liveness.
2. **Affinity pulls, taints push.** A taint needs a matching toleration to be
   overcome.
3. **Anti-affinity + PDB = survives failures and upgrades.** Spread replicas, cap
   voluntary disruption.

---

## 4. Minimal implementation

Watch a liveness probe recover a "hung" container. This classic example is healthy
for 30 seconds, then the health file disappears and the probe fails:

```bash
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
spec:
  containers:
    - name: app
      image: busybox:1.36
      args: ["/bin/sh", "-c", "touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600"]
      livenessProbe:
        exec:
          command: ["cat", "/tmp/healthy"]
        initialDelaySeconds: 5
        periodSeconds: 5
EOF
kubectl get pod liveness-demo -w     # after ~30s RESTARTS increments as liveness fails
```

Now express a placement rule. Reserve a node by **tainting** it, and prove only a
Pod that **tolerates** the taint can land there:

```bash
NODE=$(kubectl get nodes -o name | tail -1)
kubectl taint "$NODE" tier=critical:NoSchedule        # node now repels normal Pods
kubectl label "$NODE" tier=critical --overwrite

# A Pod with a matching toleration + nodeSelector CAN run on the reserved node:
kubectl run tolerant --image=nginx \
  --overrides='{"spec":{"tolerations":[{"key":"tier","value":"critical","effect":"NoSchedule"}],"nodeSelector":{"tier":"critical"}}}'
kubectl get pod tolerant -o wide     # scheduled onto the tainted node
```

A probe told Kubernetes what "healthy" means; a taint/toleration told it where a Pod
belongs. The lab combines these with anti-affinity, a PDB, and a node drain.

---

## 5. Hands-on lab

On a multi-node kind cluster you'll configure all three probes, force a liveness
failure (watch a restart) and a readiness failure (watch a Pod leave the Service),
then spread replicas with anti-affinity, protect them with a PodDisruptionBudget, and
**drain a node** to watch the PDB keep your service above its floor.

➡️ **[Start the lab: Probes, placement, and safe drains](./lab/README.md)**

---

## 6. Production considerations

- **Make liveness cheap and local; make readiness reflect dependencies.** Liveness
  should check "is *this process* wedged," not "is the database up" (or a DB blip
  restarts every Pod). Readiness can include dependency checks so traffic pauses
  gracefully.
- **Always use a startup probe for slow starters.** It prevents the "boots in 40s,
  liveness kills it at 20s, crash loop forever" failure — far safer than a giant
  `initialDelaySeconds`.
- **Spread replicas by default.** Use `topologySpreadConstraints` or anti-affinity
  across nodes and zones so a single failure domain can't take a whole service down.
- **Ship a PDB with every important Deployment.** Without one, a node drain (or
  cluster autoscaler) can evict every replica at once. `minAvailable` must leave real
  headroom (don't set it equal to replicas, or drains deadlock).
- **Govern PriorityClasses centrally.** If every team marks itself "high priority,"
  priority is meaningless and critical platform components lose. Reserve the top tiers
  for system and platform workloads.
- **Taint dedicated nodes** (GPU, licensed software) so only tolerating workloads
  land there — otherwise ordinary Pods waste expensive capacity.

---

## 7. Common mistakes

- **Using a liveness probe where you meant readiness.** — A dependency check on
  liveness restarts Pods during a downstream blip, amplifying a small problem into a
  crash loop. *Fix:* liveness = local "am I wedged"; readiness = "should I get
  traffic."
- **No readiness probe, so rollouts and warm-ups send traffic into the void.** —
  Requests fail during startup. *Fix:* add a readiness probe; Services only route to
  ready Pods.
- **No startup probe on slow apps.** — Liveness kills the app mid-boot, forever. *Fix:*
  add a startup probe sized to worst-case boot time.
- **`minAvailable` equal to replica count.** — The PDB forbids evicting *any* Pod, so
  `kubectl drain` hangs indefinitely. *Fix:* leave headroom (e.g. `minAvailable: 2`
  for 3 replicas).
- **All replicas on one node (no anti-affinity).** — One node failure is a full
  outage. *Fix:* spread with anti-affinity / topology spread constraints.
- **Everything marked high priority.** — Preemption becomes noise and truly critical
  Pods aren't protected. *Fix:* a small, governed set of priority classes.

---

## 8. Assessment

**Knowledge checks**

1. What does Kubernetes do when a liveness probe fails versus a readiness probe fails?
2. When do you need a startup probe, and what does it pause while it runs?
3. What's the difference between node affinity and a taint/toleration? Which pulls and
   which pushes?
4. How does pod anti-affinity improve availability?
5. What does a PodDisruptionBudget protect against, and what does it *not* protect
   against?

**Concept exercise**

> Explain how a load balancer stops sending requests to an app instance that has
> temporarily lost its database connection, without killing that instance — **without
> using the words "readiness probe" or "endpoint."** Describe the signal-and-de-route
> idea in your own words.

**Trade-off / debugging exercise**

> A team put a check that pings the database on their **liveness** probe. During a
> 30-second database hiccup, every Pod of their service restarted simultaneously,
> turning a minor blip into a full outage. Explain exactly why, and what they should
> have done.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Liveness failure → the kubelet kills and restarts the container. Readiness
  failure → the Pod is removed from Service endpoints (no traffic) but keeps running.
- **Q2:** For apps with long/variable startup; while the startup probe runs, liveness
  and readiness checks are suspended so a slow boot isn't treated as a failure.
- **Q3:** Node affinity/nodeSelector *pull* a Pod toward matching nodes; a taint
  *pushes* all Pods away from a node unless they carry a matching toleration.
- **Q4:** It spreads replicas across nodes/zones so a single failure domain going down
  doesn't take all replicas with it.
- **Q5:** A PDB limits **voluntary** disruptions (drains, autoscaler) so a service
  stays above its availability floor. It does **not** prevent involuntary disruptions
  like a node crashing.
- **Debugging exercise:** A liveness probe restarts the container on failure. Tying it
  to the database means a DB hiccup fails liveness on every Pod at once, so the kubelet
  restarts them all — amplifying the outage. The DB check belongs on **readiness**
  (pause traffic, stay up) or nowhere; liveness should only detect a wedged local
  process.

</details>

---

## 9. Further reading

- Kubernetes — [Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/concepts/configuration/liveness-readiness-startup-probes/)
- Kubernetes — [Configure probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- Kubernetes — [Assigning Pods to Nodes (affinity, nodeSelector)](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/)
- Kubernetes — [Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- Kubernetes — [Pod Disruption Budgets](https://kubernetes.io/docs/concepts/workloads/pods/disruptions/) and [Pod Priority and Preemption](https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 03.7 — Resource Management](../07-resource-management/)
· _Next:_ [Module 03.9 — Debugging and Troubleshooting →](../09-debugging-and-troubleshooting/)
