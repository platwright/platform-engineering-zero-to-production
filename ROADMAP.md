# Roadmap & Full Curriculum

This is the complete map of the course. It is also the build tracker: the course
is developed in the open, so each module is marked with its current status.

## Status legend

| Marker | Meaning |
|--------|---------|
| ✅ | Complete — ready to learn |
| 🚧 | In progress / scaffolded — outline exists, content being written |
| 🗓️ | Planned — not yet started |

> **Current state:** Foundations are complete. **[00 · Orientation](./00-orientation/)**
> and **[01 · Platform Foundations](./01-platform-foundations/)** are done. Everything
> below them is scaffolded and in progress. Want to help? See
> [CONTRIBUTING.md](./CONTRIBUTING.md).

---

## Full curriculum

### Phase 0 — Orientation

- ✅ **[00 · Orientation](./00-orientation/)** — how to use this course
  - [How to use this course](./00-orientation/README.md)
  - [Learning path & tracks](./00-orientation/learning-path.md)
  - [Prerequisites & self-check](./00-orientation/prerequisites.md)
  - [Environment setup](./00-orientation/environment-setup.md)
  - [Cloud account setup](./00-orientation/cloud-account-setup.md)
  - [Glossary](./00-orientation/glossary.md)
  - [Progress tracker](./00-orientation/learning-progress.md)

### Phase 1 — Platform Engineering Foundations

- ✅ **[01 · Platform Foundations](./01-platform-foundations/)**
  - [01 · What Is Platform Engineering?](./01-platform-foundations/01-what-is-platform-engineering/)
  - [02 · Platform as a Product](./01-platform-foundations/02-platform-as-a-product/)
  - [03 · Developer Experience](./01-platform-foundations/03-developer-experience/)
  - [04 · The Internal Developer Platform](./01-platform-foundations/04-the-internal-developer-platform/)
  - [05 · Platform Team Topology](./01-platform-foundations/05-platform-team-topology/)

### Phase 2 — Containerization

- 🚧 **[02 · Containerization](./02-containerization/)**
  - Container fundamentals · Dockerfiles & image building · container networking ·
    container storage · container security · registries · multi-stage builds & optimization

### Phase 3 — Kubernetes Fundamentals

- 🚧 **[03 · Kubernetes Fundamentals](./03-kubernetes-fundamentals/)**
  - Architecture · workloads · services & networking · configuration · storage ·
    RBAC · resource management · health & scheduling · debugging & troubleshooting

### Project 1

- 🚧 **[04 · Platform Project 01 — Container Platform Foundation](./04-platform-project-01/)**

### Phase 4 — Infrastructure as Code

- 🚧 **[05 · Infrastructure as Code](./05-infrastructure-as-code/)**
  - IaC principles · Terraform fundamentals · state management · modules ·
    testing & quality · Crossplane · IaC patterns for platform teams

### Phase 5 — CI/CD for Platform Teams

- 🚧 **[06 · CI/CD for Platform Teams](./06-cicd-for-platform-teams/)**
  - CI/CD fundamentals · GitHub Actions deep dive · reusable workflows & actions ·
    pipeline templates as product · container build pipelines · IaC pipelines

### Phase 6 — Kubernetes Package Management

- 🚧 **[07 · Kubernetes Package Management](./07-kubernetes-package-management/)**
  - Helm fundamentals · Helm chart development · Kustomize · Helm vs Kustomize ·
    OCI artifacts & distribution

### Phase 7 — GitOps

- 🚧 **[08 · GitOps](./08-gitops/)**
  - GitOps principles · ArgoCD fundamentals · ApplicationSets ·
    multi-environment GitOps · secrets in GitOps · GitOps maturity model

### Project 2

- 🚧 **[09 · Platform Project 02 — GitOps Platform](./09-platform-project-02/)**

### Phase 8 — Kubernetes Advanced

- 🚧 **[10 · Kubernetes Advanced](./10-kubernetes-advanced/)**
  - Custom Resource Definitions · operators · admission webhooks ·
    API extension patterns · multi-cluster Kubernetes

### Phase 9 — Observability Engineering

- 🚧 **[11 · Observability Engineering](./11-observability-engineering/)**
  - Observability fundamentals · OpenTelemetry · Prometheus · Loki · Tempo ·
    Grafana dashboards · SLOs & error budgets · platform observability strategy

### Project 3

- 🚧 **[12 · Platform Project 03 — Observability Platform](./12-platform-project-03/)**

### Phase 10 — Security and Policy Engineering

- 🚧 **[13 · Security and Policy Engineering](./13-security-and-policy-engineering/)**
  - Security principles · RBAC deep dive · Kyverno · secret management ·
    supply chain security · image signing · runtime security · zero trust

### Phase 11 — Kubernetes Networking

- 🚧 **[14 · Kubernetes Networking](./14-kubernetes-networking/)**
  - Networking fundamentals · CNI plugins · network policies · Cilium & eBPF ·
    Gateway API · service mesh reference

### Phase 12 — Developer Experience and IDP

- 🚧 **[15 · Developer Experience and IDP](./15-developer-experience-and-idp/)**
  - IDP architecture · Backstage fundamentals · software catalog · software
    templates · plugins · golden paths · platform CLI tools · portal documentation

### Project 4

- 🚧 **[16 · Platform Project 04 — Internal Developer Platform](./16-platform-project-04/)**

### Phase 13 — Platform SRE

- 🚧 **[17 · Platform SRE](./17-platform-sre/)**
  - Platform SRE fundamentals · platform SLOs · incident management ·
    capacity planning · chaos engineering · disaster recovery

### Phase 14 — FinOps and Cost Engineering

- 🚧 **[18 · FinOps and Cost Engineering](./18-finops-and-cost-engineering/)**
  - Cloud cost fundamentals · Kubernetes cost management · cost attribution ·
    optimization patterns · FinOps culture & process

### Phase 15 — Multi-Cluster and Multi-Cloud

- 🚧 **[19 · Multi-Cluster and Multi-Cloud](./19-multi-cluster-and-multi-cloud/)**
  - Multi-cluster architecture · fleet management with Cluster API ·
    multi-cloud patterns · global load balancing & edge

### Phase 16 — Advanced Platform Topics

- 🚧 **[20 · Advanced Platform Topics](./20-advanced-platform-topics/)**
  - Platform maturity model · AI-assisted platform engineering ·
    platform metrics · platform culture

---

## Capstone projects

- 🚧 **[21 · Capstone Projects](./21-capstone-projects/)**
  1. Production Kubernetes Platform
  2. Full IDP with Backstage
  3. Multi-Cluster GitOps Platform
  4. Production Platform Reference Architecture

## Reference material

- 🚧 **[22 · Interview Preparation](./22-interview-preparation/)** — question banks per domain
- 🚧 **[23 · Cheat Sheets](./23-cheat-sheets/)** — concise quick-reference pages

---

## Learning tracks

The same core curriculum supports three tracks. Full detail in
[`00-orientation/learning-path.md`](./00-orientation/learning-path.md).

- **Track A — Platform Engineer:** Containerization → Kubernetes → IaC → CI/CD →
  GitOps → Kubernetes Advanced → Observability → Security → Networking → Platform
  SRE → FinOps → Multi-Cluster.
- **Track B — Developer Experience Engineer:** Platform Foundations → Kubernetes →
  GitOps → IDP Architecture → Backstage → Golden Paths → Platform CLI → Portal
  Docs → Platform Metrics (DX) → Culture.
- **Track C — Platform Architect:** Platform Foundations → Kubernetes Architecture →
  IaC Patterns → GitOps Patterns → Kubernetes Advanced → Security/Networking
  Architecture → IDP Architecture → Multi-Cluster → FinOps → Maturity → Metrics →
  Culture.

---

## Suggested 12-week fast track

For engineers with strong DevOps or cloud experience:

| Week | Focus |
|------|-------|
| 1 | Platform Foundations + Container deep dive |
| 2 | Kubernetes Fundamentals + Project 1 start |
| 3 | IaC (Terraform + Crossplane) + Project 1 complete |
| 4 | CI/CD + Package Management (Helm + Kustomize) |
| 5 | GitOps (ArgoCD) + Project 2 |
| 6 | Kubernetes Advanced (Operators, CRDs, Webhooks) |
| 7 | Observability Engineering + Project 3 |
| 8 | Security & Policy (Kyverno, secrets, supply chain) |
| 9 | Kubernetes Networking (Cilium, Gateway API) |
| 10 | Developer Experience & IDP (Backstage) + Project 4 |
| 11 | Platform SRE + FinOps |
| 12 | Multi-Cluster + a capstone |

---

## Target outcomes

After completing the course, a learner should be able to:

**Platform fundamentals**

- Explain what platform engineering is and how it differs from DevOps and SRE.
- Apply product thinking to an internal developer platform.
- Design a thinnest viable platform and grow it incrementally.
- Measure developer experience and platform effectiveness.
- Design team topologies appropriate for platform organizations.

**Containers and Kubernetes**

- Build minimal, secure, multi-stage container images.
- Operate production Kubernetes clusters and debug workloads confidently.
- Manage RBAC, resource quotas, network policies, and security contexts.
- Build Kubernetes operators, CRDs, and admission webhooks.

**Infrastructure as Code**

- Write, test, and operate Terraform at scale and build module libraries.
- Use Crossplane for Kubernetes-native infrastructure provisioning.
- Prevent drift and enforce IaC governance.

**GitOps**

- Design multi-environment GitOps workflows.
- Operate ArgoCD including ApplicationSets and multi-cluster patterns.
- Manage secrets safely in a GitOps model.

**Observability**

- Instrument platforms with OpenTelemetry.
- Build a complete metrics, logging, and tracing stack.
- Define and alert on SLOs and error budgets.

**Security**

- Apply policy as code with Kyverno.
- Manage secrets with External Secrets Operator and Vault.
- Implement supply chain security with SLSA, SBOMs, and Sigstore.
- Enforce runtime security with Falco.

**Networking**

- Design and troubleshoot Kubernetes networking.
- Operate Cilium with eBPF-based policy and observability.
- Configure the Kubernetes Gateway API for production traffic.

**Developer experience**

- Build an Internal Developer Platform with Backstage.
- Design and deliver golden paths and build platform CLI tools.

**Platform operations**

- Define SLOs for platform services and run GameDays and chaos experiments.
- Operate multi-cluster fleets and design disaster recovery.
- Attribute and optimize platform costs.

---

## How this roadmap is maintained

- Status markers above are updated as modules land. See the
  [CHANGELOG](./CHANGELOG.md) for dated changes.
- Each module folder owns its own content and follows the shared
  [module template](./shared/templates/module-template.md).
- Long-term additions (new Kubernetes releases, new tooling, case studies) are
  tracked as issues and reflected here.
