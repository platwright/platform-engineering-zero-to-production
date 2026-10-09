# Module 03.2 — Workloads

> A Pod is the atomic unit Kubernetes runs — but you almost never create one
> directly. Instead you declare a **workload controller** (Deployment, StatefulSet,
> DaemonSet, Job, CronJob) that reconciles Pods toward a desired state. This module
> teaches which controller to reach for, and why, so rolling updates, rollbacks, and
> stable identities stop being magic.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 03.1](../01-kubernetes-architecture/) and a working
`kubectl` + [kind](https://kind.sigs.k8s.io/).

## Learning objectives

By the end of this module you will be able to:

- Explain why a **Pod** is rarely created directly, and what a controller adds.
- Use a **Deployment** for stateless apps, and perform a rolling update and a
  rollback.
- Choose between **Deployment, StatefulSet, DaemonSet, Job, and CronJob** for a
  given workload.
- Describe the **Deployment → ReplicaSet → Pod** ownership chain.
- Read a Pod spec: containers, **init containers**, volumes, resources, and probes.

---

## 1. Concept

### The Pod: the atomic unit

A **Pod** is one or more containers that share a network namespace (same IP and port
space) and can share storage volumes. Containers in a Pod are always co-located on
the same node and scheduled together. Most Pods have exactly one app container,
sometimes with helper **sidecar** containers (a log shipper, a proxy).

A Pod is also **mortal and disposable**. It has no stable identity of its own: if its
node dies, the Pod dies with it and is *not* resurrected on its own. That's by
design — the Pod is the unit of work, not the unit of durability. Durability and
desired-count come from a **controller** wrapped around Pods.

That's why you rarely write a bare `kind: Pod`. You write a controller that *owns*
Pods and reconciles them (the loop from Module 03.1).

### Deployment: the workhorse for stateless apps

A **Deployment** declares "I want N identical, interchangeable replicas of this Pod
template." It's the default for stateless services (web servers, APIs, workers).

A Deployment doesn't manage Pods directly — it manages a **ReplicaSet**, which
manages the Pods:

```text
Deployment  (desired template + replica count + update strategy)
   └── owns ReplicaSet  (pins a specific Pod template version, keeps N Pods)
          └── owns Pods (the actual running containers)
```

Why the extra layer? **Rolling updates.** When you change the Pod template (e.g. a
new image), the Deployment creates a *new* ReplicaSet and gradually shifts replicas
from old to new — scaling the new up and the old down a few Pods at a time, governed
by `maxSurge` and `maxUnavailable`. Users never see downtime, and the old ReplicaSet
is kept (scaled to zero) so you can **roll back** instantly.

- `kubectl rollout status` — watch an update progress.
- `kubectl rollout undo` — revert to the previous ReplicaSet.
- `kubectl rollout history` — see revisions.

### StatefulSet: when identity and order matter

Some workloads (databases, message brokers, anything clustered) need each replica to
have a **stable identity** and **stable storage**. A **StatefulSet** gives you:

- **Stable network identity** — Pods are named `name-0`, `name-1`, … (an *ordinal*),
  and keep that name across reschedules, reachable via a headless Service
  ([Module 03.3](../03-services-and-networking/)).
- **Ordered operations** — Pods are created and scaled in order (0, then 1, then 2)
  and terminated in reverse. A cluster can bootstrap `-0` as the seed before `-1`
  joins.
- **Stable per-Pod storage** — each Pod gets its *own* PersistentVolumeClaim from a
  `volumeClaimTemplate`, and it reattaches to the *same* volume on reschedule
  ([Module 03.5](../05-storage/)).

Deployment Pods are cattle (interchangeable); StatefulSet Pods are more like pets
with fixed names and fixed disks.

### DaemonSet: one Pod per node

A **DaemonSet** runs exactly one Pod on every node (or every node matching a
selector), and automatically adds a Pod when a new node joins. It's for
**node-level agents**: log collectors (Fluent Bit), metrics exporters (node
exporter), CNI and storage plugins, security agents. You don't set a replica count —
the count *is* the number of matching nodes.

### Job and CronJob: run to completion

Deployments assume a process that should run forever. **Jobs** are the opposite: run
a Pod (or many) **to successful completion**, then stop. Use a Job for a migration, a
batch computation, or a one-off task. A Job can run Pods in **parallel**
(`parallelism`) and require a number of successes (`completions`), retrying failures
up to `backoffLimit`.

A **CronJob** creates Jobs on a schedule (standard cron syntax) — nightly backups,
periodic reports, scheduled cleanups.

### Pod spec deep dive

Every controller embeds a **Pod template** (`spec.template`). The pieces you'll set
most:

- **`containers`** — image, command/args, ports, env, resources, probes.
- **`initContainers`** — containers that run to completion *before* the app
  containers start, in order. Use them for setup: wait for a dependency, run a
  schema migration, fetch a config. If an init container fails, the Pod restarts.
- **`volumes`** — storage made available to containers (a ConfigMap, a Secret, an
  `emptyDir`, a PersistentVolumeClaim).
- **`resources`** — requests and limits ([Module 03.7](../07-resource-management/)).
- **probes** — liveness/readiness/startup ([Module 03.8](../08-health-and-scheduling/)).

---

## 2. Why it matters for platform engineering

- **The controller is the contract.** Platform golden paths ship as controller
  templates: "deploy a stateless service" is a Deployment template; "run a nightly
  job" is a CronJob template. Knowing their semantics is knowing what you can safely
  promise teams.
- **Rolling updates are your deploy mechanism.** Zero-downtime deploys, canaries, and
  rollbacks are all built on Deployment rollout behavior. GitOps (Phase 8) drives
  these same objects.
- **Stateful vs stateless is an architecture decision.** Pushing a database into a
  Deployment (losing identity and storage) is a classic production incident. Guiding
  teams to the right controller prevents data loss.
- **DaemonSets are how the platform ships itself.** The observability, security, and
  networking agents *you* run for every team are DaemonSets. You'll operate more of
  them than any single app team.

---

## 3. Mental model

Think of workload controllers as a spectrum from "interchangeable and forever" to
"unique" to "finite":

```text
   STATELESS, LONG-RUNNING            STATEFUL, LONG-RUNNING
   ────────────────────────           ──────────────────────
   Deployment                         StatefulSet
     cattle: web-7f9c-ab12              pets: db-0, db-1, db-2
     any Pod == any other               fixed names + own disk
     rolling update via ReplicaSet      ordered, stable identity

   ONE-PER-NODE                       RUN-TO-COMPLETION
   ────────────                       ─────────────────
   DaemonSet                          Job (one-off)   CronJob (scheduled)
     log/metric/security agents         migrations      nightly backups
     count = number of nodes            batch work       cron schedule

   All of them wrap the SAME thing: a Pod template, reconciled toward desired state.
```

The decision tree:

```text
Does it run forever?
├─ No  → finite work → on a schedule? → CronJob : Job
└─ Yes → does each replica need a stable identity/own storage?
         ├─ Yes → StatefulSet
         └─ No  → must it run on every node? → DaemonSet : Deployment
```

---

## 4. Minimal implementation

Start stateless. Create a Deployment imperatively, then look at the ownership chain
reconciliation built for you:

```bash
kubectl create deployment web --image=nginx:1.25 --replicas=3
kubectl get deploy,rs,pods -l app=web      # Deployment → ReplicaSet → 3 Pods
```

Do a **rolling update** by changing the image, and watch it progress:

```bash
kubectl set image deployment/web nginx=nginx:1.27
kubectl rollout status deployment/web      # waits until the new ReplicaSet is healthy
kubectl get rs -l app=web                  # old RS scaled to 0, new RS at 3
```

Something wrong? **Roll back** to the previous ReplicaSet instantly:

```bash
kubectl rollout undo deployment/web
kubectl rollout history deployment/web
```

Now contrast with a finite workload — a Job that runs once and stops:

```bash
kubectl create job pi --image=perl:5.34 -- perl -Mbignum=bpi -wle 'print bpi(200)'
kubectl wait --for=condition=complete job/pi --timeout=60s
kubectl logs job/pi                        # 200 digits of pi, then the Pod is Completed
```

Same reconciliation engine, three different desired-state semantics: "keep 3 running,"
"replace them safely on change," and "run once to completion."

---

## 5. Hands-on lab

You'll deploy a stateless app, perform a rolling update and a rollback while watching
the ReplicaSets swap, then deploy a StatefulSet and prove its Pods keep stable
identities across deletion. All on a local kind cluster.

➡️ **[Start the lab: Deployments, rollouts, and StatefulSets](./lab/README.md)**

---

## 6. Production considerations

- **Tune the rollout strategy.** `maxSurge`/`maxUnavailable` trade deploy speed
  against spare capacity; set them deliberately. Pair rollouts with **readiness
  probes** ([Module 03.8](../08-health-and-scheduling/)) or a broken new version will
  happily replace a working one.
- **Pin image tags; prefer digests.** `:latest` makes rollouts non-reproducible and
  rollbacks meaningless. Use immutable tags or `@sha256:` digests so a revision maps
  to exact bytes.
- **Set `revisionHistoryLimit`.** Keep enough old ReplicaSets to roll back, not so
  many that the cluster fills with cruft.
- **StatefulSets need care.** Ordered, slow rollouts; deleting a StatefulSet does
  **not** delete its PVCs by default (good — your data survives; also a cleanup
  footgun). Scaling down leaves the volumes behind.
- **CronJobs need guardrails.** Set `concurrencyPolicy` (don't let a slow job stack
  up), `startingDeadlineSeconds`, and history limits. A misconfigured CronJob can
  spawn hundreds of Jobs.
- **PodDisruptionBudgets** keep rollouts and node drains from taking too many
  replicas down at once ([Module 03.8](../08-health-and-scheduling/)).

---

## 7. Common mistakes

- **Running a database in a Deployment.** — Deployment Pods are interchangeable and
  share no stable storage, so replicas fight over data or lose it. *Fix:* use a
  StatefulSet (or a managed database) when identity and per-replica storage matter.
- **Using `:latest` image tags.** — Rollouts become non-deterministic and rollbacks
  revert to "whatever latest was," not a known version. *Fix:* pin a specific tag or
  digest per release.
- **No readiness probe during rollouts.** — Kubernetes considers a Pod "available"
  as soon as the container starts, so a broken new version rolls out fully before
  anyone notices. *Fix:* add a readiness probe so only truly-ready Pods receive
  traffic and the rollout pauses on failure.
- **Treating a DaemonSet like a Deployment (setting replicas).** — DaemonSets have no
  replica count; the count is the node count. *Fix:* select nodes with
  `nodeSelector`/affinity, not `replicas`.
- **CronJob with unbounded concurrency.** — Long-running jobs overlap and pile up.
  *Fix:* set `concurrencyPolicy: Forbid` (or `Replace`) and history limits.
- **Scaling a StatefulSet down and expecting cleanup.** — PVCs are intentionally
  retained. *Fix:* delete leftover PVCs explicitly when you really mean to discard
  the data.

---

## 8. Assessment

**Knowledge checks**

1. Why do you almost never create a bare Pod directly? What does a controller add?
2. Walk the ownership chain from a Deployment to a running container. What is the
   ReplicaSet *for*?
3. Give one workload that must be a StatefulSet and one that must be a DaemonSet, and
   say why.
4. What does `kubectl rollout undo` actually do under the hood?
5. What's the difference between a Job's `completions` and `parallelism`?

**Concept exercise**

> Explain how Kubernetes updates a running web service to a new version with zero
> downtime — **without using the words "Deployment," "ReplicaSet," or "rollout."**
> Describe it as desired state plus a safe transition between two sets of replicas.

**Trade-off / debugging exercise**

> A team deployed Postgres as a Deployment with `replicas: 3` and a single shared
> PVC. It "worked" in staging and corrupted data in production. Explain every reason
> this is wrong, and what you'd change.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** A bare Pod has no reconciler — if it or its node dies, nothing recreates
  it. A controller maintains a *desired count* and lifecycle (recreate, scale,
  update, roll back).
- **Q2:** Deployment owns a ReplicaSet, which owns Pods, which the kubelet turns into
  containers. The ReplicaSet pins one Pod-template version and keeps N copies; the
  Deployment coordinates *two* ReplicaSets during an update to move replicas safely
  old → new (and keeps the old one for rollback).
- **Q3:** StatefulSet: a database/broker needing stable names and per-replica
  storage. DaemonSet: a log or metrics agent that must run on every node.
- **Q4:** It scales the previous ReplicaSet back up and the current one down —
  reverting to a known-good Pod template without rebuilding anything.
- **Q5:** `completions` = how many successful Pods are required; `parallelism` = how
  many run at once.
- **Trade-off:** Deployment Pods are interchangeable with no stable identity; three
  of them pointing at one `ReadWriteOnce` PVC means at most one can mount it (the
  others are stuck) or, with shared storage, they corrupt each other because
  Postgres assumes a single writer. There's no ordered bootstrap and no per-replica
  volume. Use a StatefulSet with a `volumeClaimTemplate` (one volume per Pod) and a
  real replication topology, or a managed database.

</details>

---

## 9. Further reading

- Kubernetes — [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- Kubernetes — [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- Kubernetes — [StatefulSets](https://kubernetes.io/docs/concepts/workloads/controllers/statefulset/)
- Kubernetes — [DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- Kubernetes — [Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/) and [CronJob](https://kubernetes.io/docs/concepts/workloads/controllers/cron-jobs/)
- Kubernetes — [Init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Module 03.1 — Kubernetes Architecture](../01-kubernetes-architecture/)
· _Next:_ [Module 03.3 — Services and Networking →](../03-services-and-networking/)
