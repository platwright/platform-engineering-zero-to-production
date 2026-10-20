# Module 03.1 — Kubernetes Architecture

> Before you deploy anything, you need a mental model of **how Kubernetes thinks**.
> This module builds that model from first principles: the reconciliation loop, the
> split between the control plane and the data plane, and why every component talks
> to the API server instead of to each other. Get this right and the rest of
> Kubernetes becomes predictable.

**Estimated effort:** ~2–2.5 hours (theory + lab)
**You'll need:** [Module 00 · Orientation](../../00-orientation/) (Docker, `kubectl`, and [kind](https://kind.sigs.k8s.io/)) and [Phase 2 · Containerization](../../02-containerization/).

## Learning objectives

By the end of this module you will be able to:

- Explain the **reconciliation loop** and the difference between *desired* and
  *actual* state.
- Name the **control-plane** components (API server, etcd, scheduler, controller
  manager, cloud controller manager) and what each one does.
- Name the **data-plane** components (kubelet, kube-proxy, container runtime) and
  what each one does.
- Explain why the **API server is the hub** that every other component speaks to.
- Read any Kubernetes object in terms of `metadata`, `spec`, and `status`, and
  navigate a cluster with `kubectl` and `kubeconfig` contexts.

---

## 1. Concept

### The problem Kubernetes solves

You have containers (Phase 2). Running one on your laptop is easy. Now run two
hundred of them across twenty machines, keep them alive when a machine dies, replace
them during deploys without downtime, let them find each other, and give every
developer a safe way to do the same. Doing that by hand — SSHing into boxes,
restarting crashed processes, editing load balancers — does not scale and does not
survive a 2am failure.

Kubernetes is a **container orchestrator**: a control system that runs your
containers for you and keeps them running in the face of failure. The key word is
*control system*. You don't tell Kubernetes *how* to do things step by step; you
tell it *what you want*, and it works continuously to make reality match.

### Desired state, actual state, and the reconciliation loop

This is the single most important idea in Kubernetes.

- **Desired state** — what you declared you want (e.g. "three replicas of this web
  app"). It lives in the cluster's database.
- **Actual state** — what is really running right now (e.g. "two replicas; one node
  just died").
- **Reconciliation** — controllers continuously observe the actual state, compare it
  to the desired state, and take action to close the gap.

```text
             ┌──────────────────────────────┐
             │   desired state (you declare) │
             └───────────────┬──────────────┘
                             │ compare
                             ▼
   observe ──► [ difference? ] ──► act to close the gap ──► observe ──► …
      ▲                                                        │
      └────────────────────────────────────────────────────────┘
                     a loop that never stops running
```

Delete a Pod that belongs to a Deployment and a new one appears seconds later — not
because something "watched for deletes," but because a controller noticed actual
(2 Pods) no longer matched desired (3 Pods) and created one. This loop is why
Kubernetes is **self-healing** and why it is **declarative**: you manage the desired
state, the system manages the convergence.

### Visual model: Kubernetes architecture

For the reusable cluster view, see the [Kubernetes architecture diagram](../../diagrams/architecture/kubernetes-architecture.png).

### The control plane: the brain

The **control plane** makes global decisions about the cluster. It has four core
components plus one for cloud integration:

- **API server (`kube-apiserver`)** — the front door. It is the only component that
  talks to the database, validates and authenticates every request, and serves the
  REST API that `kubectl`, controllers, and kubelets all use. Everything flows
  through it.
- **etcd** — a distributed, consistent key-value store. It holds the entire cluster
  state: every object you've created and its current status. If etcd is the source
  of truth, the API server is its guardian. Lose etcd without a backup and you've
  lost the cluster.
- **Scheduler (`kube-scheduler`)** — decides *which node* a new Pod should run on.
  It watches for Pods with no node assigned, scores the available nodes against the
  Pod's requirements (resources, affinity, taints), and writes its choice back to
  the API server. It only *decides*; it does not start containers.
- **Controller manager (`kube-controller-manager`)** — runs the reconciliation
  loops. It is actually dozens of controllers in one process: the Deployment
  controller, ReplicaSet controller, Node controller, Job controller, and many
  more. Each watches its objects and drives actual toward desired.
- **Cloud controller manager** — integrates with a cloud provider's APIs: when you
  create a `LoadBalancer` Service on GKE or EKS, this provisions the actual load
  balancer and reacts to nodes being deleted. A local kind cluster has no cloud, so
  it does little.

### The data plane: the muscle

The **data plane** (the worker nodes) actually runs your containers. Every node
runs three things:

- **kubelet** — the node's agent, and the only thing that turns a *scheduled* Pod
  into *running* containers. It watches the API server for Pods assigned to its node,
  tells the container runtime to start/stop them, and reports status back.
- **kube-proxy** — programs the node's networking (iptables/IPVS rules) so that the
  stable virtual IP of a Service routes to the right Pods. (Much more in
  [Module 03.3](../03-services-and-networking/).)
- **Container runtime** — the software that actually runs containers, via the
  Container Runtime Interface (CRI). Modern clusters use **containerd**; Docker's
  engine is no longer used directly by Kubernetes.

### The API server is the hub — nothing talks peer-to-peer

Here is the structural insight that explains the whole architecture: **components do
not talk to each other. They all talk to the API server.** The scheduler doesn't
call the kubelet; it writes "Pod X goes on Node 2" to the API server, and the
kubelet on Node 2 — which is watching the API server — picks it up. etcd is never
touched directly except by the API server.

This hub-and-spoke design is why Kubernetes is extensible and observable: every
change is a declarative write to one audited, access-controlled API. Your own
controllers and operators join the cluster the same way the built-in ones do — by
watching and writing objects.

### The resource model: metadata, spec, status

Every Kubernetes object has the same shape:

- **`metadata`** — identity: name, namespace, labels, annotations.
- **`spec`** — the *desired state* you declare.
- **`status`** — the *actual state*, written and updated by controllers (you never
  set it).

That split *is* the reconciliation loop expressed as data: you write `spec`,
controllers write `status`, and they work to make `status` match `spec`.

### kubectl and kubeconfig

`kubectl` is a REST client for the API server. The handful of verbs you'll use
constantly:

- `kubectl get` / `describe` — read objects (summary / detail with events).
- `kubectl apply -f` — declaratively create or update from YAML.
- `kubectl delete` — remove an object.
- `kubectl logs` / `exec` — read a container's logs / run a command inside it.

Which cluster does `kubectl` talk to? That's your **kubeconfig** (`~/.kube/config`),
which bundles three things into named **contexts**:

- **clusters** — API server URLs and their CA certs.
- **users** — credentials (certs, tokens).
- **contexts** — a (cluster + user + namespace) triple. `kubectl config
  use-context` switches between them.

`kind create cluster` adds a context automatically, so you can hold many clusters in
one config and switch safely.

---

## 2. Why it matters for platform engineering

Kubernetes is the substrate the rest of this course builds on, and as a platform
engineer you don't just *use* it — you operate it for other teams:

- **Debugging requires the model.** When a Pod is stuck `Pending`, knowing that the
  *scheduler* places Pods (and writes events explaining why it can't) turns a
  mystery into a checklist. Without the model you guess; with it you reason.
- **Everything is the reconciliation loop.** GitOps (Phase 8) is reconciliation with
  Git as the desired state. Operators and CRDs (Phase 10) are custom controllers.
  Autoscalers, cert managers, and ingress controllers are all the same pattern. One
  idea, applied everywhere.
- **The API is the platform interface.** Because every capability is an API object,
  you can build golden paths, policies, and self-service on top of it. The API
  server being the single hub is *why* platforms can be layered on Kubernetes.
- **Operational responsibility.** You'll make decisions about etcd backups, control
  plane HA, and which parts a managed provider runs for you. You can't reason about
  those trade-offs without knowing what each component does.

---

## 3. Mental model

Picture Kubernetes as a hub-and-spoke control system: one API server in the middle,
every other component watching and writing through it, and loops everywhere driving
actual state toward desired state.

```text
                         CONTROL PLANE (the brain)
   ┌───────────────────────────────────────────────────────────────┐
   │                                                                 │
   │   ┌──────────┐     ┌──────────────────────┐     ┌───────────┐  │
   │   │  etcd    │◄───►│      API SERVER       │◄───►│ scheduler │  │
   │   │ (truth)  │     │  (the ONLY hub; all   │     └───────────┘  │
   │   └──────────┘     │  reads/writes go here)│     ┌───────────┐  │
   │                    │                       │◄───►│controller │  │
   │                    └───────────┬───────────┘     │ manager   │  │
   │                                │                 └───────────┘  │
   └────────────────────────────────┼───────────────────────────────┘
                                    │ watch + write (never peer-to-peer)
          ┌─────────────────────────┼─────────────────────────┐
          ▼                         ▼                         ▼
   ┌─────────────┐          ┌─────────────┐          ┌─────────────┐
   │   NODE 1    │          │   NODE 2    │          │   NODE 3    │
   │ kubelet     │          │ kubelet     │          │ kubelet     │
   │ kube-proxy  │          │ kube-proxy  │          │ kube-proxy  │
   │ containerd  │          │ containerd  │          │ containerd  │
   │  [ Pods ]   │          │  [ Pods ]   │          │  [ Pods ]   │
   └─────────────┘          └─────────────┘          └─────────────┘
                         DATA PLANE (the muscle)
```

Three rules to remember a year from now:

1. **You declare `spec`; controllers own `status`.** Manage desired state, not steps.
2. **Everything goes through the API server.** No component talks peer-to-peer.
3. **Reconciliation never stops.** The cluster is always closing the gap between
   what is and what you asked for.

---

## 4. Minimal implementation

Let's watch the reconciliation loop from section 3 actually run. Create a bare Pod
and delete it — nothing brings it back, because a bare Pod has no controller watching
its desired count:

```bash
kubectl run nginx --image=nginx        # create a single Pod (no controller)
kubectl delete pod nginx               # it's gone — and stays gone
```

Now give it a controller. A Deployment declares "I want N of these," so its
controller reconciles the count for you:

```bash
kubectl create deployment web --image=nginx --replicas=3
kubectl get pods -l app=web            # three Pods
kubectl delete pod -l app=web --field-selector=status.phase=Running \
  --wait=false                          # delete them...
kubectl get pods -l app=web -w          # ...and watch replacements appear
```

Finally, look at the `spec`/`status` split that drives it all:

```bash
kubectl get deployment web -o yaml | grep -A3 '^spec:'    # desired: replicas: 3
kubectl get deployment web -o yaml | grep -A6 '^status:'  # actual: readyReplicas…
```

You just watched a controller observe a difference (2 ≠ 3) and act. That's the whole
system in miniature.

---

## 5. Hands-on lab

You'll stand up a **local multi-node kind cluster**, explore the control-plane Pods
that run the components you just learned, and then provoke the reconciliation loop —
deleting Pods and watching the system heal itself. No cloud, no cost.

➡️ **[Start the lab: Explore a cluster and the reconciliation loop](./lab/README.md)**

---

## 6. Production considerations

What changes between a kind cluster on your laptop and a cluster serving many teams:

- **Managed control planes.** On GKE, EKS, or AKS the provider runs and backs up the
  API server, etcd, scheduler, and controller manager for you (the control plane is
  often free) with an SLA; you manage nodes and workloads. This is the usual choice —
  running your own etcd is a serious operational commitment.
- **etcd is the crown jewels.** It holds all cluster state, so production clusters run
  it with an odd number of members (3 or 5) for quorum, on fast disks, with regular
  encrypted backups. "Back up etcd" is the single most important self-managed task.
- **Control-plane high availability.** A single API server is a single point of
  failure. HA clusters run multiple API server replicas behind a load balancer and
  multiple etcd members across failure domains.
- **Node pools and autoscaling.** Real clusters group nodes into pools (e.g.
  general, memory-optimized, GPU, spot) and add/remove nodes automatically
  ([Module 03.7](../07-resource-management/)).
- **Provision clusters as code.** Nobody clicks "create cluster" in production.
  Clusters are defined with Terraform (Phase 5) so they're reproducible and
  reviewable — the GKE equivalent of `kind create cluster` is a Terraform module.
- **API server is also the security boundary.** Every request is authenticated and
  authorized ([Module 03.6](../06-rbac/)); its audit log is a primary security
  signal.

---

## 7. Common mistakes

- **Thinking of Pods as things you start and stop by hand.** — People `kubectl run`
  a Pod, see it vanish on failure, and conclude Kubernetes is flaky. *Fix:* almost
  never create bare Pods; create a controller (Deployment/StatefulSet/Job) and let
  reconciliation own the lifecycle.
- **Believing components call each other.** — Assuming the scheduler "tells" the
  kubelet to run a Pod leads to wrong debugging. *Fix:* remember the hub — the
  scheduler writes an assignment to the API server; the kubelet reads it. Debug by
  inspecting the object and its events.
- **Editing `status` or expecting to set it.** — `status` is owned by controllers;
  hand-editing it is meaningless and gets overwritten. *Fix:* change `spec` (desired
  state) and let the controller update `status`.
- **Ignoring kubeconfig context.** — Running a command against the wrong cluster
  because the context wasn't checked. *Fix:* `kubectl config current-context` before
  anything destructive; prefix risky commands with `--context`.
- **Treating etcd as disposable.** — No backups, single member, slow disk. *Fix:*
  on self-managed clusters, back up etcd and run it HA; on managed clusters, confirm
  the provider's backup guarantees.

---

## 8. Assessment

**Knowledge checks**

1. In one sentence, what is the reconciliation loop, and which part of an object is
   *desired* vs *actual* state?
2. Which component decides *which node* a Pod runs on, and which component actually
   *starts* its containers?
3. Why do people say "everything talks to the API server"? What design property does
   that give the cluster?
4. What does etcd store, and why is backing it up the top self-managed operational
   task?
5. What three things does a kubeconfig *context* tie together?

**Concept exercise**

> Explain how Kubernetes keeps three copies of a web app running after a node dies —
> **without using the words "Kubernetes," "Deployment," or "controller."** Describe
> it purely as a control system with desired state, observation, and corrective
> action.

**Debugging / trade-off exercise**

> A teammate says: "I deleted the Pod but it keeps coming back — Kubernetes is
> broken." Another says: "I deleted my Pod and it's gone forever — Kubernetes lost
> my app." Both ran `kubectl delete pod …`. Explain how *both* can be true depending
> on how the Pod was created, and what you'd check first.

<details>
<summary>Discussion (open after you've answered)</summary>

- **Q1:** Controllers continuously compare actual state to the desired state and act
  to close the gap. `spec` is desired; `status` is actual.
- **Q2:** The **scheduler** decides placement (binds a Pod to a node); the **kubelet**
  on that node tells the container runtime to start the containers.
- **Q3:** Because every component watches and writes through the API server rather
  than calling each other. That hub-and-spoke design makes the system auditable,
  access-controlled, and extensible — your own controllers join the same way.
- **Q4:** etcd stores the entire cluster state (all objects and their status). If
  it's lost without a backup, the cluster's source of truth is gone, so a verified
  backup is the most important self-managed task.
- **Q5:** A cluster (API endpoint + CA), a user (credentials), and a default
  namespace.
- **Debugging exercise:** A Pod created by a Deployment/ReplicaSet has a controller
  reconciling its replica count, so deleting it triggers a replacement ("keeps
  coming back"). A *bare* Pod (`kubectl run` without a controller, or a standalone
  Pod manifest) has nothing reconciling it, so it stays gone. First check:
  `kubectl get pod <name> -o jsonpath='{.metadata.ownerReferences}'` — an owner
  means a controller will replace it.

</details>

---

## 9. Further reading

- Kubernetes — [Kubernetes Components](https://kubernetes.io/docs/concepts/overview/components/)
- Kubernetes — [Kubernetes API concepts: objects, spec and status](https://kubernetes.io/docs/concepts/overview/working-with-objects/kubernetes-objects/)
- Kubernetes — [The Kubernetes API reference](https://kubernetes.io/docs/reference/kubernetes-api/)
- Kubernetes — [Controllers and the control loop](https://kubernetes.io/docs/concepts/architecture/controller/)
- Kubernetes — [Organizing cluster access using kubeconfig files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- kind — [Quick start](https://kind.sigs.k8s.io/docs/user/quick-start/)

---

### Module progress

- [ ] Theory completed
- [ ] Lab completed
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

_Previous:_ [Phase 2 · Containerization](../../02-containerization/)
· _Next:_ [Module 03.2 — Workloads →](../02-workloads/)
