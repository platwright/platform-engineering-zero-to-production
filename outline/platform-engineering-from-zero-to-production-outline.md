# Platform Engineering — From Zero to Production

> A practical, self-paced GitHub course for engineers who want to build
> and operate Internal Developer Platforms, production Kubernetes
> platforms, and the tooling and culture that lets software teams move
> fast without accumulating operational debt.

---

# 1. Course Vision

This repository is designed for software engineers, DevOps engineers,
SREs and cloud engineers who want to become Platform Engineers — people
who build the foundations other teams build on.

The course follows this progression:

```text
Platform Foundations
        ↓
Containerization
        ↓
Kubernetes Fundamentals
        ↓
Infrastructure as Code
        ↓
CI/CD for Platform Teams
        ↓
Kubernetes Package Management
        ↓
GitOps
        ↓
Kubernetes Advanced (Operators, CRDs, Webhooks)
        ↓
Observability Engineering
        ↓
Security and Policy Engineering
        ↓
Kubernetes Networking
        ↓
Developer Experience and IDP
        ↓
Platform SRE
        ↓
FinOps and Cost Engineering
        ↓
Multi-Cluster and Multi-Cloud
        ↓
Advanced Platform Topics
        ↓
Capstone Platform Systems
```

The central principle is:

> Understand the problem first. Build the smallest solution yourself.
> Then use the production tool. Know why every component exists.

Platform engineers who only know the tools without understanding the
underlying problems make fragile platforms.

---

# 2. Target Audience

Primary audience:

- Software engineers moving into platform roles
- DevOps engineers formalizing platform engineering practices
- SREs building internal platforms
- Cloud engineers moving into developer-facing platform work
- Infrastructure engineers building self-service systems
- Technical leads evaluating platform engineering adoption
- Senior engineers building engineering effectiveness programs

The course assumes:

```text
Comfortable with Linux command line
Basic Git and GitHub
Basic Python or another scripting language
Basic cloud concepts
No prior Kubernetes or platform engineering required
```

---

# 3. Target Outcomes

After completing the course, a learner should be able to:

### Platform Fundamentals

- Explain what platform engineering is and how it differs from DevOps and SRE.
- Apply product thinking to an internal developer platform.
- Design a thinnest viable platform and grow it incrementally.
- Measure developer experience and platform effectiveness.
- Design team topologies appropriate for platform organizations.

### Containers and Kubernetes

- Build minimal, secure, multi-stage container images.
- Operate production Kubernetes clusters.
- Debug Kubernetes workloads confidently.
- Manage RBAC, resource quotas, network policies and security contexts.
- Build Kubernetes operators, CRDs and admission webhooks.

### Infrastructure as Code

- Write, test, and operate Terraform at scale.
- Build Terraform module libraries.
- Use Crossplane for Kubernetes-native infrastructure provisioning.
- Prevent infrastructure drift and enforce IaC governance.

### GitOps

- Design multi-environment GitOps workflows.
- Operate ArgoCD including ApplicationSets and multi-cluster patterns.
- Manage secrets safely in a GitOps model.

### Observability

- Instrument platforms with OpenTelemetry.
- Build a complete metrics, logging and tracing stack.
- Define and alert on SLOs and error budgets.
- Design dashboards that platform teams and their customers can use.

### Security

- Apply policy as code using Kyverno.
- Manage secrets with External Secrets Operator and Vault.
- Implement supply chain security with SLSA, SBOMs and Sigstore.
- Enforce runtime security with Falco.

### Networking

- Design and troubleshoot Kubernetes networking.
- Operate Cilium with eBPF-based policy and observability.
- Configure Kubernetes Gateway API for production traffic.

### Developer Experience

- Build an Internal Developer Platform with Backstage.
- Design and deliver golden paths.
- Build platform CLI tools.
- Deliver self-service infrastructure to development teams.

### Platform Operations

- Define SLOs for platform services.
- Run GameDays and chaos experiments.
- Operate multi-cluster Kubernetes fleets.
- Design disaster recovery for platform infrastructure.
- Attribute and optimize platform costs.

---

# 4. Recommended Technology Stack

The repository avoids tool sprawl. One primary tool per problem.

### Foundation

```text
Python           — automation, scripts, platform tooling
Go               — operators, platform CLI tools
Linux            — all labs run on Linux
Bash             — operational scripts and CI steps
```

### Containers

```text
Docker / BuildKit        — container builds
Docker Compose           — local development environments
crane / skopeo           — image operations without a daemon
```

### Kubernetes

```text
Kubernetes (GKE)         — primary cluster platform
kubectl                  — cluster operations
kustomize                — Kubernetes configuration
Helm                     — package management
kind / k3d               — local development clusters
```

### Infrastructure as Code

```text
Terraform                — cloud infrastructure provisioning
Crossplane               — Kubernetes-native infrastructure
tfsec / Checkov          — IaC security scanning
Terratest                — IaC testing
```

### GitOps

```text
ArgoCD                   — primary GitOps engine
Sealed Secrets / ESO     — secrets in GitOps
```

### CI/CD

```text
GitHub Actions           — primary CI/CD platform
OIDC (keyless auth)      — no long-lived cloud credentials in CI
```

### Observability

```text
OpenTelemetry            — instrumentation and collection
Prometheus               — metrics
Loki                     — logs
Tempo                    — distributed traces
Grafana                  — visualization, alerting, on-call
Alertmanager             — alert routing
```

### Security

```text
Kyverno                  — policy as code
External Secrets Operator — secret management
HashiCorp Vault          — secret store
Cosign / Sigstore        — image signing and verification
Falco                    — runtime security
OPA (reference)          — policy as code alternative
```

### Networking

```text
Cilium                   — CNI, eBPF networking, network policy
Hubble                   — network observability (Cilium)
Kubernetes Gateway API   — ingress and traffic management
```

### Developer Platform

```text
Backstage                — internal developer portal
Cobra + Viper (Go)       — platform CLI framework
MkDocs                   — TechDocs (via Backstage)
```

### Cloud

```text
Google Cloud (GKE, GCS, GCR, Secret Manager)    — primary
AWS / Azure                                      — optional references
Terraform Google provider                        — cloud IaC
```

---

# 5. Repository Philosophy

Every module follows the same structure:

```text
Concept
  ↓
Why it matters for platform engineering
  ↓
Mental model
  ↓
Minimal implementation
  ↓
Hands-on lab
  ↓
Production considerations
  ↓
Common mistakes
  ↓
Assessment
  ↓
Further reading
```

Avoid:

- Tool-first teaching without explaining the problem being solved
- Configuration copy-paste without understanding the parameters
- Pretending that `kubectl apply` equals platform engineering
- Treating Backstage as the definition of platform engineering
- Skipping security and cost until "later" (they are structural, not bolt-on)
- Single-environment labs that do not reflect real-world complexity
- "It works on my laptop" labs with no production consideration

The platform must be a product. Engineers who build platforms without
product thinking build platforms that nobody uses.

---

# 6. Repository Structure

Recommended name:

```text
platform-engineering-from-zero-to-production
```

```text
platform-engineering-from-zero-to-production/
│
├── README.md
├── ROADMAP.md
├── CONTRIBUTING.md
├── LICENSE
├── SECURITY.md
├── CODE_OF_CONDUCT.md
├── CHANGELOG.md
│
├── 00-orientation/
│   ├── README.md
│   ├── learning-path.md
│   ├── prerequisites.md
│   ├── environment-setup.md
│   ├── cloud-account-setup.md
│   └── glossary.md
│
├── 01-platform-foundations/
│   ├── 01-what-is-platform-engineering/
│   ├── 02-platform-as-a-product/
│   ├── 03-developer-experience/
│   ├── 04-the-internal-developer-platform/
│   └── 05-platform-team-topology/
│
├── 02-containerization/
│   ├── 01-container-fundamentals/
│   ├── 02-dockerfile-and-image-building/
│   ├── 03-container-networking/
│   ├── 04-container-storage/
│   ├── 05-container-security/
│   ├── 06-container-registries/
│   └── 07-multi-stage-builds-and-optimization/
│
├── 03-kubernetes-fundamentals/
│   ├── 01-kubernetes-architecture/
│   ├── 02-workloads/
│   ├── 03-services-and-networking/
│   ├── 04-configuration/
│   ├── 05-storage/
│   ├── 06-rbac/
│   ├── 07-resource-management/
│   ├── 08-health-and-scheduling/
│   └── 09-debugging-and-troubleshooting/
│
├── 04-platform-project-01/
│   └── container-platform-foundation/
│
├── 05-infrastructure-as-code/
│   ├── 01-iac-principles/
│   ├── 02-terraform-fundamentals/
│   ├── 03-terraform-state-management/
│   ├── 04-terraform-modules/
│   ├── 05-terraform-testing-and-quality/
│   ├── 06-crossplane/
│   └── 07-iac-patterns-for-platform-teams/
│
├── 06-cicd-for-platform-teams/
│   ├── 01-cicd-fundamentals-for-platform/
│   ├── 02-github-actions-deep-dive/
│   ├── 03-reusable-workflows-and-actions/
│   ├── 04-pipeline-templates-as-product/
│   ├── 05-container-build-pipelines/
│   └── 06-iac-pipelines/
│
├── 07-kubernetes-package-management/
│   ├── 01-helm-fundamentals/
│   ├── 02-helm-chart-development/
│   ├── 03-kustomize/
│   ├── 04-helm-vs-kustomize/
│   └── 05-oci-artifacts-and-distribution/
│
├── 08-gitops/
│   ├── 01-gitops-principles/
│   ├── 02-argocd-fundamentals/
│   ├── 03-argocd-applicationsets/
│   ├── 04-multi-environment-gitops/
│   ├── 05-secrets-in-gitops/
│   └── 06-gitops-maturity-model/
│
├── 09-platform-project-02/
│   └── gitops-platform/
│
├── 10-kubernetes-advanced/
│   ├── 01-custom-resource-definitions/
│   ├── 02-kubernetes-operators/
│   ├── 03-admission-webhooks/
│   ├── 04-api-extension-patterns/
│   └── 05-multi-cluster-kubernetes/
│
├── 11-observability-engineering/
│   ├── 01-observability-fundamentals/
│   ├── 02-opentelemetry/
│   ├── 03-metrics-with-prometheus/
│   ├── 04-logging-with-loki/
│   ├── 05-distributed-tracing-with-tempo/
│   ├── 06-grafana-dashboards/
│   ├── 07-slos-and-error-budgets/
│   └── 08-platform-observability-strategy/
│
├── 12-platform-project-03/
│   └── observability-platform/
│
├── 13-security-and-policy/
│   ├── 01-security-principles-for-platform-teams/
│   ├── 02-kubernetes-rbac-deep-dive/
│   ├── 03-policy-as-code-with-kyverno/
│   ├── 04-secret-management/
│   ├── 05-supply-chain-security/
│   ├── 06-image-signing-and-verification/
│   ├── 07-runtime-security/
│   └── 08-zero-trust-for-platforms/
│
├── 14-kubernetes-networking/
│   ├── 01-kubernetes-networking-fundamentals/
│   ├── 02-cni-plugins/
│   ├── 03-network-policies/
│   ├── 04-cilium-and-ebpf/
│   ├── 05-kubernetes-gateway-api/
│   └── 06-service-mesh-reference/
│
├── 15-developer-experience-and-idp/
│   ├── 01-idp-architecture/
│   ├── 02-backstage-fundamentals/
│   ├── 03-backstage-software-catalog/
│   ├── 04-backstage-software-templates/
│   ├── 05-backstage-plugins/
│   ├── 06-golden-paths/
│   ├── 07-platform-cli-tools/
│   └── 08-developer-portal-documentation/
│
├── 16-platform-project-04/
│   └── internal-developer-platform/
│
├── 17-platform-sre/
│   ├── 01-platform-sre-fundamentals/
│   ├── 02-platform-slos/
│   ├── 03-platform-incident-management/
│   ├── 04-platform-capacity-planning/
│   ├── 05-chaos-engineering-for-platforms/
│   └── 06-disaster-recovery-for-platform/
│
├── 18-finops-and-cost-engineering/
│   ├── 01-cloud-cost-fundamentals/
│   ├── 02-kubernetes-cost-management/
│   ├── 03-cost-attribution/
│   ├── 04-cost-optimization-patterns/
│   └── 05-finops-culture-and-process/
│
├── 19-multi-cluster-and-multi-cloud/
│   ├── 01-multi-cluster-architecture/
│   ├── 02-fleet-management-with-cluster-api/
│   ├── 03-multi-cloud-platform-patterns/
│   └── 04-global-load-balancing-and-edge/
│
├── 20-advanced-platform-topics/
│   ├── 01-platform-engineering-maturity-model/
│   ├── 02-ai-assisted-platform-engineering/
│   ├── 03-platform-engineering-metrics/
│   └── 04-platform-engineering-culture/
│
├── 21-capstone-projects/
│   ├── 01-production-kubernetes-platform/
│   ├── 02-full-idp-with-backstage/
│   ├── 03-multi-cluster-gitops-platform/
│   └── 04-production-platform-reference-architecture/
│
├── 22-interview-preparation/
│   ├── platform-engineering-fundamentals.md
│   ├── containers-and-kubernetes.md
│   ├── infrastructure-as-code.md
│   ├── gitops.md
│   ├── observability.md
│   ├── security.md
│   ├── networking.md
│   ├── developer-experience.md
│   ├── platform-sre.md
│   ├── finops.md
│   └── system-design.md
│
├── 23-cheat-sheets/
│   ├── platform-engineering-overview.md
│   ├── kubernetes-cheat-sheet.md
│   ├── kubectl-cheat-sheet.md
│   ├── helm-cheat-sheet.md
│   ├── terraform-cheat-sheet.md
│   ├── gitops-cheat-sheet.md
│   ├── argocd-cheat-sheet.md
│   ├── observability-cheat-sheet.md
│   ├── security-cheat-sheet.md
│   ├── networking-cheat-sheet.md
│   ├── idp-cheat-sheet.md
│   ├── finops-cheat-sheet.md
│   └── platform-maturity-model.md
│
├── datasets/
├── notebooks/
├── diagrams/
│   ├── architecture/
│   ├── network/
│   └── platform/
├── scripts/
├── shared/
│   ├── terraform-modules/
│   ├── helm-charts/
│   ├── github-actions/
│   └── scripts/
│
└── .github/
    ├── workflows/
    ├── ISSUE_TEMPLATE/
    └── pull_request_template.md
```

---

# 7. Detailed Curriculum

## Phase 0 — Orientation

## Module 00: How to Use This Course

Teach:

- How the repository is organized
- Recommended learning sequence
- Prerequisites check: Linux, Git, Python, cloud basics
- Local environment setup: Docker, kubectl, kind, Go, Terraform
- Cloud account setup: GCP project, billing, IAM bootstrap
- Estimated effort per module and phase
- How labs are structured and graded
- API key and secret management hygiene

Deliverable:

```text
learning-progress.md
```

Learners track:

```text
[ ] Theory completed
[ ] Lab completed
[ ] Architecture reviewed
[ ] Assessment completed
[ ] Production considerations documented
```

---

# Phase 1 — Platform Engineering Foundations

## Module 01: What Is Platform Engineering?

Topics:

- The cognitive load crisis in software engineering
- How Ops evolved to DevOps and DevOps to Platform Engineering
- Platform Engineering definition: building internal products that enable software teams
- Platform Engineering vs DevOps vs SRE: distinct roles, overlapping skills
- The "Thinnest Viable Platform" principle: start minimal, grow by demand
- CNCF Platform Engineering White Paper concepts
- The Platform Engineering market: CNCF surveys, industry adoption
- Why platforms fail: built without developer feedback, over-engineered, under-adopted

Lab:

Interview three engineers on your team or in your network.
Ask: what is the most painful part of deploying and operating your service?
Document the responses. Identify recurring themes.

This is your first product discovery exercise.

---

## Module 02: Platform as a Product

Topics:

- Product thinking for internal platforms
- The platform team as a service provider, not a gatekeeper
- Internal customers: understanding stream-aligned teams
- Jobs to be Done framework for developer tooling
- Developer journey mapping: from idea to production
- Platform roadmapping driven by developer pain
- Measuring platform success: DORA metrics, adoption rate, NPS, time-to-first-deployment
- Build vs buy decisions for platform components
- The danger of "build it and they will come"

Lab:

Design a one-page Platform Product Brief:

```text
Problem statement
Target developer persona
Key jobs to be done
Three initial platform capabilities
Success metrics
Anti-goals (what the platform will not do)
```

---

## Module 03: Developer Experience

Topics:

- What is Developer Experience (DX)?
- Cognitive load: intrinsic, extraneous, germane
- Measuring DX: SPACE framework, DORA metrics, developer surveys
- Time-to-first-production-deployment as a north-star metric
- Paved roads vs golden paths vs guardrails
- The friction taxonomy: setup friction, deployment friction, operational friction, debugging friction
- Self-service vs ticket-driven operations
- Platform contracts: reliability, interface stability, support

Lab:

Measure "Time to Hello World in Production" for a fictional new team joining your organization.
Document every manual step, ticket, and waiting period.
Identify the top three sources of avoidable friction.

---

## Module 04: The Internal Developer Platform

Topics:

- IDP definition and scope
- The five planes of an IDP: developer control plane, integration and delivery plane, resource plane, monitoring plane, security plane
- IDP reference architecture (Humanitec Platform Orchestrator model)
- Key IDP capabilities: self-service provisioning, environment management, application catalog, deployment automation, secrets management, observability, access control
- Build vs buy: Backstage, Port, Cortex, Compass, custom solutions
- IDP anti-patterns: the portal that wraps a ticket system, the platform that requires a platform team ticket to use
- Platform API as the core product

Architecture considerations:

```text
Developer
  ↓
IDP Portal / CLI / API
  ↓
Platform Orchestration Layer
  ↓
GitOps Engine (ArgoCD)      ← config delivery
IaC Engine (Terraform/XP)  ← resource provisioning
Secrets Manager             ← secrets injection
Observability Platform      ← runtime telemetry
  ↓
Kubernetes Clusters
  ↓
Cloud Resources
```

---

## Module 05: Platform Team Topology

Topics:

- Team Topologies: stream-aligned, platform, enabling, complicated-subsystem
- The platform team as an enabling team: accelerate stream teams, not control them
- Interaction modes: X-as-a-service vs facilitation vs collaboration
- Platform team sizing: one platform engineer per 8–12 developers (heuristic)
- Platform team charter: mission, owned capabilities, support model, SLAs
- Embedded platform engineers vs centralized platform teams
- Avoiding the platform team becoming a bottleneck or a gatekeeper
- Platform team communication: office hours, changelog, roadmap reviews

Deliverable:

Draft a Platform Team Charter:

```text
Team mission
Platform capabilities owned
Out-of-scope capabilities
Support model and SLA
Communication channels
Roadmap process
Success metrics
```

---

# Phase 2 — Containerization

## Module 06: Container Fundamentals

Topics:

- What is a container? The Linux primitives underneath
- Namespaces: pid, net, mnt, uts, ipc, user
- cgroups: resource isolation and limits
- Container vs virtual machine: trade-offs for platform engineers
- OCI Image Specification: layers, manifests, index
- Container lifecycle: create, start, pause, stop, kill, remove
- Container runtime interface (CRI): containerd, CRI-O
- Why containers changed platform engineering

Lab:

```bash
# Manually create a minimal container-like environment using
# Linux namespaces and cgroups without Docker
unshare --fork --pid --net --mount --uts /bin/bash

# Observe namespaces
ls -la /proc/self/ns

# Compare with Docker container
docker run --rm -it alpine sh
```

---

## Module 07: Dockerfile and Image Building

Topics:

- Dockerfile anatomy: FROM, RUN, COPY, ADD, ENV, EXPOSE, CMD, ENTRYPOINT
- Image layers and build cache: why order matters
- Multi-stage builds: builder stage vs runtime stage
- Build arguments (ARG) and build secrets
- .dockerignore: what not to copy
- Base image selection: distroless, alpine, debian-slim
- Image size reduction patterns
- BuildKit: parallel build, inline cache, SSH mounts

Lab:

Build the same application three ways:

```text
Version 1: naive single-stage (large)
Version 2: multi-stage (smaller)
Version 3: distroless runtime (smallest + most secure)
```

Measure and compare:

```text
Image size
Build time
Attack surface (number of binaries/packages)
CVE count from scanner
```

---

## Module 08: Container Networking

Topics:

- Bridge network: default Docker networking
- Host networking: performance vs isolation trade-off
- Overlay networks: multi-host container communication
- Port mapping: `-p host:container`
- Container DNS: embedded resolver
- Network troubleshooting with `nsenter`, `ip`, `ss`

Lab:

```bash
# Create a custom bridge network
docker network create --driver bridge platform-net

# Run two containers and demonstrate DNS resolution
docker run -d --name svc-a --network platform-net nginx
docker run --rm --network platform-net alpine sh -c "nslookup svc-a"
```

---

## Module 09: Container Storage

Topics:

- Ephemeral container filesystem: why state is lost
- Volumes: named, anonymous
- Bind mounts: host path to container
- tmpfs: in-memory filesystem
- Storage drivers: overlay2
- When to use each: local dev vs production

Lab:

Demonstrate data persistence across container restarts using volumes,
and data loss without volumes. Apply to a database container.

---

## Module 10: Container Security

Topics:

- Running as non-root (critical)
- Read-only root filesystem
- Dropping Linux capabilities
- Seccomp profiles: restrict syscall surface
- AppArmor profiles
- No-new-privileges flag
- Distroless and scratch base images
- Image vulnerability scanning: Trivy
- Secrets: never bake into image layers

Lab:

```bash
# Scan a common public image for CVEs
trivy image nginx:latest

# Compare with distroless equivalent
trivy image gcr.io/distroless/static-debian12

# Run container with hardened security context
docker run --rm \
  --user 1000:1000 \
  --read-only \
  --cap-drop ALL \
  --security-opt no-new-privileges \
  --security-opt seccomp=/path/to/profile.json \
  gcr.io/distroless/static-debian12
```

---

## Module 11: Container Registries

Topics:

- Registry concepts: repository, tag, digest
- Public registries: Docker Hub, GCR, ECR, GHCR
- Private registry deployment (Harbor)
- Registry security: image scanning on push, access control
- Image promotion: dev → staging → production with immutable digests
- OCI artifacts: store anything (Helm charts, SBOMs, attestations, Wasm modules) in a registry
- Registry mirroring and caching for air-gapped environments

Lab:

```bash
# Push image to GHCR and GCR
docker build -t ghcr.io/org/my-app:sha-abc123 .
docker push ghcr.io/org/my-app:sha-abc123

# Set up vulnerability scanning on push using Harbor
# Configure image promotion policy: only promote if no critical CVEs
```

---

## Module 12: Multi-Platform Builds and Optimization

Topics:

- Multi-platform builds: linux/amd64 + linux/arm64
- Docker buildx and QEMU emulation
- Remote cache in CI (registry cache, GitHub Actions cache)
- Parallel build stages
- Build attestations (SBOM, provenance) with buildx
- BuildKit remote builders (faster CI)

Lab:

Build a multi-platform image in GitHub Actions and push to GHCR:

```yaml
- name: Build and push
  uses: docker/build-push-action@v5
  with:
    platforms: linux/amd64,linux/arm64
    cache-from: type=gha
    cache-to: type=gha,mode=max
    provenance: true
    sbom: true
```

---

# Phase 3 — Kubernetes Fundamentals

## Module 13: Kubernetes Architecture

Topics:

- Control plane: API Server, etcd, Scheduler, Controller Manager
- Cloud Controller Manager: manages cloud resources (LBs, storage)
- Data plane: kubelet, kube-proxy, Container Runtime (containerd)
- The API server as the center: all components speak to API, not each other
- Kubernetes resource model: objects, spec, status, metadata
- kubectl fundamentals: get, describe, apply, delete, logs, exec
- kubeconfig: contexts, clusters, users
- GKE cluster setup with Terraform

Lab:

```bash
# Set up a local kind cluster
kind create cluster --config kind-config.yaml

# Explore control plane components
kubectl get pods -n kube-system

# Observe the reconciliation loop
kubectl run nginx --image=nginx
kubectl delete pod nginx   # watch it respawn
watch kubectl get pods
```

---

## Module 14: Kubernetes Workloads

Topics:

- Pod: the atomic unit, not usually created directly
- Deployment: desired state, ReplicaSet management, rolling update, rollback
- StatefulSet: stable network identity, ordered operations, persistent storage
- DaemonSet: one pod per node, use cases (log agents, node exporters)
- Job: run-to-completion, parallel jobs
- CronJob: scheduled Jobs
- Pod spec deep dive: containers, init containers, volumes, resources, probes

Lab:

```bash
# Deploy a web application with a Deployment
kubectl create deployment web --image=nginx --replicas=3

# Perform a rolling update
kubectl set image deployment/web nginx=nginx:1.25

# Observe rollout status
kubectl rollout status deployment/web

# Rollback
kubectl rollout undo deployment/web

# Deploy a StatefulSet and observe stable identity
kubectl apply -f statefulset.yaml
```

---

## Module 15: Kubernetes Services and Networking

Topics:

- ClusterIP: internal service, stable virtual IP
- NodePort: expose on every node port
- LoadBalancer: cloud provider LB provisioning
- Headless Service: direct pod DNS, used by StatefulSets
- Endpoints and EndpointSlices
- DNS in Kubernetes: `service.namespace.svc.cluster.local`
- kube-proxy modes: iptables, ipvs, eBPF (Cilium)
- ExternalName services for external dependencies

Lab:

```bash
# Deploy frontend + backend
kubectl apply -f backend-deployment.yaml
kubectl apply -f backend-service.yaml

# Verify DNS resolution
kubectl run -it test --image=alpine --restart=Never -- nslookup backend.default.svc.cluster.local

# Test service discovery
kubectl exec -it frontend -- curl http://backend/health
```

---

## Module 16: Kubernetes Configuration

Topics:

- ConfigMap: non-sensitive configuration
- Secrets: base64-encoded (not encrypted at rest by default)
- Consuming config: environment variables, volume mounts, envFrom
- Configuration management patterns: one ConfigMap per service, shared ConfigMaps
- Immutable ConfigMaps and Secrets
- Kubernetes Secrets encryption at rest (KMS plugin)

Lab:

```bash
# Create ConfigMap from file and literal
kubectl create configmap app-config \
  --from-file=config.yaml \
  --from-literal=LOG_LEVEL=info

# Mount as volume and as environment variable
# Demonstrate hot reload when ConfigMap is updated
```

---

## Module 17: Kubernetes Storage

Topics:

- PersistentVolume (PV): a piece of storage in the cluster
- PersistentVolumeClaim (PVC): a request for storage
- StorageClass: dynamic provisioning
- Access modes: ReadWriteOnce, ReadOnlyMany, ReadWriteMany, ReadWriteOncePod
- Volume expansion
- CSI drivers: the plugin interface for storage
- StatefulSet storage patterns

Lab:

```bash
# Create a StorageClass for GKE
# Deploy a StatefulSet with PVC template
# Write data, delete pod, verify data survives
# Expand the volume without downtime
kubectl patch pvc my-pvc -p '{"spec":{"resources":{"requests":{"storage":"20Gi"}}}}'
```

---

## Module 18: Kubernetes RBAC

Topics:

- Subjects: Users, Groups, ServiceAccounts
- Role and ClusterRole: what can be done
- RoleBinding and ClusterRoleBinding: who can do it, where
- Principle of least privilege in Kubernetes
- Namespace-scoped vs cluster-scoped resources
- RBAC design patterns: read-only audit roles, namespace-owner roles, CI/CD service accounts
- Common RBAC mistakes: overbroad wildcards, default service account misuse
- RBAC testing with `kubectl auth can-i`

Lab:

```bash
# Create a CI/CD service account with minimum required permissions
kubectl create serviceaccount cicd-deployer -n my-app

# Create a role: deploy-only to specific namespace
kubectl apply -f cicd-role.yaml
kubectl apply -f cicd-rolebinding.yaml

# Verify
kubectl auth can-i create deployments --as=system:serviceaccount:my-app:cicd-deployer -n my-app
kubectl auth can-i delete namespaces --as=system:serviceaccount:my-app:cicd-deployer
```

---

## Module 19: Resource Management

Topics:

- Resource requests: what the scheduler uses to place pods
- Resource limits: what the kernel enforces at runtime
- LimitRange: default and maximum constraints per namespace
- ResourceQuota: total resource budget per namespace
- Quality of Service classes: Guaranteed, Burstable, BestEffort
- Horizontal Pod Autoscaler (HPA): scale on CPU/memory/custom metrics
- Vertical Pod Autoscaler (VPA): right-size containers
- KEDA: event-driven autoscaling (queue depth, Pub/Sub, cron)
- Cluster Autoscaler and Karpenter: node-level scaling

Lab:

```bash
# Apply a LimitRange to a namespace
# Apply a ResourceQuota to prevent one team consuming all cluster resources
# Deploy HPA and generate load to trigger scaling
kubectl autoscale deployment web --cpu-percent=50 --min=2 --max=10

# Observe autoscaling events
kubectl get events --sort-by=.lastTimestamp
```

---

## Module 20: Health, Probes and Scheduling

Topics:

- Liveness probe: restart the container if unhealthy
- Readiness probe: remove from service endpoints if not ready
- Startup probe: give slow-starting containers time
- Probe types: HTTP, TCP, exec, gRPC
- Node selectors: simple node selection
- Node affinity and anti-affinity: preferred vs required
- Pod affinity and anti-affinity: co-location vs spread
- Taints and tolerations: repel pods from nodes
- Pod Disruption Budgets: protect availability during voluntary disruptions
- Priority Classes: guarantee critical workloads get resources

Lab:

```bash
# Deploy application with all three probes configured
# Demonstrate liveness failure causing restart
# Demonstrate readiness failure removing pod from service
# Apply PodDisruptionBudget and test with node drain
kubectl drain node-1 --ignore-daemonsets --delete-emptydir-data
```

---

## Module 21: Kubernetes Debugging and Troubleshooting

Topics:

- Debugging workflow: describe → events → logs → exec
- `kubectl describe`: reading events and conditions
- Container logs: multi-container pods, previous container logs
- `kubectl exec`: shell into a running container
- Ephemeral debug containers (`kubectl debug`)
- Port-forward for local debugging
- Common failure patterns:
  - CrashLoopBackOff: container starts and exits repeatedly
  - ImagePullBackOff: registry auth or image not found
  - OOMKilled: exceeded memory limit
  - Pending: scheduling failure (resource, affinity, taint)
  - Evicted: node pressure eviction

Lab:

Provide five pre-broken Kubernetes manifests. Learner must diagnose and fix each:

```text
Failure 1: OOMKilled — limits too low
Failure 2: ImagePullBackOff — wrong image name
Failure 3: Pending — missing toleration for tainted node
Failure 4: CrashLoopBackOff — missing required env var
Failure 5: Not routable — incorrect label selector on Service
```

---

# 8. Major Project

# Project 1 — Container Platform Foundation

Goal:

Build a production-grade Kubernetes cluster foundation on GKE with
all the baseline platform capabilities a team needs to start deploying
services safely.

Architecture:

```text
GitHub
  ↓
GitHub Actions (CI)
  ↓
Build → Scan → Sign → Push
  ↓
GHCR / GCR
  ↓
GKE Cluster (Terraform)
  ↓
Namespaces: platform-system, team-a, team-b
RBAC: per-namespace roles + CI service accounts
LimitRanges + ResourceQuotas per namespace
Cilium CNI
External Secrets Operator
Container Registry with image scanning
```

Requirements:

- Terraform provisions GKE cluster, VPC, node pools, GCS for state
- Namespaces with RBAC for 3 teams
- LimitRanges and ResourceQuotas per team namespace
- CI pipeline: build → Trivy scan → Cosign sign → push to GHCR
- Deployment blocked if critical CVEs found
- Non-root, read-only containers enforced by Kyverno policy
- Secrets managed via External Secrets Operator + GCP Secret Manager

Stretch goals:

- Karpenter for node auto-provisioning
- Cluster upgrade automation
- Prometheus basic cluster monitoring

---

# Phase 4 — Infrastructure as Code

## Module 22: IaC Principles

Topics:

- IaC definition: infrastructure described as code in version control
- Declarative vs imperative IaC
- Idempotency: applying the same config repeatedly gives the same result
- State: what IaC tools use to track real-world resource state
- Drift detection: production diverges from IaC definition
- IaC lifecycle: write → plan → apply → review → destroy
- Configuration Management (Ansible) vs IaC (Terraform): complementary, not competing
- When IaC is not appropriate: one-off explorations, prototype environments

---

## Module 23: Terraform Fundamentals

Topics:

- Providers, resources, data sources
- Variables, locals, outputs
- Resource dependencies: implicit and explicit
- `terraform init`, `plan`, `apply`, `destroy`
- `terraform show`, `terraform state list`
- Meta-arguments: count, for_each, depends_on, lifecycle
- The `null_resource` and `terraform_data` for local operations

Lab:

```hcl
# Provision a GKE cluster with Terraform
terraform {
  required_providers {
    google = { source = "hashicorp/google", version = "~> 5.0" }
  }
}

resource "google_container_cluster" "platform" {
  name     = "platform-cluster"
  location = var.region
  # ...
}
```

---

## Module 24: Terraform State Management

Topics:

- Local state vs remote state
- Remote backends: GCS, S3, Terraform Cloud
- State locking: prevent concurrent modifications
- State inspection: `terraform state list`, `terraform state show`
- State manipulation: `terraform state mv`, `terraform state rm`
- State migration between backends
- Workspaces: one state per environment (dev/staging/prod)
- Blast radius management through state isolation

Lab:

```bash
# Configure GCS remote backend
# Demonstrate state locking with concurrent applies
# Move a resource between state files
terraform state mv google_container_cluster.old google_container_cluster.new
```

---

## Module 25: Terraform Modules

Topics:

- Module structure: variables.tf, outputs.tf, main.tf
- Root modules vs child modules
- Module composition: composing from smaller modules
- Published modules: Terraform Registry
- Internal module library: versioning with Git tags
- Module interface design: minimal required inputs, sensible defaults

Lab:

Build an internal GKE module library:

```text
modules/
├── gke-cluster/
├── gke-node-pool/
├── vpc/
├── gcs-bucket/
└── secret-manager-secret/
```

Then compose:

```text
environments/
├── dev/
│   └── main.tf  (calls internal modules)
└── prod/
    └── main.tf
```

---

## Module 26: Terraform Testing and Quality

Topics:

- `terraform fmt` and `terraform validate`
- `tfsec` and `Checkov`: static security scanning
- OPA / Conftest for Terraform plan policy
- Terratest: Go-based integration tests for Terraform
- Contract testing: test module interface only, not implementation
- PR checks: plan on PR, apply on merge (enforced)

Lab:

```go
// Terratest example: verify GKE cluster is created
func TestGKECluster(t *testing.T) {
    opts := &terraform.Options{TerraformDir: "../modules/gke-cluster"}
    defer terraform.Destroy(t, opts)
    terraform.InitAndApply(t, opts)

    clusterName := terraform.Output(t, opts, "cluster_name")
    assert.NotEmpty(t, clusterName)
}
```

---

## Module 27: Crossplane

Topics:

- Crossplane concept: bring cloud resource management into Kubernetes
- Managed Resources: direct Kubernetes-to-cloud resource mapping
- Composite Resources (XR) and XRDs: custom abstractions over multiple managed resources
- Compositions: define how XRs are implemented
- Provider configuration
- Self-service infrastructure via `kubectl apply`
- Crossplane vs Terraform: complementary use cases
- When Crossplane shines: self-service databases, developer namespaces, environments

Lab:

```yaml
# Developer requests a database via XR
apiVersion: platform.example.com/v1alpha1
kind: PostgreSQLInstance
metadata:
  name: my-app-db
spec:
  parameters:
    storageGB: 20
    version: "15"
  compositionSelector:
    matchLabels:
      environment: production
```

```bash
# Platform team implements Composition
kubectl apply -f composition-postgresql.yaml

# Developer self-provisions:
kubectl apply -f my-app-db.yaml
```

---

## Module 28: IaC Patterns for Platform Teams

Topics:

- DRY IaC: when to abstract, when not to
- Environment promotion patterns: dev → staging → prod
- Blast radius management: separate states per environment, per team
- IaC governance: mandatory PR reviews, no manual cloud console changes
- Drift detection: scheduled pipeline compares plan to live state
- Bootstrapping new environments: automation from account creation to cluster
- IaC module versioning: pin module versions, upgrade deliberately

Architecture:

```text
IaC Mono-repo
├── modules/          ← reusable, versioned modules
├── environments/
│   ├── dev/          ← applies modules with dev vars
│   ├── staging/      ← applies modules with staging vars
│   └── prod/         ← applies modules with prod vars
└── .github/workflows/
    ├── plan.yaml     ← runs on PR
    └── apply.yaml    ← runs on merge to main
```

---

# Phase 5 — CI/CD for Platform Teams

## Module 29: CI/CD Fundamentals for Platform Teams

Topics:

- Platform CI/CD is different from application CI/CD
- Three types of platform pipelines: infrastructure, configuration, validation
- Infrastructure pipelines: Terraform plan/apply
- Configuration pipelines: Helm chart lint/test/package/push
- Validation pipelines: policy checks, drift detection, security scans
- Pipeline failure philosophy: fail fast, fail loud, never silently skip
- Change review requirements for platform changes vs application changes

---

## Module 30: GitHub Actions Deep Dive

Topics:

- Workflow anatomy: triggers, jobs, steps, runners
- Event triggers: push, pull_request, workflow_dispatch, schedule
- Contexts: github, env, vars, secrets, runner, job, steps
- Environment protection rules: required reviewers, deployment gates
- OIDC (OpenID Connect): keyless cloud authentication — no long-lived secrets
- GitHub Environments: dev, staging, production gates
- Concurrency groups: prevent parallel runs on the same environment
- Self-hosted runners: when and why

Lab:

```yaml
# Keyless GCP authentication from GitHub Actions
permissions:
  id-token: write
  contents: read

steps:
  - name: Auth GCP
    uses: google-github-actions/auth@v2
    with:
      workload_identity_provider: projects/123/locations/global/workloadIdentityPools/github/providers/github
      service_account: github-actions@project.iam.gserviceaccount.com
```

---

## Module 31: Reusable Workflows and Composite Actions

Topics:

- Composite actions: combine multiple steps, share across workflows
- Reusable workflows: call from other workflows with `workflow_call`
- Input and output parameters for reusable workflows
- Versioning composite actions (GitHub releases)
- Central action registry: one repository for all shared actions
- When to build custom actions vs use community actions
- Security considerations: pinning action versions by SHA

Lab:

Build a shared action library:

```text
.github/actions/
├── build-and-push/
│   └── action.yaml   ← composite: build, scan, sign, push
├── terraform-plan/
│   └── action.yaml
└── deploy-helm/
    └── action.yaml
```

---

## Module 32: Pipeline Templates as a Platform Product

Topics:

- The platform team owns the pipeline templates
- Developers consume templates, not write pipelines from scratch
- Template versioning and migration path
- Enforcement: require platform pipeline template for production deployments
- Escape hatches: how teams override templates for legitimate reasons
- Template adoption metrics: what percentage of teams use the golden path pipeline?

Lab:

Build a reusable workflow that all application teams consume:

```yaml
# Called from application repositories
jobs:
  ci:
    uses: platform-org/platform-workflows/.github/workflows/app-ci.yaml@v2
    with:
      dockerfile-path: ./Dockerfile
      image-name: my-app
    secrets: inherit
```

---

## Module 33: Container Build Pipelines

Topics:

- Build pipeline stages: lint → test → build → scan → sign → push
- Layer caching in CI: registry cache, GHA cache
- Multi-arch builds in CI: linux/amd64 + linux/arm64
- Vulnerability gate: block on critical CVEs (Trivy)
- SBOM generation as a pipeline artifact
- Image signing with Cosign in CI (keyless via OIDC)
- Image promotion by digest: same image from dev to production, immutable

Lab:

```yaml
# Full container CI pipeline
- name: Run Trivy vulnerability scan
  uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ env.IMAGE }}
    exit-code: '1'
    severity: 'CRITICAL'

- name: Sign image with Cosign
  run: |
    cosign sign --yes ${{ env.IMAGE }}@${{ steps.build.outputs.digest }}
```

---

## Module 34: IaC Pipelines

Topics:

- Terraform plan on pull request: comment plan output in PR
- Terraform apply on merge: automatic, gated by required reviews
- Atlantis: pull-request-based Terraform workflow
- Drift detection: scheduled workflow, alert if plan is non-empty
- Per-environment approval gates in GitHub Environments
- Handling Terraform state conflicts in CI
- IaC pipeline security: least-privilege service account, OIDC

Lab:

Build a Terraform CI/CD pipeline:

```text
PR opened:
  terraform fmt --check
  terraform validate
  tfsec .
  checkov -d .
  terraform plan → comment on PR

PR merged:
  terraform apply (auto, for dev)
  terraform apply (manual gate, for prod)

Nightly:
  terraform plan → alert if drift detected
```

---

# Phase 6 — Kubernetes Package Management

## Module 35: Helm Fundamentals

Topics:

- Helm concepts: charts, releases, repositories
- Chart structure: Chart.yaml, values.yaml, templates/
- Helm template functions: toYaml, required, default, include
- helm install, upgrade, rollback, uninstall
- Release history and versioning
- Helm values hierarchy: default values → environment overrides

Lab:

```bash
# Install a chart from a repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  -f prod-values.yaml

# Inspect release
helm history ingress-nginx -n ingress-nginx
```

---

## Module 36: Helm Chart Development

Topics:

- Writing reusable templates with named templates and helpers
- Values schema validation (values.schema.json)
- Helm hooks: pre-install, post-install, pre-upgrade, pre-delete
- `helm test`: smoke tests in a Job
- `helm-unittest`: unit testing templates without a cluster
- Chart packaging and OCI distribution
- Helm chart CI: lint → unit test → package → push

Lab:

Build a platform-standard Helm chart template:

```text
charts/platform-app/
├── Chart.yaml
├── values.yaml
├── values.schema.json
├── templates/
│   ├── _helpers.tpl
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── hpa.yaml
│   ├── pdb.yaml
│   ├── serviceaccount.yaml
│   └── networkpolicy.yaml
└── tests/
    └── deployment_test.yaml
```

---

## Module 37: Kustomize

Topics:

- Kustomize concepts: resources, bases, overlays
- Strategic merge patches: add or modify fields
- JSON patches (RFC 6902): precise modifications
- Kustomize generators: ConfigMapGenerator, SecretGenerator
- Transformers: labels, images, namespaces
- Kustomize in kubectl: `kubectl apply -k`

Lab:

```text
base/
├── deployment.yaml
└── kustomization.yaml

overlays/
├── dev/
│   ├── kustomization.yaml    ← patches image tag, replicas=1
│   └── replica-patch.yaml
└── prod/
    ├── kustomization.yaml    ← patches image tag, replicas=3, adds HPA
    └── hpa.yaml
```

---

## Module 38: Helm vs Kustomize

Teach:

- Helm: templating, packaging, distribution, lifecycle management
- Kustomize: configuration overlays, no templating, declarative
- When Helm wins: distributable charts, parameterized packages
- When Kustomize wins: patching existing manifests, no templating needed
- Combining both: Helm chart base + Kustomize overlay for environment differences
- ArgoCD support for both

Lab:

Deploy the same application using Helm only, Kustomize only, and Helm + Kustomize.
Compare maintainability and cognitive complexity.

---

## Module 39: OCI Artifacts and Distribution

Topics:

- OCI artifacts: everything beyond container images (Helm charts, SBOMs, attestations, Wasm)
- ORAS (OCI Registry as Storage) CLI
- Helm OCI: `helm push`, `helm pull oci://`
- Storing attestations and SBOMs in OCI registries
- Platform artifact distribution patterns

Lab:

```bash
# Package and push Helm chart to OCI registry
helm package ./charts/my-app
helm push my-app-1.0.0.tgz oci://ghcr.io/org/charts

# Pull and deploy
helm install my-app oci://ghcr.io/org/charts/my-app --version 1.0.0
```

---

# Phase 7 — GitOps

## Module 40: GitOps Principles

Topics:

- GitOps definition: Git is the single source of truth for declarative infrastructure
- Four GitOps principles: declarative, versioned, pulled, continuously reconciled
- Push-based vs pull-based delivery: why pull wins for security
- GitOps vs traditional CI/CD: where CI ends and GitOps begins
- Drift detection and self-healing: the cluster converges to Git state
- GitOps for infrastructure (config) vs GitOps for application code
- When GitOps adds complexity without value

Architecture:

```text
Developer
  ↓
PR → Code Review → Merge
  ↓
Config Repository (Git)
  ↓           ← ArgoCD polls, detects diff
ArgoCD
  ↓
Kubernetes Cluster
```

---

## Module 41: ArgoCD Fundamentals

Topics:

- ArgoCD architecture: application controller, repo server, API server, dex
- Application resource: source, destination, sync policy
- Application health: Healthy, Progressing, Degraded, Missing, Unknown
- Sync status: Synced, OutOfSync
- Sync options: prune, self-heal, replace
- Repository types: Git, Helm, OCI
- ArgoCD CLI: `argocd app sync`, `argocd app status`
- RBAC in ArgoCD
- Notifications: Slack, email on sync events

Lab:

```bash
# Install ArgoCD on kind cluster
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create an Application pointing to a Helm chart in Git
argocd app create my-app \
  --repo https://github.com/org/config-repo \
  --path apps/my-app \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace my-app \
  --sync-policy automated
```

---

## Module 42: ArgoCD ApplicationSets

Topics:

- ApplicationSet: generate multiple Applications from a template
- Generators: list, cluster, git (file, directory), matrix, merge
- List generator: explicit list of environments or clusters
- Cluster generator: one Application per registered cluster
- Git file generator: one Application per config file in a directory
- Matrix generator: combine two generators (e.g., services × clusters)
- App of Apps pattern: one Application that creates other Applications

Lab:

```yaml
# ApplicationSet for all apps in a monorepo
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: all-apps
spec:
  generators:
    - git:
        repoURL: https://github.com/org/config-repo
        revision: HEAD
        directories:
          - path: apps/*
  template:
    spec:
      source:
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{path.basename}}'
```

---

## Module 43: Multi-Environment GitOps

Topics:

- Branch vs folder strategy: folder wins for auditability
- Environment promotion workflow: overlay update → PR → review → merge → auto-sync
- Promotion automation: update image tag in config repo from CI
- Sync waves: control order of resource creation (CRDs before CRs, namespace before deployment)
- Rollback in GitOps: revert the Git commit, ArgoCD syncs to previous state
- Rollback across multiple environments: correlate Git history to cluster state

Lab:

```text
config-repo/
├── apps/
│   └── my-app/
│       ├── base/
│       └── overlays/
│           ├── dev/     ← auto-sync, no approval
│           ├── staging/ ← auto-sync after dev passes
│           └── prod/    ← manual sync gate
```

---

## Module 44: Secrets in GitOps

Topics:

- The core problem: secrets must not be in Git in plain text
- Option 1 — Sealed Secrets: encrypt in cluster, store encrypted in Git
- Option 2 — External Secrets Operator (ESO): store in secret manager, sync to K8s
- Option 3 — Vault Agent / CSI driver: mount secrets at pod runtime
- Option 4 — SOPS: encrypt files with KMS key, store in Git
- Recommendation: ESO + GCP Secret Manager (or Vault) for most platforms
- Secret rotation: update in secret manager, ESO propagates to cluster

Lab:

```yaml
# External Secrets Operator: sync from GCP Secret Manager
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: my-app-secret
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: gcp-secrets
    kind: SecretStore
  target:
    name: my-app-secret
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: projects/my-project/secrets/db-url/versions/latest
```

---

## Module 45: GitOps Maturity Model

Teach learners to assess and evolve GitOps practice:

```text
Level 0 — No GitOps
  Manual kubectl apply
  Scripts, runbooks, tribal knowledge
  No audit trail for cluster changes

Level 1 — Manual GitOps
  Config in Git but manual sync
  No self-healing or drift detection
  Some audit trail

Level 2 — Automated GitOps
  Auto-sync enabled
  Self-healing: cluster divergence corrected automatically
  Image updater for simple applications

Level 3 — Full Platform GitOps
  All cluster config managed via GitOps
  Secrets via ESO, not plain-text files
  Multi-environment promotion automation
  Drift alerts and breaking-change detection

Level 4 — Adaptive Platform GitOps
  Progressive delivery integrated (Argo Rollouts / Flagger)
  Cross-cluster GitOps
  Policy evaluation as part of GitOps sync
  Automated cluster bootstrapping
```

---

# 9. Major Project

# Project 2 — GitOps Platform

Goal:

Build a complete multi-environment, multi-team GitOps platform using
ArgoCD with secrets management, promotion automation, and self-healing.

Architecture:

```text
config-repo (Git)
├── platform/          ← ArgoCD, ESO, Kyverno, Cilium
├── apps/
│   ├── team-a/
│   │   └── service-1/
│   │       ├── base/
│   │       └── overlays/dev, staging, prod
│   └── team-b/
│       └── service-2/
│           └── overlays/dev, staging, prod

application-repo (GitHub Actions CI)
  ↓ on merge: update image tag in config-repo via PR
  ↓ PR auto-merged in dev, reviewed in prod

ArgoCD
  ↓ watches config-repo, syncs cluster state
  ↓ sends notifications to Slack on sync events

GCP Secret Manager → ESO → Kubernetes Secrets
```

Requirements:

- App of Apps pattern bootstrapping the entire cluster config
- ApplicationSets for team-a and team-b applications
- ESO + GCP Secret Manager for all secrets
- Promotion pipeline: CI writes image digest to config repo PR
- ArgoCD auto-syncs dev; production requires manual sync gate
- Kyverno policy: only signed images from `ghcr.io/org` allowed

---

# Phase 8 — Kubernetes Advanced

## Module 46: Custom Resource Definitions

Topics:

- Extending the Kubernetes API without modifying core
- CRD anatomy: group, version, kind, schema
- OpenAPI v3 schema validation in CRDs
- CEL (Common Expression Language) validation rules: replace webhooks for simple validation
- CRD versioning: v1alpha1 → v1beta1 → v1
- Conversion webhooks for version migration
- Served vs stored versions
- Status subresource: separate spec write from status write

Lab:

```yaml
# Define a custom resource for a platform team
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: environments.platform.example.com
spec:
  group: platform.example.com
  names:
    kind: Environment
    plural: environments
  scope: Cluster
  versions:
    - name: v1alpha1
      schema:
        openAPIV3Schema:
          properties:
            spec:
              properties:
                team:
                  type: string
                tier:
                  enum: [dev, staging, prod]
                  type: string
```

---

## Module 47: Kubernetes Operators

Topics:

- The Operator pattern: encode human operational knowledge in software
- Controller-runtime: the Go library for building controllers
- Reconciliation loop: observe desired state, observe actual state, reconcile
- Requeue strategies: requeue on error, requeue after interval, watch events
- Status conditions: standard condition types (Ready, Synced, Degraded)
- Owner references: garbage-collect child resources when parent is deleted
- Finalizers: perform cleanup before object deletion
- operator-sdk: scaffolding for operator projects

Lab:

Build a `NamespaceProvisioner` operator:

```go
// When an Environment CR is created:
// 1. Create a namespace
// 2. Create default RBAC
// 3. Apply ResourceQuota
// 4. Apply LimitRange
// 5. Set status conditions

func (r *EnvironmentReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    // Fetch the Environment instance
    env := &platformv1alpha1.Environment{}
    if err := r.Get(ctx, req.NamespacedName, env); err != nil {
        return ctrl.Result{}, client.IgnoreNotFound(err)
    }
    // reconcile namespace, rbac, quota, limitrange
    // update status
}
```

---

## Module 48: Admission Webhooks

Topics:

- MutatingAdmissionWebhook: modify resources before storage
- ValidatingAdmissionWebhook: accept or reject resources
- ValidatingAdmissionPolicy: CEL-based validation without a webhook server
- Webhook server: TLS cert, registration, failure policy
- Common use cases: inject sidecars, enforce labels, set defaults, block non-conforming resources
- Testing admission webhooks: envtest, cert-manager for TLS

Lab:

Build a mutating webhook that automatically injects:

```text
labels:
  platform.example.com/team: <from namespace annotation>
  platform.example.com/cost-center: <from namespace annotation>
```

on every Pod created in team namespaces — without developers needing to set these manually.

---

## Module 49: Kubernetes API Extension Patterns

Topics:

- Aggregated API servers: extend the Kubernetes API with custom API groups
- Subresources: `/status` and `/scale` subresources on CRDs
- Field selectors on custom resources: filter by custom fields
- Webhook vs CEL validation: choose CEL first, webhook only when needed
- Indexers and informers: efficient list and watch in controllers
- Server Side Apply: declarative field management

---

## Module 50: Multi-Cluster Kubernetes

Topics:

- Why multi-cluster: isolation, availability zones, regulatory, team ownership
- Cluster topologies: hub-and-spoke, mesh, hierarchical
- Management cluster pattern: one cluster to manage all others
- Cluster API (CAPI): declarative cluster lifecycle management
- CAPI providers: GKE, EKS, AKS, vSphere
- Fleet management: Rancher Fleet, Argo CD multi-cluster
- Cross-cluster service discovery: Submariner, Istio multi-cluster
- Multi-cluster KubeConfig management

Lab:

```bash
# Bootstrap a management cluster
# Create a workload cluster using Cluster API
kubectl apply -f workload-cluster.yaml

# Register workload cluster in ArgoCD
argocd cluster add workload-cluster

# Deploy an application to all clusters using ApplicationSet
```

---

# Phase 9 — Observability Engineering

## Module 51: Observability Fundamentals

Topics:

- Observability definition: understand system state from external outputs
- Three pillars: metrics, logs, traces
- The difference between monitoring and observability
- OpenTelemetry as the unified observability standard
- RED method: Rate, Errors, Duration (for services)
- USE method: Utilization, Saturation, Errors (for resources)
- Cardinality: why high-cardinality metrics are expensive
- Sampling: why you cannot trace 100% of requests at scale
- The four golden signals (Google SRE): latency, traffic, errors, saturation

---

## Module 52: OpenTelemetry

Topics:

- OTel data model: spans, traces, metrics, logs
- OTel SDK: language-specific instrumentation libraries
- Auto-instrumentation vs manual instrumentation
- OTel Collector: receive, process, export telemetry
- Collector processors: batch, memory limiter, filter, attribute, sampling
- Exporters: OTLP, Prometheus, Loki, Tempo, Jaeger
- Tail-based sampling vs head-based sampling
- OTel Operator for Kubernetes: inject auto-instrumentation

Lab:

```yaml
# Deploy OTel Collector as DaemonSet for node-level metrics
# Deploy OTel Collector as Deployment for trace aggregation

# Instrument a Go service
import "go.opentelemetry.io/otel"

tracer := otel.Tracer("my-service")
ctx, span := tracer.Start(ctx, "process-request")
defer span.End()
```

---

## Module 53: Metrics with Prometheus

Topics:

- Prometheus architecture: scrape, store, query
- Metric types: Counter, Gauge, Histogram, Summary
- PromQL: instant vector, range vector, aggregation
- ServiceMonitor and PodMonitor (Prometheus Operator)
- Recording rules: pre-compute expensive queries
- Remote write: long-term storage (Thanos, Mimir, VictoriaMetrics)
- Prometheus federation
- kube-state-metrics: cluster resource metrics

Lab:

```promql
# Service error rate
rate(http_requests_total{status=~"5.."}[5m])
  /
rate(http_requests_total[5m])

# p99 latency
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))

# Cluster CPU utilization by namespace
sum by (namespace) (rate(container_cpu_usage_seconds_total[5m]))
```

---

## Module 54: Logging with Loki

Topics:

- Loki architecture: Distributor, Ingester, Querier, Compactor
- LogQL: log query language
- Labels: low cardinality (do not use high-cardinality fields as labels)
- Log streams
- Promtail vs OTel log collection
- Structured logging best practices
- Log retention and storage backends (GCS, S3)

Lab:

```logql
# All error logs from a specific service
{namespace="team-a", app="my-service"} |= "ERROR"

# Error rate from log lines
rate({namespace="team-a"} |= "ERROR" [5m])

# Parse structured JSON logs
{app="my-service"} | json | level="error" | line_format "{{.message}}"
```

---

## Module 55: Distributed Tracing with Tempo

Topics:

- Distributed tracing concepts: trace, span, context propagation
- Trace context: W3C TraceContext, B3
- Tempo architecture: Distributor, Ingester, Querier, Compactor
- Querying traces: TraceQL
- Connecting traces to logs (Loki) and metrics (Prometheus): exemplars
- Trace sampling strategies: head-based (probability), tail-based (keep errors)

Lab:

```bash
# Deploy Tempo in microservices mode with GCS backend
# Instrument services with OTel Go SDK
# Query traces in Grafana Explore
# Link a Loki log line to its trace ID
# Link a Prometheus exemplar to a trace
```

---

## Module 56: Grafana Dashboards

Topics:

- Dashboard design principles: one purpose per dashboard, top-down hierarchy
- Variables and templating: dynamic dashboards
- Mixed data sources on one panel
- Alert rules in Grafana
- Contact points and notification policies
- Dashboard as code: Grafonnet (Jsonnet) and Grizzly
- Dashboard versioning in Git

Lab:

Build a Platform Overview Dashboard covering:

```text
Panel 1: Cluster CPU and memory utilization by namespace
Panel 2: Request rate and error rate per service
Panel 3: p50, p95, p99 latency per service
Panel 4: SLO burn rate
Panel 5: Recent deployments (from ArgoCD sync events)
Panel 6: Active incidents
```

Deliver the dashboard as Jsonnet code, not a JSON export.

---

## Module 57: SLOs and Error Budgets

Topics:

- SLI (Service Level Indicator): the measured metric
- SLO (Service Level Objective): the target for the SLI
- SLA (Service Level Agreement): the external commitment (legal)
- Error budget: 100% - SLO target, budget consumed by incidents
- Burn rate alerting: alert when burning budget too fast
- Multi-window, multi-burn-rate alerts (Google SRE alert format)
- SLO tooling: sloth (SLO generator), pyrra (SLO manager)
- Platform team SLO examples

Lab:

Define SLOs for the platform:

```yaml
# Sloth SLO definition
apiVersion: sloth.slok.dev/v1
kind: PrometheusServiceLevel
metadata:
  name: argocd-api
spec:
  service: argocd
  slos:
    - name: availability
      objective: 99.9
      sli:
        events:
          error_query: |
            sum(rate(argocd_app_sync_total{phase="Error"}[{{.window}}]))
          total_query: |
            sum(rate(argocd_app_sync_total[{{.window}}]))
      alerting:
        page_alert:
          labels:
            severity: page
        ticket_alert:
          labels:
            severity: ticket
```

---

## Module 58: Platform Observability Strategy

Topics:

- What to observe for a platform team (different from application teams)
- Golden signals for platform services: ArgoCD, Prometheus, Grafana, ESO
- Observability for GitOps pipelines: sync latency, sync errors, drift events
- Cluster-level signals: node pressure, etcd health, API server latency
- Cross-team observability: platform metrics that all teams see
- Alerting for platform teams: who gets paged and when
- Runbooks linked from every alert

---

# 10. Major Project

# Project 3 — Observability Platform

Goal:

Deploy a production-grade observability platform on Kubernetes, delivered
and managed via GitOps, with SLOs defined for the platform itself.

Architecture:

```text
Applications (instrumented with OTel SDK)
  ↓ OTLP
OTel Collector (DaemonSet + Gateway)
  ↓
┌─────────────────────────────┐
│  Prometheus (metrics)       │
│  Loki (logs)                │
│  Tempo (traces)             │
│  Alertmanager               │
└─────────────────────────────┘
  ↓
Grafana (dashboards, alerts, on-call)
  ↓
GCS (long-term storage for all signals)
```

Requirements:

- Entire stack deployed via ArgoCD (from Project 2)
- OTel Collector deployed as DaemonSet for logs/metrics + Deployment for traces
- Platform Overview Dashboard (from Module 56) in code (Jsonnet)
- SLO defined for ArgoCD, Prometheus, and the API gateway
- Burn rate alert → Slack notification via Alertmanager
- Runbooks for every alert, linked in Alertmanager annotations
- Log retention: 30 days in GCS, Prometheus retention 15d local + Mimir for 1 year

Stretch goals:

- Trace-to-log correlation in Grafana
- Exemplars linking Prometheus metrics to Tempo traces
- Grafana OnCall for on-call schedule management

---

# Phase 10 — Security and Policy Engineering

> Reference: [OWASP Kubernetes Top 10](https://owasp.org/www-project-kubernetes-top-10/)
> and [CIS Kubernetes Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
> provide structured baselines for this phase.

## Module 59: Security Principles for Platform Teams

Topics:

- Defence in depth for Kubernetes: 7 layers
- The platform team owns the security baseline; teams consume it
- Security as a platform capability: not a checklist at the end
- CIS Kubernetes Benchmark: applying and scoring
- OWASP Kubernetes Top 10: RBAC misconfiguration, secret exposure, overprivileged containers
- Zero-trust thinking: assume breach, verify everything, least privilege everywhere

Layers:

```text
1. Cloud IAM and network perimeter
2. Cluster API access control
3. Node security and OS hardening
4. Namespace isolation and RBAC
5. Workload security (Pod Security Standards)
6. Network policies
7. Runtime security
```

---

## Module 60: Kubernetes RBAC Deep Dive

Topics:

- RBAC subjects: ServiceAccount (machine identity), User, Group
- Impersonation: testing RBAC without switching contexts
- Aggregated ClusterRoles: compose roles from smaller roles
- RBAC audit: `rbac-audit`, `KubiScan` for RBAC risk scanning
- Just-in-time access patterns
- Cross-namespace access: when and how to grant it safely
- RBAC for CI/CD: per-namespace ServiceAccount, no cluster-admin in pipelines
- Audit logging: `--audit-policy-file` for the API server

Lab:

```bash
# Audit existing RBAC for overbroad permissions
kubectl get clusterrolebindings -o json | jq '
  .items[]
  | select(.subjects[]?.kind == "ServiceAccount")
  | {name: .metadata.name, subjects: .subjects, role: .roleRef.name}
'

# Use kubectl-who-can to list who can do sensitive actions
kubectl-who-can delete pods --all-namespaces
kubectl-who-can create clusterrolebindings
```

---

## Module 61: Policy as Code with Kyverno

Topics:

- Kyverno vs OPA/Gatekeeper: choose Kyverno for Kubernetes-native syntax
- Policy types: validate, mutate, generate, verify image
- ClusterPolicy vs Policy (namespace-scoped)
- Audit mode vs enforce mode: start in audit, move to enforce
- Policy exceptions: controlled escape hatches
- Policy reports: visibility into violations without blocking
- Background scanning: evaluate policy against existing resources

Lab:

```yaml
# Policy: block non-root containers
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: disallow-root-containers
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-runAsNonRoot
      match:
        any:
          - resources:
              kinds: [Pod]
      validate:
        message: Containers must run as non-root.
        pattern:
          spec:
            containers:
              - securityContext:
                  runAsNonRoot: true

# Policy: auto-inject team labels on namespaces
# Policy: require resource limits on all containers
# Policy: block latest tag in production namespaces
# Policy: verify image signature before allowing pull
```

---

## Module 62: Secret Management

Topics:

- Kubernetes Secrets are base64-encoded, not encrypted by default
- Encryption at rest via KMS integration (GCP KMS + etcd encryption)
- HashiCorp Vault: the secret store
  - KV v2 secrets engine
  - Dynamic secrets (database credentials, cloud credentials)
  - Vault agent: inject secrets as files or environment variables
- External Secrets Operator (ESO): sync secrets from Vault/GCP/AWS to K8s
- CSI Secret Store Driver: mount secrets as volumes
- Workload Identity (GKE) and IRSA (EKS): keyless cloud secret access
- Secret rotation: how ESO handles it with `refreshInterval`

Lab:

```bash
# Deploy Vault on Kubernetes with Raft storage
# Enable Kubernetes auth method
# Create a policy for app-specific secrets
# Deploy ESO and configure a SecretStore pointing to Vault
# Deploy application that reads secrets via ESO (no Vault SDK needed)

# Test secret rotation:
vault kv put secret/my-app/db password="new-password"
# ESO should propagate to K8s Secret within refreshInterval
```

---

## Module 63: Supply Chain Security

Topics:

- Supply chain attacks: the Solarwinds pattern applied to software builds
- SLSA framework: Supply chain Levels for Software Artifacts (0–3)
- SLSA levels: source requirements, build requirements, provenance requirements
- SBOM: Software Bill of Materials (SPDX, CycloneDX)
- SBOM generation: Syft
- SBOM vulnerability scanning: Grype
- Dependency scanning: Dependabot, Renovate
- Provenance attestation: who built what, when, with what inputs

Lab:

```bash
# Generate SBOM for a container image
syft my-app:latest -o spdx-json > sbom.json

# Scan SBOM for vulnerabilities
grype sbom:./sbom.json

# Attach SBOM to image in registry as OCI attestation
cosign attest --type spdx --predicate sbom.json my-app:latest@sha256:...
```

---

## Module 64: Image Signing and Verification

Topics:

- Why sign images: verify that what was built is what runs
- Sigstore / Cosign: the standard for container image signing
- Keyless signing: use OIDC identity (GitHub Actions, GCP SA) — no key management
- Transparency log (Rekor): immutable audit log of all signatures
- Verifying signatures: `cosign verify`
- Policy enforcement: Kyverno `verifyImages` rule blocks unsigned images
- Signature policies: who is allowed to sign for which registry paths

Lab:

```bash
# Sign image in CI (keyless, via GitHub Actions OIDC)
cosign sign --yes \
  --certificate-identity=https://github.com/org/repo/.github/workflows/build.yaml@refs/heads/main \
  --certificate-oidc-issuer=https://token.actions.githubusercontent.com \
  ghcr.io/org/my-app@${DIGEST}

# Verify signature
cosign verify \
  --certificate-identity=... \
  --certificate-oidc-issuer=... \
  ghcr.io/org/my-app:latest
```

---

## Module 65: Runtime Security

Topics:

- Runtime threat detection: watching what processes are doing, not just what they are
- Falco: eBPF-based syscall monitoring
- Falco rules: detect container escapes, unexpected binaries, shell in production container
- Pod Security Standards: Privileged, Baseline, Restricted
- Security contexts: `securityContext` on pod and container level
- AppArmor and Seccomp profiles
- gVisor and Kata Containers: stronger isolation boundaries
- Incident response for runtime security alerts

Lab:

```yaml
# Deploy Falco as DaemonSet
# Custom rule: alert if shell is opened in production containers
- rule: Shell Spawned in Production Container
  desc: Detect shell in production namespace
  condition: >
    spawned_process and
    proc.name in (shell_binaries) and
    k8s.ns.name = "production"
  output: "Shell in production (user=%user.name cmd=%proc.cmdline)"
  priority: CRITICAL
  tags: [process, runtime]
```

---

## Module 66: Zero Trust for Platforms

Topics:

- Zero Trust principles: never trust, always verify, assume breach
- Workload identity: SPIFFE/SPIRE for service identity
- mTLS: every service-to-service call is authenticated and encrypted
- Cilium mTLS with SPIFFE identities (alternative to Istio)
- Just-in-time access: time-limited privileges instead of permanent access
- Service-to-service authorization policies: only `frontend` can call `backend`
- Zero standing privileges: no human has permanent cluster-admin

Lab:

```yaml
# Cilium NetworkPolicy: L7 authorization
apiVersion: "cilium.io/v2"
kind: CiliumNetworkPolicy
metadata:
  name: allow-frontend-to-backend
spec:
  endpointSelector:
    matchLabels:
      app: backend
  ingress:
    - fromEndpoints:
        - matchLabels:
            app: frontend
      toPorts:
        - ports:
            - port: "8080"
          rules:
            http:
              - method: "GET"
                path: "/api/.*"
```

---

# Phase 11 — Kubernetes Networking

## Module 67: Kubernetes Networking Fundamentals

Topics:

- Kubernetes networking model: all pods can reach all other pods, no NAT
- Pod networking: veth pairs, bridges, routing
- Pod-to-Pod communication: same node (bridge) vs cross-node (CNI)
- Pod-to-Service communication: iptables/eBPF rewriting Service IP to Pod IP
- DNS resolution chain: `my-svc.namespace.svc.cluster.local`
- Headless service: DNS returns pod IPs directly
- kube-proxy: manages iptables/IPVS rules for Services
- Container network interface (CNI): the plugin API for networking

Lab:

```bash
# Trace a request from pod to service to pod
# Observe iptables DNAT rules for ClusterIP service
iptables -t nat -L KUBE-SERVICES -n

# Observe Cilium replacing kube-proxy with eBPF
cilium status
cilium connectivity test
```

---

## Module 68: CNI Plugins

Topics:

- CNI specification: what a CNI plugin must implement
- Flannel: simple overlay, VXLAN, limited features
- Calico: BGP-based, rich NetworkPolicy support
- Cilium: eBPF-based, L7 visibility, service mesh features
- Choosing a CNI: feature set, performance, operational complexity
- CNI plugin troubleshooting: pod stuck in ContainerCreating
- IPAM (IP Address Management): how pods get IPs

---

## Module 69: Network Policies

Topics:

- Default-deny patterns: start closed, open only what's needed
- Ingress and egress policies
- Namespace isolation: teams cannot accidentally reach other teams
- Policy selectors: pod, namespace, IP block
- NetworkPolicy limitations: no FQDN support, no L7 in vanilla
- Testing network policies: `netcat`, `kubectl exec`
- Cilium NetworkPolicy: extends standard with L7 and DNS-based rules

Lab:

```yaml
# Default deny all in a namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]

# Then selectively open: allow frontend → backend on port 8080
# Allow egress to kube-dns on 53/UDP
# Allow egress to external API on specific FQDN (Cilium only)
```

---

## Module 70: Cilium and eBPF

Topics:

- eBPF: run sandboxed programs in the kernel without kernel modules
- Cilium as CNI + service mesh + network observability
- eBPF programs for packet processing: faster than iptables
- Hubble: eBPF-powered network flow visibility
- Cilium L7 policies: HTTP, gRPC, Kafka, DNS
- Bandwidth management: rate limiting at the eBPF level
- Cilium replacing kube-proxy: eBPF-based service load balancing
- Cluster mesh: multi-cluster networking with Cilium

Lab:

```bash
# Enable Hubble UI
cilium hubble enable

# Observe network flows between services
hubble observe --namespace team-a --follow

# Identify unexpected connections
hubble observe --verdict DROPPED --follow
```

---

## Module 71: Kubernetes Gateway API

Topics:

- Gateway API: the successor to the Ingress API
- Role separation: GatewayClass (infra), Gateway (operator), HTTPRoute (developer)
- HTTPRoute: path routing, header matching, traffic weighting
- TCPRoute and TLSRoute: non-HTTP protocols
- Traffic splitting for canary: 90/10 weighted routing
- Gateway API for multi-tenancy: teams manage their own HTTPRoutes
- TLS termination and passthrough
- Reference implementation: GKE Gateway, Cilium Gateway, Envoy Gateway

Lab:

```yaml
# Platform team manages the Gateway
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: platform-gateway
spec:
  gatewayClassName: gke-l7-global-external-managed
  listeners:
    - name: https
      port: 443
      protocol: HTTPS

# Developer team manages HTTPRoutes in their namespace
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-app
  namespace: team-a
spec:
  parentRefs:
    - name: platform-gateway
      namespace: platform-system
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /api/my-app
      backendRefs:
        - name: my-app
          port: 8080
```

---

## Module 72: Service Mesh Reference

Topics:

- Service mesh: what problem it solves (mTLS, traffic management, observability)
- Istio architecture: Istiod control plane, Envoy sidecar proxy
- Ambient mesh: Istio without sidecars (ztunnel + waypoint proxy)
- mTLS with Istio: automatic certificate management via SPIFFE
- Traffic management: VirtualService, DestinationRule, retry, circuit breaker
- Istio vs Cilium: service mesh comparison
- When a service mesh adds more complexity than value
- Choosing: Cilium for networking-first, Istio for traffic management richness

---

# Phase 12 — Developer Experience and IDP

## Module 73: IDP Architecture

Topics:

- The five functional planes of an IDP:
  1. Developer control plane: portal, CLI, API — the interface developers use
  2. Integration and delivery plane: CI/CD, GitOps, artifact management
  3. Resource plane: cloud resources, databases, queues — via IaC or Crossplane
  4. Monitoring plane: observability, alerting, cost visibility
  5. Security plane: access control, secrets, policy enforcement
- IDP reference architecture (Humanitec model)
- Platform API design: stable, versioned, documented interfaces
- IDP product principles: convention over configuration, escape hatches exist, migration supported
- Build vs buy decision matrix

---

## Module 74: Backstage Fundamentals

Topics:

- Backstage origin: internal tool at Spotify, donated to CNCF
- Core plugin architecture: every feature is a plugin
- Core features: Software Catalog, Software Templates, TechDocs, Search
- Backstage deployment: Node.js app, PostgreSQL backend, deployed on Kubernetes
- Authentication: configuring identity providers (GitHub, Google, OIDC)
- Deploying Backstage with Helm on GKE
- Backstage as a platform product: versioning, changelog, support model

Lab:

```bash
# Scaffold a Backstage app
npx @backstage/create-app

# Configure GitHub authentication
# Connect to a PostgreSQL database
# Deploy to GKE with Helm
helm install backstage backstage/backstage \
  -f backstage-values.yaml -n platform-system
```

---

## Module 75: Backstage Software Catalog

Topics:

- Catalog entities: Component, API, System, Domain, Resource, Group, User
- `catalog-info.yaml`: the descriptor file in every repository
- Entity relationships: `ownedBy`, `partOf`, `dependsOn`, `providesAPI`
- Catalog ingestion: GitHub discovery (auto-import all repos with `catalog-info.yaml`)
- API catalog: display and document APIs from OpenAPI specs
- Software catalog as engineering inventory: what exists, who owns it, where it runs
- Catalog health: staleness detection, missing owners

Lab:

```yaml
# catalog-info.yaml in every service repository
apiVersion: backstage.io/v1alpha1
kind: Component
metadata:
  name: checkout-service
  description: Handles payment and order checkout
  annotations:
    github.com/project-slug: org/checkout-service
    backstage.io/techdocs-ref: dir:.
    argocd/app-name: checkout-service
spec:
  type: service
  lifecycle: production
  owner: team-payments
  system: order-management
  providesApis:
    - checkout-api
  dependsOn:
    - component:payment-gateway
    - resource:orders-database
```

---

## Module 76: Backstage Software Templates

Topics:

- Software Templates: scaffolding new services from Backstage UI
- Template structure: metadata, parameters, steps
- Template actions: `fetch:template`, `publish:github`, `catalog:register`, `github:actions:dispatch`
- Template parameters: form fields rendered in the Backstage UI
- Custom template actions: extend with platform-specific steps
- Template versioning: reference a specific Git tag for stability

Lab:

Build a golden path template for a standard Go microservice:

```yaml
apiVersion: scaffolder.backstage.io/v1beta3
kind: Template
metadata:
  name: go-microservice
  title: Go Microservice
spec:
  parameters:
    - title: Service Information
      properties:
        name:
          title: Service Name
          type: string
        team:
          title: Owning Team
          type: string
  steps:
    - id: fetch-base
      action: fetch:template
      input:
        url: ./skeleton     ← Go service skeleton with CI, Dockerfile, Helm chart
        values:
          name: ${{ parameters.name }}
    - id: publish
      action: publish:github
      input:
        repoUrl: github.com?owner=org&repo=${{ parameters.name }}
    - id: register
      action: catalog:register
      input:
        catalogInfoUrl: ${{ steps.publish.output.remoteUrl }}/blob/main/catalog-info.yaml
```

---

## Module 77: Backstage Plugins

Topics:

- Backstage plugin architecture: frontend (React) + backend (Node.js) plugins
- Official plugins: GitHub Actions, ArgoCD, Kubernetes, PagerDuty, Grafana, SonarQube
- Plugin for ArgoCD: display sync status on the component page
- Plugin for Kubernetes: show running pods, deployments, events in Backstage
- Plugin for Grafana: embed dashboards in the Backstage entity page
- Plugin for cost: OpenCost or Kubecost data in entity page
- Building a custom plugin: TypeScript, React, Backstage plugin SDK

Lab:

Install and configure:

```text
@backstage/plugin-argocd         ← GitOps sync status
@backstage/plugin-kubernetes     ← live cluster state
@roadiehq/backstage-plugin-grafana ← embedded dashboards
@backstage/plugin-cost-insights  ← team cost visibility
```

Then build a simple custom plugin that shows the team's on-call schedule
from PagerDuty on the team entity page.

---

## Module 78: Golden Paths

Topics:

- Golden path definition: the recommended, supported, opinionated way to do something
- What a golden path must include:
  - Repository scaffold (from Backstage template)
  - CI/CD pipeline (from platform pipeline template)
  - Container build and push
  - IaC for cloud resources (if needed)
  - GitOps deployment config
  - Observability (OTel SDK pre-configured)
  - Security (non-root, signed image, SBOM)
  - Documentation template (TechDocs)
- Escape hatches: documented, reviewed process for deviating from the golden path
- Golden path versioning: v1 → v2 migration with tooling to help teams update
- Golden path adoption metrics: what % of services use each version?

Architecture of a golden path:

```text
Developer requests "new service" in Backstage
  ↓
Template creates:
  GitHub repo (skeleton: main.go, Dockerfile, Helm chart, catalog-info.yaml)
  GitHub Actions workflow (from platform template)
  config-repo entry (GitOps App definition)
  Namespace in dev cluster (via Namespace Operator)
  Monitoring dashboard (Grafana dashboard template)
  On-call schedule entry (PagerDuty)
  ↓
Developer starts coding in a pre-wired, production-ready skeleton
```

---

## Module 79: Platform CLI Tools

Topics:

- When to build a CLI: reduce friction for frequent developer tasks
- Go + Cobra + Viper: the standard for platform CLIs
- CLI commands for a platform team: `platform env create`, `platform deploy`, `platform logs`, `platform cost`
- CLI distribution: GitHub releases, Homebrew tap, internal package manager
- CLI versioning and auto-update
- CLI config: `~/.platform/config.yaml`, environment variables
- Shell completions: bash, zsh, fish
- Avoiding over-engineering: the CLI wraps API calls, not business logic

Lab:

Build a `platform` CLI in Go that wraps common kubectl, ArgoCD and cost
operations behind a developer-friendly interface:

```bash
platform env list
platform env create --name my-feature-env --base dev
platform deploy --app my-service --version sha-abc123 --env dev
platform logs --app my-service --env prod --since 1h
platform cost --team payments --month current
```

---

## Module 80: Developer Portal Documentation Strategy

Topics:

- TechDocs in Backstage: render MkDocs-based documentation from service repos
- Docs-as-code: documentation lives in the repository with the code
- Documentation structure for platform services: README, architecture, runbooks, API
- Architecture Decision Records (ADRs): documenting why decisions were made
- API documentation: OpenAPI specs registered in Backstage catalog
- Runbook standards: every alert must link to a runbook
- Platform documentation: the platform itself must be well-documented

---

# 11. Major Project

# Project 4 — Internal Developer Platform

Goal:

Build a fully functional Internal Developer Platform on GKE, integrating
all previous project capabilities, delivered via Backstage with
golden path templates and CI/CD self-service.

Architecture:

```text
Developer
  ↓
Backstage Portal (on GKE)
  ↓
Software Catalog: all services, APIs, systems, teams
Software Templates: Go service, Python service, RAG app
TechDocs: all service documentation
Plugins: ArgoCD, Kubernetes, Grafana, Cost Insights, GitHub Actions
  ↓
Developer requests new service
  ↓
Template creates:
  GitHub repo with platform skeleton
  CI/CD pipeline
  ArgoCD Application
  Namespace with RBAC + quota
  GCP Secret Manager secret via ESO
  Monitoring dashboards
  ↓
Platform Capabilities (all from Projects 1–3):
  GKE cluster + Terraform (Project 1)
  GitOps with ArgoCD (Project 2)
  Observability stack (Project 3)
  Kyverno policies: image signing, resource limits, non-root
  Cilium networking + Gateway API
  External Secrets Operator
```

Requirements:

- Backstage deployed on GKE with GitHub auth
- Software catalog auto-populated from GitHub organization
- Two golden path templates (Go service, Python/FastAPI service)
- ArgoCD, Kubernetes, Grafana plugins installed and configured
- Cost Insights plugin connected to Kubecost
- TechDocs rendered from at least 3 service repositories
- All deployed via GitOps from Project 2

Stretch goals:

- Custom Backstage plugin for internal incident history
- `platform` CLI (from Module 79) with `env create` and `deploy` commands
- Backstage scaffolder action that creates GCP resources via Crossplane

---

# Phase 13 — Platform SRE

## Module 81: Platform SRE Fundamentals

Topics:

- Platform teams have a higher reliability bar than application teams
- Every platform outage affects all stream-aligned teams simultaneously
- Platform SRE responsibilities: SLOs, toil reduction, capacity, incident management
- Toil: manual repetitive operational work; eliminate it or automate it
- Measuring toil: time spent on non-engineering work per sprint
- Platform engineering toil sources: manual namespace setup, manual secret creation, manual cluster upgrades
- Automation as the primary tool against toil

---

## Module 82: Platform SLOs

Topics:

- Define SLOs for every platform service
- Platform SLO examples:

```text
GitOps sync latency:  95% of syncs complete within 60 seconds
ArgoCD availability:  99.9% API uptime measured over 30 days
Secret propagation:   95% of ESO syncs within 10 minutes of source change
Cluster API server:   99.95% availability (GKE SLA)
Build pipeline:       95% of builds complete within 10 minutes
Backstage portal:     99.5% availability
```

- Error budget burn rate for platform services
- When platform SLO breach means freezing changes vs investigating
- Communication of SLO status to developer teams

---

## Module 83: Platform Incident Management

Topics:

- Incident management process for platform teams
- Incident severity classification for platform incidents
- P0: all teams blocked. P1: major capability degraded. P2: partial degradation. P3: minor.
- Incident commander role in platform incidents
- Communication during platform incidents: status page, Slack, email
- Runbooks: every failure mode must have a runbook
- Postmortem process: blameless, structured, action-tracked
- Postmortem template: timeline, contributing factors, action items

Lab:

Run a simulated platform incident:

```text
Scenario: ArgoCD stops syncing due to a misconfigured webhook.

Tasks:
1. Detect the incident via SLO burn rate alert
2. Triage: determine scope and impact
3. Execute runbook for ArgoCD sync failure
4. Mitigate: restore sync
5. Write a postmortem
```

---

## Module 84: Platform Capacity Planning

Topics:

- Cluster capacity planning: how many nodes? which sizes?
- Node pool design: general-purpose, compute-optimized, GPU, spot
- Autoscaling strategy: HPA + VPA for pods, Cluster Autoscaler + Karpenter for nodes
- Karpenter: right-size nodes to fit pod requests, prefer spot, consolidate on low utilization
- Capacity forecasting: predict growth from team adoption trends
- Resource efficiency: idle resources cost money, tight resources cause incidents
- Node rightsizing: monitor actual usage vs requests over 30 days, recommend adjustments

Lab:

```bash
# Deploy Karpenter on GKE (or kind)
# Configure NodePool with spot preference and fallback to on-demand
# Observe Karpenter launching the right node size for different workloads
# Enable consolidation: Karpenter merges underutilized nodes
```

---

## Module 85: Chaos Engineering for Platforms

Topics:

- Chaos engineering: inject failure deliberately to find weaknesses before users do
- Steady-state hypothesis: define what "normal" looks like before injecting failure
- Chaos Mesh: Kubernetes-native chaos experiments
- Litmus Chaos: CNCF chaos engineering framework
- Failure modes for platforms: control plane unavailability, node failure, network partition, storage failure, dependency failure
- GameDay: structured chaos exercise with the platform team
- Chaos results: did SLOs hold? Did alerts fire? Did runbooks work?

Lab:

Design and run three chaos experiments:

```text
Experiment 1: Kill one third of ArgoCD pods
  Hypothesis: ArgoCD remains functional, sync continues
  Expected: Remaining pods handle load, no sync failures

Experiment 2: Introduce 500ms network latency to Prometheus
  Hypothesis: Grafana dashboards degrade gracefully, alerts still fire
  Expected: Query timeout alerts fire, not total blackout

Experiment 3: Delete External Secrets Operator pod
  Hypothesis: Existing secrets survive, new secret syncs retry
  Expected: ESO restarts within 30 seconds, catches up on missed refreshes
```

---

## Module 86: Disaster Recovery for Platform

Topics:

- Platform DR: what happens when an entire cluster is lost?
- RTO and RPO for platform services
- Cluster backup with Velero: backup all resources and persistent volumes
- etcd backup: raw etcd snapshot for control plane recovery
- GKE cluster recovery: Terraform re-creates cluster, ArgoCD re-syncs config
- DR runbooks: tested, not assumed
- Multi-region platform: active-active vs active-passive
- DR drills: quarterly, documented

Lab:

```bash
# Configure Velero with GCS backend
velero install --provider gcp --bucket platform-velero-backup \
  --secret-file ./credentials-velero

# Create a scheduled backup
velero schedule create daily-full --schedule="0 2 * * *"

# Simulate cluster loss: delete a namespace with all resources
# Restore from Velero backup and verify
velero restore create --from-schedule daily-full
```

---

# Phase 14 — FinOps and Cost Engineering

## Module 87: Cloud Cost Fundamentals

Topics:

- Cloud pricing models: on-demand, committed (1yr/3yr), spot/preemptible
- Cost components: compute, storage, networking, managed services
- GCP billing: projects, billing accounts, budgets, alerts
- Committed Use Discounts (CUDs): up to 57% discount for 1–3 year commitments
- Spot VMs: 60–90% cheaper, may be preempted
- Networking egress costs: often overlooked, can be significant
- Cost allocation tags: every resource must have team, environment, application labels

---

## Module 88: Kubernetes Cost Management

Topics:

- Kubernetes cost attribution: cloud sees nodes, not workloads
- Kubecost: cost per namespace, workload, pod, container
- OpenCost: CNCF-sandbox open-source cost monitoring
- Cost per workload = (CPU cost × CPU request fraction) + (memory cost × memory request fraction)
- Idle cost: requested-but-unused resources — wasted money
- Node efficiency: ratio of allocated resources to total node capacity
- Cost metrics in Grafana: integrate Kubecost/OpenCost with Grafana

Lab:

```bash
# Install OpenCost on the cluster
helm install opencost opencost/opencost -n opencost

# Query cost by namespace
curl http://localhost:9090/allocation?window=1d&aggregate=namespace

# Identify top 5 most expensive workloads in the last 7 days
# Identify idle namespaces: low usage, potentially unused
```

---

## Module 89: Cost Attribution and Chargeback

Topics:

- Showback: show teams how much they cost, no billing
- Chargeback: bill teams for their cloud spend
- Cost allocation labels: mandatory team, service, environment, cost-center labels
- Enforcing labels: Kyverno policy requiring labels on all workloads
- Team cost dashboards in Grafana (OpenCost data source)
- Cost reporting automation: weekly report per team via Slack
- FinOps conversations: how to discuss cost with engineering managers

Lab:

```yaml
# Kyverno: require cost allocation labels on all Deployments
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: require-cost-labels
spec:
  validationFailureAction: Enforce
  rules:
    - name: check-labels
      match:
        resources:
          kinds: [Deployment]
      validate:
        message: "Deployments must have team, environment, and cost-center labels."
        pattern:
          metadata:
            labels:
              platform.example.com/team: "?*"
              platform.example.com/environment: "?*"
              platform.example.com/cost-center: "?*"
```

---

## Module 90: Cost Optimization Patterns

Topics:

- Right-sizing: reduce resource requests to match actual usage (VPA recommendations)
- Spot/preemptible workloads: run batch jobs, dev environments, non-critical workloads on spot
- Cluster bin-packing with Karpenter: consolidate onto fewer, fuller nodes
- Reserved capacity: commit to 1-year CUDs for baseline compute
- Autoscaling to zero: scale down dev environments outside business hours
- Storage tiering: move old data to cold storage
- Egress optimization: keep traffic within regions, use CDN for static assets
- Delete idle resources: unused namespaces, PVCs, load balancers

Lab:

Implement three cost optimizations on a test cluster:

```text
Optimization 1: VPA recommendations → right-size 5 workloads
  Before: team-a spending $X/month
  After:  team-a spending $X * 0.7/month

Optimization 2: Move dev workloads to spot nodes
  Karpenter NodePool with spotFirst strategy

Optimization 3: Karpenter consolidation
  Enable drifted and underutilized node consolidation
  Observe node count drop from N to N*0.6 at night
```

---

## Module 91: FinOps Culture and Process

Topics:

- FinOps lifecycle: Inform → Optimize → Operate
- FinOps not as a team but as a practice shared across platform + engineering
- Unit economics: cost per request, cost per user, cost per transaction
- Cost quality reliability triangle: you can optimize two, the third suffers
- Cost review in sprint planning: team cost trends as an engineering concern
- Cost anomaly detection and alerting: alert when cost spikes > 20% week-on-week
- Platform team cost governance: approved instance types, required auto-scaling

---

# Phase 15 — Multi-Cluster and Multi-Cloud

## Module 92: Multi-Cluster Architecture

Topics:

- Why multi-cluster: regulatory isolation, failure domain, team ownership, regional HA
- Cluster segmentation strategies: one per environment, one per team, one per region
- Management cluster pattern: a cluster to manage all other clusters
- Multi-cluster traffic patterns: ingress per cluster vs global load balancer
- Cross-cluster service discovery: Cilium Cluster Mesh, Istio multi-cluster, Submariner
- Multi-cluster RBAC: centralized identity, distributed enforcement
- Multi-cluster GitOps: ApplicationSets targeting multiple clusters

---

## Module 93: Fleet Management with Cluster API

Topics:

- Cluster API (CAPI): manage cluster lifecycle declaratively via Kubernetes
- CAPI concepts: management cluster, workload clusters, providers
- CAPI providers: CAPG (GKE), CAPA (EKS), CAPZ (AKS), CAPD (Docker/kind)
- Cluster bootstrap: cluster is created, Flux/ArgoCD bootstrapped automatically
- Cluster upgrades with CAPI: rolling, declarative, auditable
- Machine pools: auto-scaling node groups via CAPI
- ClusterClass: reusable cluster templates

Lab:

```yaml
# Create a GKE workload cluster via Cluster API
apiVersion: cluster.x-k8s.io/v1beta1
kind: Cluster
metadata:
  name: team-a-production
spec:
  clusterNetwork:
    pods:
      cidrBlocks: ["192.168.0.0/16"]
  infrastructureRef:
    apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
    kind: GCPManagedCluster
    name: team-a-production
  controlPlaneRef:
    apiVersion: controlplane.cluster.x-k8s.io/v1beta1
    kind: GKEManagedControlPlane
    name: team-a-production
```

---

## Module 94: Multi-Cloud Platform Patterns

Topics:

- Why multi-cloud: avoid vendor lock-in, regulatory requirements, best-of-breed services
- Multi-cloud abstraction layer: Crossplane XRDs hide cloud-specific implementation
- Multi-cloud networking: VPN, ExpressRoute, Cloud Interconnect
- Multi-cloud IAM: federated identity, consistent access patterns
- Multi-cloud cost: usually more expensive than single-cloud (redundant expertise, tooling, connectivity)
- When multi-cloud adds value vs when it adds only complexity
- Kubernetes as the portability layer: run the same Helm charts on any cloud

---

## Module 95: Global Load Balancing and Edge

Topics:

- Multi-region active-active: all regions serve traffic simultaneously
- Multi-region active-passive: standby region promoted on failure
- Global load balancers: GCP Global LB, AWS Global Accelerator, Cloudflare
- Latency-based routing: route to nearest region
- Health-based failover: automatically reroute on unhealthy regional backend
- Anycast: same IP address resolves to nearest PoP
- Edge compute: run platform-adjacent logic at the CDN edge

---

# Phase 16 — Advanced Platform Topics

## Module 96: Platform Engineering Maturity Model

Teach learners to self-assess and prioritize:

```text
Level 1 — Reactive Ops
  Manual provisioning, runbooks in people's heads
  No self-service, ticket-driven everything
  Measure: time-to-environment > 1 week

Level 2 — Standardized DevOps
  Standard CI/CD pipelines
  IaC for infrastructure
  Basic monitoring
  Measure: time-to-environment < 1 day

Level 3 — Self-Service Platform
  Developer self-service for common tasks
  GitOps for config delivery
  Observability as a platform service
  Golden paths exist but adoption is partial
  Measure: time-to-environment < 1 hour

Level 4 — Productized Platform
  IDP with catalog, templates, and documentation
  Platform has SLOs and on-call
  Security is enforced by the platform, not by code review
  Adoption > 80% of teams on golden paths
  Measure: time-to-environment < 10 minutes

Level 5 — Adaptive Platform
  Platform self-heals and self-optimizes
  AI-assisted developer experience
  Continuous platform quality improvement via feedback loops
  Full cost attribution and optimization automation
  Measure: developer satisfaction score > 4/5 consistently
```

---

## Module 97: AI-Assisted Platform Engineering

Topics:

- LLM-powered developer self-service: natural language to platform action
- AI in platform documentation: auto-generated TechDocs, README improvements
- AIOps for platform teams: LLM-powered root cause analysis, log summarization
- AI for incident correlation: connect related alerts and suggest cause
- AI-generated runbooks from historical incidents
- AI cost optimization: automated right-sizing recommendations with explanations
- Responsible use: AI assists platform engineers, does not replace judgment

Integration with AI engineering courses:

```text
Platform Engineering course → platform that hosts AI services
AI Engineering course → AI services that run on the platform
```

---

## Module 98: Platform Engineering Metrics

Topics:

- DORA metrics in the platform context:
  - Deployment frequency: how often does the platform itself deploy?
  - Lead time for changes: PR to production for platform config
  - Change failure rate: platform changes that cause incidents
  - Time to restore: MTTR for platform incidents

- SPACE framework for developer experience:
  - Satisfaction: developer NPS survey
  - Performance: deployment frequency per team
  - Activity: code commits, deployments, PRs per team
  - Communication: PR review time
  - Efficiency: time-to-first-deployment for new teams

- Platform adoption metrics:
  - % of teams using the golden path
  - % of services in the software catalog
  - % of services with SLOs defined
  - % of services using platform-managed observability

- Platform health dashboard:
  - Real-time platform service SLO status
  - Active incidents
  - Change activity (recent deployments)
  - Developer experience trend

---

## Module 99: Platform Engineering Culture and Organization

Topics:

- Platform team culture: product mindset + engineering excellence
- Avoiding the "platform empire" anti-pattern: platform team that controls everything
- Developer evangelism: demos, office hours, lunch-and-learn sessions
- Internal marketing: changelog, roadmap, success stories
- Community of practice: cross-team platform champions
- Handling resistance: "why should I use the platform when I can just use cloud directly?"
- Platform roadmap communication: open roadmap, developer input into priorities
- Measuring and communicating platform impact: before/after deployment frequency, incident counts
- Platform team career development: platform engineer → senior → staff → principal

---

# 12. Capstone Projects

## Capstone 1 — Production Kubernetes Platform

Build a complete, multi-team, production-grade Kubernetes platform from scratch.

Requirements:

```text
[ ] GKE cluster provisioned with Terraform
[ ] Cilium as CNI (replacing kube-proxy)
[ ] Multi-namespace structure with RBAC per team
[ ] LimitRanges and ResourceQuotas per namespace
[ ] Karpenter for node autoscaling (spot-first)
[ ] Kyverno: image signing, non-root, resource limits, cost labels
[ ] External Secrets Operator + GCP Secret Manager
[ ] Kubernetes Gateway API with GKE Gateway Controller
[ ] Network policies: default deny all, selective allow
[ ] Falco for runtime security
[ ] All provisioning via GitOps (ArgoCD)
[ ] Full LGTM observability stack
[ ] SLOs for all platform services
[ ] Backstage Software Catalog
[ ] CI pipeline template for all teams
[ ] Cluster backup with Velero
[ ] Disaster recovery runbook, tested
```

Deliverable:

- GitHub repository with full IaC, GitOps config, and documentation
- Architecture diagram showing all components
- Platform SLO dashboard (Grafana)
- DR runbook
- Onboarding guide for new development teams

---

## Capstone 2 — Full IDP with Backstage

Build a fully functional Internal Developer Platform that can onboard a
new engineering team from zero to their first production deployment
in under 30 minutes.

New team onboarding journey:

```text
Platform engineer runs:
  platform team create --name payments --members alice,bob,charlie
  ↓
Backstage: Group entity created
GitHub team created
Namespace provisioned (via Operator)
Default RBAC applied
ResourceQuota applied
Cost label policies applied
PagerDuty schedule created
Slack channel created

Developer opens Backstage:
  Clicks "Create Service"
  Selects "Go Microservice" template
  Fills in: name, description, dependencies
  ↓
GitHub repo created with full skeleton
CI/CD pipeline wired
ArgoCD Application created
Dev environment deployed automatically
Monitoring dashboard created
On-call schedule linked
Service appears in Software Catalog immediately
```

Deliverable:

- Backstage deployed and configured
- At least 3 golden path templates (Go service, Python service, frontend)
- All 4 core plugins configured (ArgoCD, Kubernetes, Grafana, Cost)
- Custom template actions for platform-specific steps
- Platform CLI with `team create`, `env create`, `deploy` commands
- Recorded demo of the full onboarding journey

---

## Capstone 3 — Multi-Cluster GitOps Platform

Build a multi-cluster platform serving three environments across two regions
using GitOps, with full promotion automation and disaster recovery.

Architecture:

```text
Management Cluster (us-central1)
  ArgoCD (manages all clusters)
  Backstage
  Vault

Workload Clusters:
  dev-us-central1     ← auto-sync, spot nodes
  staging-us-central1 ← auto-sync after dev passes eval
  prod-us-central1    ← manual gate, HA node pools
  prod-us-east1       ← DR replica, Cilium Cluster Mesh
```

Requirements:

- Cluster API bootstraps all workload clusters from management cluster
- ArgoCD ApplicationSets deploy to all clusters
- Cluster Mesh: prod clusters share service visibility
- Promotion pipeline: dev → staging → prod (each with evaluation gate)
- Velero DR: cross-region backup, tested restore
- Global load balancer routing between prod regions
- Platform SLOs measured per cluster

---

## Capstone 4 — Production Platform Reference Architecture

Combine all previous capstones into a single, fully documented reference
architecture that another organization could adopt.

```text
                     Developer
                         │
                         ▼
                    Backstage IDP
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         Go Service  Python App  RAG App
         Template    Template    Template
              │          │          │
              └──────────┼──────────┘
                         ▼
                Platform CI/CD Pipeline
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
             Dev      Staging     Prod
          (auto-sync) (auto-sync) (manual)
              │          │          │
              └──────────┼──────────┘
                         ▼
               Platform Services Layer
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
   GitOps Engine    Observability    Security Layer
   (ArgoCD)         (LGTM Stack)    (Kyverno+Falco)
        │                │                │
        └────────────────┼────────────────┘
                         ▼
              Kubernetes Clusters (GKE)
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         Cilium CNI   Karpenter   Gateway API
                         │
                         ▼
                    Google Cloud
                (GKE, GCS, GCR, SM, KMS)
```

Deliverable:

- GitHub repository: complete, reproducible, documented
- Architecture decision records for every major choice
- Production readiness checklist: filled and passing
- Runbook library for all platform failure modes
- IDP demo video
- Blog post: "How We Built Our Internal Developer Platform"

---

# 13. Learning Projects by Difficulty

## Beginner

1.  Run a container and explore namespaces/cgroups
2.  Write a multi-stage Dockerfile, measure size reduction
3.  Deploy a workload on a local kind cluster
4.  Write RBAC that allows a CI service account to deploy to one namespace
5.  Write a basic Terraform config to provision a GCS bucket
6.  Create a Helm chart for a simple web application

## Intermediate

7.  Set up ArgoCD and deploy an application via GitOps
8.  Build a container CI pipeline with Trivy scan and Cosign sign
9.  Configure External Secrets Operator with GCP Secret Manager
10. Build a Kyverno policy that blocks non-root containers
11. Write a Terraform module for GKE with tests using Terratest
12. Define and configure SLOs for a service using sloth
13. Deploy the LGTM observability stack and build a service dashboard

## Advanced

14. Build a Kubernetes operator that provisions namespaces with full RBAC and quotas
15. Write an admission webhook that injects cost-allocation labels
16. Implement a multi-environment GitOps workflow with promotion automation
17. Configure Cilium with L7 network policies and observe flows with Hubble
18. Deploy Backstage with GitHub discovery and ArgoCD plugin
19. Set up Falco with custom rules and alerts

## Expert / Portfolio

20. Internal Developer Platform (Capstone 2)
21. Production Kubernetes Platform (Capstone 1)
22. Multi-Cluster GitOps Platform (Capstone 3)
23. Production Platform Reference Architecture (Capstone 4)

---

# 14. Standard Lab Template

Every lab:

```text
lab-name/
├── README.md
├── prerequisites.md
├── src/
├── tests/
├── manifests/    ← or terraform/ or helm/
├── scripts/
└── architecture.md
```

README structure:

```text
# Lab Name

## Objective

## Concepts

## Architecture Diagram

## Prerequisites

## Setup

## Implementation Steps

## Experiments

## Results and Observations

## Common Mistakes

## Production Considerations

## Cleanup

## Further Reading
```

Every lab must include a `cleanup.sh` or `terraform destroy` instruction.
Leaving cloud resources running wastes money.

---

# 15. Standard Project Template

```text
project/
├── README.md
├── architecture/
│   ├── architecture.md
│   ├── diagrams/
│   └── decisions/          ← ADRs
├── terraform/
│   ├── modules/
│   └── environments/
├── kubernetes/
│   ├── platform/
│   └── apps/
├── helm/
│   └── charts/
├── backstage/              ← for IDP projects
├── docs/
│   ├── runbooks/
│   └── onboarding.md
├── scripts/
│   ├── bootstrap.sh
│   └── cleanup.sh
└── .github/
    └── workflows/
```

The README must contain:

```text
Architecture diagram
Quick start (< 5 commands to get running)
Component inventory
Known limitations
Production considerations
Cost estimate
```

---

# 16. Architecture Decision Records

Every significant project should document key decisions.

Required ADRs for the capstone projects:

```text
ADR-001 — Why GKE over self-managed Kubernetes?
ADR-002 — Why Cilium as CNI?
ADR-003 — Why ArgoCD over Flux?
ADR-004 — Why Kyverno over OPA/Gatekeeper?
ADR-005 — Why External Secrets Operator over Sealed Secrets?
ADR-006 — Why Karpenter over Cluster Autoscaler?
ADR-007 — Why Backstage over Port/Cortex/custom?
ADR-008 — Why Helm + Kustomize over Helm alone?
ADR-009 — Why Crossplane for self-service databases?
ADR-010 — Why OpenCost over Kubecost?
ADR-011 — Why Tempo over Jaeger?
ADR-012 — Why folder strategy over branch strategy for GitOps environments?
```

ADR format:

```text
# ADR-NNN — Title

## Status
Accepted / Superseded / Deprecated

## Context
What problem are we solving? What are the constraints?

## Decision
What did we decide?

## Consequences
What are the benefits? What are the trade-offs?

## Alternatives Considered
What else did we evaluate and why did we not choose it?
```

---

# 17. Assessment Strategy

## Knowledge checks

Short questions at the end of each module:

```text
What is the difference between a request and a limit in Kubernetes?
What does ArgoCD do when it detects drift?
Why should secrets not be stored as plain text in Git?
What is the difference between SLI, SLO, and SLA?
```

## Concept exercises

Explain a concept without using the tool name:

```text
"Explain what GitOps achieves, without mentioning ArgoCD or Flux."
"Describe how Kubernetes self-heals a failed pod, without using the word 'controller'."
```

## Architecture exercises

Design a production system:

```text
Design a Kubernetes platform for a 50-engineer engineering organization
with 3 teams, 20 services, and strict PCI-DSS compliance requirements.
Include: cluster design, networking, RBAC, secret management, observability,
and the self-service mechanism for teams to request new services.
```

## Debugging exercises

Provide a broken cluster state and ask learners to diagnose:

```text
Exercise: A deployment exists in Kubernetes with 3 replicas requested,
but only 0 pods are running. All you know is that the pods are in
Pending state. Diagnose and fix the issue.
```

## Trade-off exercises

```text
"Your organization has three teams. Team A wants ArgoCD because they
know it. Team B wants Flux because they heard it's more GitOps-pure.
Team C doesn't care. You must choose one for the platform. How do you
make this decision? What process do you follow? What do you do with
the team that doesn't get their preferred tool?"
```

---

# 18. Platform Engineering Interview Track

## Fundamentals

- What is platform engineering?
- How does it differ from DevOps and SRE?
- What is an Internal Developer Platform?
- What is a golden path?
- What is cognitive load and why does it matter in platform engineering?

## Containers and Kubernetes

- How does a container differ from a VM?
- What happens when you `kubectl apply` a Deployment?
- What is a Kubernetes controller?
- How does Kubernetes networking work at a pod level?
- How do you debug a pod stuck in CrashLoopBackOff?
- What is the difference between a liveness and a readiness probe?

## Infrastructure as Code

- What is Terraform state and why does it matter?
- How do you handle secrets in Terraform?
- What is the difference between Terraform workspaces and separate state files?
- What is Crossplane and when would you use it over Terraform?
- How do you test IaC?

## GitOps

- What is GitOps and how does it differ from traditional CI/CD?
- How does ArgoCD detect and resolve drift?
- How do you manage secrets in a GitOps model?
- What is the App of Apps pattern?
- How do you promote a change from dev to production in a GitOps model?

## Observability

- What is the difference between metrics, logs, and traces?
- What is OpenTelemetry and why is it important?
- What is an SLO and how do you define one?
- What is error budget burn rate?
- How do you design alerts that are actionable and not noisy?

## Security

- What are Pod Security Standards?
- How does Kyverno work and what can it do?
- What is supply chain security?
- How do you manage secrets in Kubernetes without putting them in Git?
- What is the principle of least privilege in Kubernetes?

## Platform Architecture

- Design a Kubernetes platform for 100 development teams.
- How would you implement self-service environment provisioning?
- How would you build a GitOps multi-environment promotion workflow?
- How would you approach multi-cluster fleet management?
- How do you measure the success of a platform team?

---

# 19. Cheat Sheets

Create concise reference pages for:

```text
Platform Engineering Overview
Platform Maturity Model (Levels 1–5)
Kubernetes Architecture
kubectl Quick Reference
Pod Debugging Workflow
Kubernetes Resource Management
Kubernetes RBAC
Helm Quick Reference
Kustomize Quick Reference
Terraform Quick Reference
GitOps Principles
ArgoCD Operations
Observability: Metrics, Logs, Traces
PromQL Quick Reference
LogQL Quick Reference
SLO and Error Budget Quick Reference
Kyverno Policy Patterns
Secret Management Options Comparison
Supply Chain Security (SLSA Levels)
Cilium and eBPF Quick Reference
Kubernetes Gateway API
IDP Architecture Overview
Backstage Entity Types
Golden Path Checklist
Chaos Engineering Experiment Template
FinOps Optimization Checklist
Multi-Cluster Architecture Patterns
Platform CI/CD Pipeline Template
Production Readiness Checklist
Security Hardening Checklist
```

---

# 20. Three Learning Tracks

## Track A — Platform Engineer

For engineers building and operating the platform itself.

```text
Containerization
Kubernetes Fundamentals
IaC (Terraform + Crossplane)
CI/CD
GitOps
Kubernetes Advanced (Operators, CRDs, Webhooks)
Observability
Security and Policy
Networking
Platform SRE
FinOps
Multi-Cluster
```

## Track B — Developer Experience Engineer

For engineers focused on the IDP and developer tooling.

```text
Platform Foundations (all modules)
Kubernetes Fundamentals
GitOps
IDP Architecture
Backstage (all modules)
Golden Paths
Platform CLI Tools
Developer Portal Documentation
Platform Metrics (DX focus)
Platform Culture
```

## Track C — Platform Architect

For engineers designing and evaluating platform strategies.

```text
Platform Foundations (all modules)
Kubernetes Architecture
IaC Patterns
GitOps Patterns
Kubernetes Advanced
Security Architecture
Networking Architecture
IDP Architecture
Multi-Cluster Architecture
FinOps
Platform Maturity Model
Platform Metrics
Platform Culture
```

The same core curriculum supports all three tracks.

---

# 21. Suggested 12-Week Fast-Track

For engineers with strong DevOps or cloud engineering experience:

## Week 1

Platform Foundations + Container deep dive

## Week 2

Kubernetes Fundamentals + Project 1 start

## Week 3

IaC (Terraform + Crossplane) + Project 1 complete

## Week 4

CI/CD + Kubernetes Package Management (Helm + Kustomize)

## Week 5

GitOps (ArgoCD) + Project 2: GitOps Platform

## Week 6

Kubernetes Advanced (Operators, CRDs, Admission Webhooks)

## Week 7

Observability Engineering + Project 3: Observability Platform

## Week 8

Security and Policy (Kyverno, Secret Management, Supply Chain)

## Week 9

Kubernetes Networking (Cilium, Gateway API)

## Week 10

Developer Experience and IDP (Backstage) + Project 4: IDP

## Week 11

Platform SRE + FinOps + Multi-Cluster

## Week 12

Capstone Project + Architecture review + Interview preparation

The complete repository is much larger than the 12-week track. This
identifies the minimum high-value route to a production-capable
platform engineering skill set.

---

# 22. Portfolio Requirements

A project is portfolio-ready only if it has:

```text
[ ] Clear problem statement in the README
[ ] Architecture diagram (not a box-and-line placeholder)
[ ] Fully reproducible: another engineer can deploy from scratch
[ ] IaC for all infrastructure (Terraform)
[ ] Delivered via GitOps
[ ] Tests: IaC tests, policy tests, smoke tests
[ ] Observability: metrics, logs, traces configured
[ ] SLOs defined for every platform service
[ ] Security: non-root containers, signed images, policy enforcement
[ ] Secrets managed (not stored in Git)
[ ] Cost considerations documented
[ ] Runbooks for at least 3 failure modes
[ ] DR plan documented and tested
[ ] Known limitations
[ ] Future improvements
[ ] Architecture decisions documented (ADRs)
[ ] Onboarding guide: how a new developer gets their first service deployed
```

A cluster of YAML files without architecture, without documentation,
and without reproducible deployment is not a portfolio piece.

---

# 23. Production Readiness Checklist

Every advanced platform project answers:

### Availability

- What is the SLO for each platform service?
- What happens if ArgoCD is down?
- What happens if the API server is unreachable?
- Is there a fallback for every critical dependency?
- Are PodDisruptionBudgets configured for platform workloads?

### Security

- Are all containers running as non-root?
- Are images signed and signature-verified before deployment?
- Are there network policies enforcing default-deny in every namespace?
- Are secrets stored outside Git?
- Is RBAC following the principle of least privilege?
- Is runtime security (Falco) deployed and alerting?

### Observability

- Can you trace a deployment from Git push to running pod?
- Can you see which team is consuming the most resources?
- Do all platform service alerts link to runbooks?
- Are SLO burn rate alerts configured?

### Cost

- Is every workload labeled with team and cost-center?
- Are cost reports delivered to teams weekly?
- Are spot instances used for appropriate workloads?
- Is cluster autoscaling configured to scale down at night?

### Operations

- Can a new cluster be provisioned end-to-end from Terraform?
- Is there a tested DR procedure for total cluster loss?
- Are cluster upgrades automated and tested?
- Is there a runbook for every alert?

---

# 24. Diagrams Reference

Use diagrams selectively. A diagram must explain something
that is difficult to explain in prose.

Required diagrams:

```text
1.  Platform Engineering overview (what the platform delivers)
2.  IDP architecture (five planes)
3.  Container vs VM
4.  Container layer and OCI image structure
5.  Kubernetes architecture (control plane + data plane)
6.  Kubernetes networking (pod-to-pod, pod-to-service, DNS)
7.  Kubernetes RBAC model
8.  Terraform state and lifecycle
9.  GitOps model (Git as source of truth → ArgoCD → cluster)
10. ArgoCD multi-environment promotion flow
11. Multi-cluster architecture (hub and spoke)
12. Observability data flow (OTel → Prometheus/Loki/Tempo → Grafana)
13. SLO burn rate and error budget
14. Security layers in Kubernetes (7 layers)
15. Supply chain security pipeline
16. Secret management flow (Vault → ESO → K8s Secret → Pod)
17. Cilium eBPF packet path (vs iptables)
18. Kubernetes Gateway API role separation
19. IDP developer journey (request to deployed service)
20. Platform maturity model (Levels 1–5)
```

---

# 25. Repository README Structure

The root README is the landing page for the course.

```text
# Platform Engineering — From Zero to Production

Build and operate production-grade Internal Developer Platforms.

## What You'll Learn

## Who This Is For

## The Platform You'll Build

## Course Architecture

## Projects and Capstones

## Technology Stack

## Fast Track (12 weeks)

## Full Curriculum

## Learning Tracks

## How to Start

## Repository Structure

## Contributing

## License
```

The first screen must answer:

> "This is not a course about running kubectl commands.
> It is a course about building the platforms that other
> engineers build on — and understanding everything
> from first principles."

---

# 26. What Makes This Repository Different

This repository deliberately combines five disciplines:

```text
              PLATFORM ENGINEERING
                       │
      ┌────────────────┼────────────────┐
      │                │                │
      ▼                ▼                ▼
 KUBERNETES        SOFTWARE        DEVELOPER
  OPERATIONS       ENGINEERING     EXPERIENCE
      │                │                │
      └────────────────┼────────────────┘
                       │
          ┌────────────┴────────────┐
          ▼                         ▼
     SECURITY &                  FINOPS &
     POLICY ENG                  COST ENG
```

The differentiator is not teaching:

> "How to deploy a pod."

It is teaching:

> "How to build the platform that lets 50 teams deploy
> their pods safely, reliably, observably, and cheaply —
> without creating a bottleneck."

---

# 27. Long-Term Evolution of the Repository

After the initial curriculum is complete, add:

- New Kubernetes releases and API changes
- New platform tooling (Argo Rollouts, Flagger for progressive delivery)
- New Backstage plugins and features
- CNCF project maturity updates (new Graduated projects)
- AI-assisted platform engineering patterns
- Case studies from real platform engineering teams
- Architecture postmortems: platform incidents and what was learned
- Benchmark results: GitOps sync latency, Cilium vs iptables, etc.
- Community contributions

Create a `CHANGELOG.md` for all curriculum changes.

Keep cloud-provider-specific material isolated so that the underlying
concepts remain valid across cloud providers.

---

# 28. Final Learning Model

The entire repository can be summarized as six levels:

```text
LEVEL 1 — UNDERSTAND
Container and Kubernetes fundamentals
IaC and GitOps principles
Platform Engineering concepts


LEVEL 2 — OPERATE
Run workloads on Kubernetes
Manage infrastructure with Terraform
Deploy with ArgoCD
Observe with Prometheus and Grafana


LEVEL 3 — SECURE
Enforce policy with Kyverno
Manage secrets with ESO and Vault
Secure supply chains with Cosign and SLSA
Monitor runtime with Falco


LEVEL 4 — EXTEND
Build Kubernetes operators and CRDs
Write admission webhooks
Extend CI/CD with custom actions
Configure Cilium for L7 observability


LEVEL 5 — PLATFORM
Build an Internal Developer Platform
Design and deliver golden paths
Deliver self-service via Backstage
Measure and improve developer experience


LEVEL 6 — SCALE
Multi-cluster architecture
Fleet management with Cluster API
FinOps and cost governance
Platform SRE
```

A learner should not graduate saying:

> "I know how to use Kubernetes."

They should be able to say:

> "I understand the infrastructure and software engineering
> principles underlying modern platforms. I can build a
> self-service Internal Developer Platform, operate it with
> SLOs and on-call, secure it with policy-as-code and supply
> chain verification, and measure its impact on developer
> productivity — from first principles."

That is the standard this repository should aim for.
