# Glossary

A quick reference for the terms used throughout this course. Definitions are
intentionally short and practical; the relevant module goes deeper. If a term you
need is missing, please [open an issue](https://github.com/platwright/platform-engineering-zero-to-production/issues) or a pull request.

> Tip: use your browser's find (<kbd>Ctrl/Cmd</kbd>+<kbd>F</kbd>) to jump to a term.

---

## A

- **ADR (Architecture Decision Record)** â€” A short document capturing one
  significant decision: its context, the decision, and the consequences. See the
  [template](../shared/templates/adr-template.md).
- **Admission webhook** â€” A Kubernetes extension point that validates or mutates
  objects as they're submitted to the API server (e.g. to enforce policy).
- **Alertmanager** â€” The component that routes, groups, and silences alerts from
  Prometheus and sends them to destinations (Slack, PagerDuty, email).
- **ApplicationSet** â€” An ArgoCD resource that generates many `Application`s from a
  single template (e.g. one per cluster or per environment).
- **ArgoCD** â€” A GitOps engine that continuously reconciles a cluster's state
  toward declarative config stored in Git.

## B

- **Backstage** â€” An open-source framework (originally from Spotify, now CNCF) for
  building an Internal Developer Portal: software catalog, templates, and docs.
- **Blast radius** â€” The scope of damage a change or failure can cause. Platform
  design limits it (e.g. via state isolation, namespaces, and quotas).
- **BuildKit** â€” Docker's modern build engine: parallel stages, better caching,
  build secrets, and multi-platform builds.

## C

- **Canary / progressive delivery** â€” Releasing a change to a small slice of
  traffic first, then widening it as confidence grows.
- **Capstone** â€” A portfolio-grade project that combines many phases into one
  complete, documented, reproducible platform.
- **CNCF (Cloud Native Computing Foundation)** â€” The foundation that hosts
  Kubernetes, Prometheus, ArgoCD, Backstage, and many other projects used here.
- **CNI (Container Network Interface)** â€” The plugin standard for pod networking
  (e.g. Cilium). It wires pods into the cluster network.
- **Cognitive load** â€” The mental effort required to do a task. Reducing
  *extraneous* cognitive load on developers is a central goal of platform
  engineering.
- **ConfigMap** â€” A Kubernetes object holding non-sensitive configuration consumed
  by pods as env vars or mounted files.
- **Container** â€” A process isolated with Linux namespaces and cgroups, running
  from an image. Lighter than a VM; shares the host kernel.
- **Controller** â€” A control loop that watches the desired state of a resource and
  works to make the actual state match it. The heart of how Kubernetes self-heals.
- **Cosign** â€” A Sigstore tool for signing and verifying container images and other
  artifacts, enabling keyless signing via OIDC.
- **CRD (Custom Resource Definition)** â€” Extends the Kubernetes API with your own
  resource types, which operators then act upon.
- **Crossplane** â€” A tool for provisioning and managing cloud infrastructure
  through the Kubernetes API, as an alternative/complement to Terraform.

## D

- **DaemonSet** â€” A workload that runs one pod per node (log shippers, node
  exporters, CNI agents).
- **Deployment** â€” A Kubernetes workload that manages a replicated, rolling-updated
  set of stateless pods.
- **DevEx / DX (Developer Experience)** â€” How it *feels* to build, ship, and operate
  software in your organization. A measurable product concern, not a vibe.
- **Distroless** â€” Minimal container base images that contain only your app and its
  runtime deps â€” no shell or package manager â€” shrinking size and attack surface.
- **DORA metrics** â€” Deployment frequency, lead time for changes, change failure
  rate, and time to restore â€” common measures of delivery performance.
- **Drift** â€” When real-world infrastructure diverges from its declared state (in
  Terraform or Git). GitOps and drift detection catch it.

## E

- **eBPF** â€” A Linux kernel technology for safely running sandboxed programs in the
  kernel; the basis for Cilium networking and observability (Hubble).
- **Error budget** â€” The allowed amount of unreliability under an SLO
  (`100% âˆ’ SLO target`). Spending it too fast triggers alerts and change freezes.
- **ESO (External Secrets Operator)** â€” Syncs secrets from an external store (e.g.
  Vault, GCP Secret Manager) into Kubernetes Secrets.

## F

- **Falco** â€” A runtime security tool that detects anomalous behavior in
  containers and nodes via kernel events.
- **FinOps** â€” The practice of bringing financial accountability to cloud spend:
  inform, optimize, operate. Attributing and optimizing platform cost.
- **Four golden signals** â€” Latency, traffic, errors, saturation â€” Google SRE's
  recommended service signals.

## G

- **Gateway API** â€” The successor to Ingress: a richer, role-oriented Kubernetes
  API for managing traffic into and within a cluster.
- **GitOps** â€” Using Git as the single source of truth for declarative
  infrastructure, with an agent continuously reconciling the cluster toward it.
- **Golden path (paved road)** â€” The recommended, supported, opinionated way to do
  something (scaffold a service, ship to prod) that makes the easy way the right
  way.
- **Grafana** â€” A visualization, dashboarding, and alerting tool that sits on top of
  metrics, logs, and traces.

## H

- **Helm** â€” A package manager for Kubernetes: templated, versioned, distributable
  "charts."
- **HPA (Horizontal Pod Autoscaler)** â€” Scales the number of pod replicas based on
  CPU, memory, or custom metrics.
- **Hubble** â€” Cilium's network observability layer, built on eBPF.

## I

- **IaC (Infrastructure as Code)** â€” Managing infrastructure through
  version-controlled, declarative definitions (e.g. Terraform).
- **IDP (Internal Developer Platform)** â€” The self-service product a platform team
  builds so stream-aligned teams can ship without filing tickets. (Not to be
  confused with *Identity Provider*.)
- **Idempotency** â€” Applying the same operation repeatedly yields the same result â€”
  essential for safe, re-runnable automation.
- **Ingress** â€” The older Kubernetes API for exposing HTTP(S) services; largely
  superseded by the Gateway API.

## J

- **Jobs to be Done (JTBD)** â€” A framing that focuses on the outcome a user is
  "hiring" a product to achieve, rather than the product's features. Useful for
  platform product thinking.

## K

- **KEDA** â€” Event-driven autoscaling for Kubernetes (scale on queue depth, Pub/Sub,
  cron, etc.).
- **kind / k3d** â€” Tools to run local Kubernetes clusters in Docker, used for
  cost-free labs.
- **kubectl** â€” The Kubernetes command-line client.
- **Kustomize** â€” Template-free Kubernetes configuration management via bases and
  overlays; built into `kubectl -k`.
- **Kyverno** â€” A Kubernetes-native policy-as-code engine (validate, mutate,
  generate) that uses YAML rather than a separate policy language.

## L

- **LGTM stack** â€” Loki (logs), Grafana (dashboards), Tempo (traces), Mimir/
  Prometheus (metrics) â€” Grafana Labs' observability stack.
- **LimitRange** â€” Per-namespace default and maximum resource constraints for pods
  and containers.
- **Loki** â€” A log aggregation system that indexes labels rather than full text,
  queried with LogQL.

## M

- **Managed resource (Crossplane)** â€” A Kubernetes object that maps directly to a
  single cloud resource.
- **Mental model** â€” A durable, simplified way of reasoning about how something
  works. Each module gives you one.
- **mTLS (mutual TLS)** â€” Both client and server authenticate each other with
  certificates; a building block of zero-trust and service meshes.

## N

- **Namespace (Kubernetes)** â€” A virtual cluster-within-a-cluster used to scope and
  isolate resources, RBAC, and quotas (often per team).
- **NetworkPolicy** â€” A Kubernetes resource that controls allowed traffic between
  pods; a "default-deny" baseline is a security best practice.
- **Node** â€” A worker machine (VM or physical) in a Kubernetes cluster.

## O

- **OCI (Open Container Initiative)** â€” The standards for container images and
  registries. OCI registries can also store Helm charts, SBOMs, and signatures.
- **OIDC (OpenID Connect)** â€” An identity protocol; in CI/CD it enables **keyless**
  cloud auth, removing long-lived credentials.
- **OpenTelemetry (OTel)** â€” The vendor-neutral standard and toolkit for generating
  and collecting metrics, logs, and traces.
- **Operator** â€” A controller plus one or more CRDs that encodes operational
  knowledge to manage an application or platform component.

## P

- **PDB (Pod Disruption Budget)** â€” Limits how many pods of a workload can be down
  during voluntary disruptions (e.g. node drains).
- **Platform engineering** â€” The discipline of building and operating internal
  products (platforms) that enable software teams to deliver with lower cognitive
  load. The subject of this course.
- **Pod** â€” The smallest deployable unit in Kubernetes: one or more containers that
  share network and storage.
- **Prometheus** â€” A metrics system that scrapes, stores, and queries time-series
  data with PromQL.
- **PromQL** â€” Prometheus's query language.
- **PV / PVC** â€” PersistentVolume (a piece of storage) and PersistentVolumeClaim (a
  request for storage) â€” how pods consume durable storage.

## Q

- **QoS class** â€” A pod's Quality of Service (Guaranteed, Burstable, BestEffort),
  derived from its requests/limits, affecting eviction order.
- **Quota (ResourceQuota)** â€” A per-namespace cap on total resource consumption,
  preventing one team from starving the cluster.

## R

- **RBAC (Role-Based Access Control)** â€” Kubernetes authorization: Roles define what
  can be done; RoleBindings bind them to subjects (users, groups, service
  accounts).
- **RED method** â€” Rate, Errors, Duration â€” a service-focused monitoring method.
- **Reconciliation loop** â€” The continuous "observe â†’ diff â†’ act" cycle that drives
  controllers, operators, and GitOps.
- **RTO / RPO** â€” Recovery Time Objective (how fast you recover) and Recovery Point
  Objective (how much data loss is acceptable) â€” disaster-recovery targets.
- **Runbook** â€” Step-by-step operational instructions for handling a specific
  situation; every alert should link to one.

## S

- **SBOM (Software Bill of Materials)** â€” A machine-readable inventory of everything
  in an artifact; a supply-chain security staple.
- **Sealed Secrets** â€” Encrypts secrets so they can be safely committed to Git and
  decrypted only in-cluster.
- **Service (Kubernetes)** â€” A stable virtual endpoint (ClusterIP, NodePort,
  LoadBalancer, or Headless) that load-balances to a set of pods.
- **Sidecar** â€” A helper container running alongside the main app container in a pod
  (e.g. a proxy or log shipper).
- **Sigstore** â€” A project for signing, verifying, and proving the provenance of
  software artifacts (includes Cosign).
- **SLI / SLO / SLA** â€” Service Level Indicator (the measured metric), Objective (the
  internal target), Agreement (the external, often contractual, commitment).
- **SLSA** â€” "Supply-chain Levels for Software Artifacts," a framework of
  increasing supply-chain integrity guarantees.
- **SPACE framework** â€” A multi-dimensional way to measure developer productivity:
  Satisfaction, Performance, Activity, Communication, Efficiency.
- **SRE (Site Reliability Engineering)** â€” Operating systems reliably using
  software-engineering practices, SLOs, and error budgets.
- **StatefulSet** â€” A workload for stateful apps: stable network identity, ordered
  operations, and per-pod persistent storage.
- **Stream-aligned team** â€” A team aligned to a flow of work (a product or service);
  the platform team's primary customer. (From *Team Topologies*.)
- **Supply chain security** â€” Securing everything that goes into building and
  shipping software: dependencies, builds, signatures, and provenance.

## T

- **Taint / toleration** â€” Taints repel pods from nodes; tolerations let specific
  pods be scheduled there anyway.
- **Team Topologies** â€” A model of four team types (stream-aligned, platform,
  enabling, complicated-subsystem) and three interaction modes.
- **Tempo** â€” A distributed tracing backend, queried with TraceQL.
- **Terraform** â€” A declarative IaC tool for provisioning cloud infrastructure.
- **Terratest** â€” A Go library for writing automated tests against Terraform and
  other infrastructure.
- **Thinnest Viable Platform (TVP)** â€” Start with the smallest platform that
  provides value and grow it by real developer demand â€” not a big up-front build.
- **Trivy** â€” A scanner for vulnerabilities, misconfigurations, and secrets in
  images, filesystems, and IaC.

## U

- **USE method** â€” Utilization, Saturation, Errors â€” a resource-focused monitoring
  method (complements RED).

## V

- **Vault (HashiCorp)** â€” A secrets-management system for storing and dynamically
  issuing secrets and credentials.
- **VPA (Vertical Pod Autoscaler)** â€” Recommends or sets right-sized CPU/memory
  requests for pods based on observed usage.

## W

- **Workload Identity Federation** â€” Lets external identities (e.g. GitHub Actions
  via OIDC) assume cloud permissions without long-lived keys.

## Z

- **Zero trust** â€” A security model that trusts no network location by default and
  verifies every request (identity, policy, mTLS).

---

> Missing a term you expected? Contributions to this glossary are especially
> welcome â€” see [CONTRIBUTING.md](../CONTRIBUTING.md).
