# 03 · Kubernetes Fundamentals

> Kubernetes is the operating system of the modern platform. Almost everything in
> the rest of this course — GitOps, observability, policy, multi-cluster, the
> internal developer platform itself — runs **on** Kubernetes and uses its APIs as
> a foundation. This phase teaches Kubernetes from first principles: not "which
> command do I run," but **how the machine thinks**, so that when something breaks
> at 2am you can reason about it instead of guessing.

**Phase 3 · 9 modules · ~18–25 hours**

## Why Kubernetes, and why from first principles?

You can learn to type `kubectl apply -f` in an afternoon. That is not what this
phase is for. Platform engineers don't just *use* Kubernetes — they operate it,
extend it, debug it, and hand it to other teams as a product. That requires a
mental model of the thing, not a memorized list of commands.

The single idea that unlocks Kubernetes is the **reconciliation loop**: you declare
the *desired state* of the world, and controllers work continuously to make the
*actual state* match. Deployments, Services, PersistentVolumeClaims, autoscalers,
RBAC — nearly every object in the system is a variation on that one theme. Once you
see it, Kubernetes stops being a pile of YAML and becomes a predictable,
debuggable control system.

This phase builds that model layer by layer:

- **Architecture** — the control plane, the data plane, and why every component
  talks to the API server instead of to each other.
- **Workloads** — how Pods are wrapped in controllers (Deployment, StatefulSet,
  DaemonSet, Job) that reconcile them toward a declared state.
- **Networking and configuration** — how Pods find each other, and how you inject
  config and secrets without rebuilding images.
- **Storage** — how stateless orchestration manages stateful data.
- **RBAC, resource management, health, and scheduling** — the controls that make a
  cluster safe, fair, and reliable enough to hand to many teams.
- **Debugging** — the systematic workflow that turns a red Pod into a root cause.

Every later phase leans on this one. GitOps (Phase 8) reconciles Git into these
objects. Observability (Phase 11) watches them. Policy (Phase 13) guards them. Get
the fundamentals right here and the rest of the course is far easier.

## Modules

| # | Module | You'll learn | Lab deliverable |
|---|--------|--------------|-----------------|
| 1 | [Kubernetes Architecture](./01-kubernetes-architecture/) | Control plane vs data plane; the API server as the hub; the resource model; the reconciliation loop. | A local multi-node kind cluster you've explored and self-healed. |
| 2 | [Workloads](./02-workloads/) | Pods, Deployments, StatefulSets, DaemonSets, Jobs, CronJobs; rolling updates and rollback. | A rolled-out, rolled-back Deployment and a StatefulSet with stable identity. |
| 3 | [Services and Networking](./03-services-and-networking/) | ClusterIP, NodePort, LoadBalancer, headless Services; cluster DNS; EndpointSlices; kube-proxy. | A frontend that discovers a backend by DNS name. |
| 4 | [Configuration](./04-configuration/) | ConfigMaps and Secrets; env vars vs volume mounts; `envFrom`; immutability; encryption at rest. | A service configured by ConfigMap and Secret, with a hot-reload demo. |
| 5 | [Storage](./05-storage/) | PVs, PVCs, StorageClasses, access modes, CSI; how StatefulSets claim storage. | A StatefulSet whose data survives Pod deletion. |
| 6 | [RBAC](./06-rbac/) | Subjects, Roles/ClusterRoles, bindings; least privilege; `auth can-i`. | A scoped CI/CD ServiceAccount proven with `kubectl auth can-i`. |
| 7 | [Resource Management](./07-resource-management/) | Requests vs limits; QoS classes; LimitRange; ResourceQuota; HPA. | A namespace with quotas and an autoscaling Deployment under load. |
| 8 | [Health, Probes and Scheduling](./08-health-and-scheduling/) | Liveness/readiness/startup probes; affinity; taints/tolerations; PDBs; PriorityClasses. | A probed app plus a scheduling-and-disruption experiment. |
| 9 | [Debugging and Troubleshooting](./09-debugging-and-troubleshooting/) | The describe → events → logs → exec workflow; the five classic failure modes. | Five pre-broken manifests diagnosed and fixed. |

Work them in order — each builds on the last. Together they take you from "what are
all these moving parts?" to "I can deploy, expose, configure, secure, scale, and
debug a real workload on Kubernetes."

## Learning objectives

By the end of this phase you will be able to:

- Explain the Kubernetes control-plane and data-plane components and how the
  reconciliation loop keeps actual state converging on desired state.
- Choose and configure the right workload controller (Deployment, StatefulSet,
  DaemonSet, Job, CronJob) for a given problem.
- Expose and connect workloads using Services and cluster DNS, and reason about the
  trade-offs of each Service type.
- Inject configuration and secrets safely, and explain why Kubernetes Secrets are
  not encrypted by default.
- Provision and attach persistent storage, and explain how stateful workloads keep
  their data across rescheduling.
- Apply least-privilege RBAC, resource requests/limits, quotas, probes, and
  scheduling constraints to make a cluster safe and reliable for many teams.
- Diagnose the common failure modes (`CrashLoopBackOff`, `ImagePullBackOff`,
  `OOMKilled`, `Pending`, unreachable Service) using a repeatable workflow.

## Prerequisites

- [Module 00 · Orientation](../00-orientation/) — Docker, `kubectl`, and
  [kind](https://kind.sigs.k8s.io/) installed locally.
- [Phase 2 · Containerization](../02-containerization/) — you should be comfortable
  with images, registries, and running containers. Kubernetes orchestrates
  containers; it assumes you already understand them.

Everything in this phase runs on a **local kind cluster** — free, offline, and
disposable. There is **no cloud spend required**. Where production behavior differs
on a managed service such as GKE, the lessons call it out explicitly, but every
hands-on step runs on your laptop.

## A note on the labs

These labs are deliberately hands-on: you will break things on purpose, watch
controllers heal them, and read the system's own events to understand what it is
doing. Keep the manifests you write — they become the raw material for
[Phase 4 · Platform Project 01](../04-platform-project-01/), where you assemble a
real container platform on top of everything you learn here.

Every lab that creates a cluster or resources ends with a **mandatory cleanup**
step (`kind delete cluster` or `kubectl delete`). Running clusters consume laptop
memory; tear them down when you're done.

---

Start with [**03.1 · Kubernetes Architecture →**](./01-kubernetes-architecture/)
