# Learning Progress Tracker

Copy this file to a personal, **untracked** file and update it as you go:

```bash
cp 00-orientation/learning-progress.md my-learning-progress.md
```

(`my-learning-progress.md` isn't special-cased by `.gitignore`; keep it out of any
PR. It's yours.)

## How to use it

Each module is **done** when you can check all five boxes:

```text
[ ] Theory completed                     — you read and understood the lesson
[ ] Lab completed                        — you did the lab and produced its deliverable
[ ] Architecture reviewed                — you studied the diagrams/mental model
[ ] Assessment completed                 — you answered the questions honestly
[ ] Production considerations documented — you noted what changes at scale
```

> On GitHub, the `- [ ]` boxes below are clickable. Tick them as you progress.

---

## Overall progress

- [ ] Phase 0 — Orientation
- [ ] Phase 1 — Platform Foundations
- [ ] Phase 2 — Containerization
- [ ] Phase 3 — Kubernetes Fundamentals
- [ ] Project 1 — Container Platform Foundation
- [ ] Phase 4 — Infrastructure as Code
- [ ] Phase 5 — CI/CD for Platform Teams
- [ ] Phase 6 — Kubernetes Package Management
- [ ] Phase 7 — GitOps
- [ ] Project 2 — GitOps Platform
- [ ] Phase 8 — Kubernetes Advanced
- [ ] Phase 9 — Observability Engineering
- [ ] Project 3 — Observability Platform
- [ ] Phase 10 — Security and Policy Engineering
- [ ] Phase 11 — Kubernetes Networking
- [ ] Phase 12 — Developer Experience and IDP
- [ ] Project 4 — Internal Developer Platform
- [ ] Phase 13 — Platform SRE
- [ ] Phase 14 — FinOps and Cost Engineering
- [ ] Phase 15 — Multi-Cluster and Multi-Cloud
- [ ] Phase 16 — Advanced Platform Topics
- [ ] Capstone(s) completed

---

## Phase 0 — Orientation

- [ ] Read [How to use this course](./README.md)
- [ ] Chose a [learning path / track](./learning-path.md)
- [ ] Confirmed [prerequisites](./prerequisites.md) (ran the prereq checker)
- [ ] Completed [environment setup](./environment-setup.md) (core tools green)
- [ ] Reviewed [cloud account setup](./cloud-account-setup.md) and **set a budget alert**
- [ ] Skimmed the [glossary](./glossary.md)

---

## Phase 1 — Platform Foundations

### 01.1 — What Is Platform Engineering?

- [ ] Theory completed
- [ ] Lab completed (interview 3 engineers; themes identified)
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

### 01.2 — Platform as a Product

- [ ] Theory completed
- [ ] Lab completed (one-page Platform Product Brief)
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

### 01.3 — Developer Experience

- [ ] Theory completed
- [ ] Lab completed (Time to Hello World in Production audit)
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

### 01.4 — The Internal Developer Platform

- [ ] Theory completed
- [ ] Lab completed (IDP capability assessment)
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

### 01.5 — Platform Team Topology

- [ ] Theory completed
- [ ] Lab completed (Platform Team Charter)
- [ ] Architecture reviewed
- [ ] Assessment completed
- [ ] Production considerations documented

---

## Later phases

These expand into the full five-point checklist as each module is published. For
now, track them at the module level. See the [ROADMAP](../ROADMAP.md) for status.

<details>
<summary><strong>Phase 2 — Containerization</strong></summary>

- [ ] Container fundamentals
- [ ] Dockerfile and image building
- [ ] Container networking
- [ ] Container storage
- [ ] Container security
- [ ] Container registries
- [ ] Multi-platform builds and optimization

</details>

<details>
<summary><strong>Phase 3 — Kubernetes Fundamentals</strong></summary>

- [ ] Kubernetes architecture
- [ ] Workloads
- [ ] Services and networking
- [ ] Configuration
- [ ] Storage
- [ ] RBAC
- [ ] Resource management
- [ ] Health, probes and scheduling
- [ ] Debugging and troubleshooting

</details>

<details>
<summary><strong>Project 1 — Container Platform Foundation</strong></summary>

- [ ] Terraform-provisioned GKE cluster, VPC, node pools
- [ ] Namespaces + RBAC for multiple teams
- [ ] LimitRanges and ResourceQuotas
- [ ] CI pipeline: build → scan → sign → push
- [ ] Policy enforcement (Kyverno) + secrets via ESO
- [ ] README, architecture diagram, cleanup verified

</details>

<details>
<summary><strong>Phase 4 — Infrastructure as Code</strong></summary>

- [ ] IaC principles
- [ ] Terraform fundamentals
- [ ] Terraform state management
- [ ] Terraform modules
- [ ] Terraform testing and quality
- [ ] Crossplane
- [ ] IaC patterns for platform teams

</details>

<details>
<summary><strong>Phase 5 — CI/CD for Platform Teams</strong></summary>

- [ ] CI/CD fundamentals for platform teams
- [ ] GitHub Actions deep dive
- [ ] Reusable workflows and composite actions
- [ ] Pipeline templates as a product
- [ ] Container build pipelines
- [ ] IaC pipelines

</details>

<details>
<summary><strong>Phase 6 — Kubernetes Package Management</strong></summary>

- [ ] Helm fundamentals
- [ ] Helm chart development
- [ ] Kustomize
- [ ] Helm vs Kustomize
- [ ] OCI artifacts and distribution

</details>

<details>
<summary><strong>Phase 7 — GitOps</strong></summary>

- [ ] GitOps principles
- [ ] ArgoCD fundamentals
- [ ] ArgoCD ApplicationSets
- [ ] Multi-environment GitOps
- [ ] Secrets in GitOps
- [ ] GitOps maturity model

</details>

<details>
<summary><strong>Project 2 — GitOps Platform</strong></summary>

- [ ] Multi-environment delivery via ArgoCD
- [ ] App-of-apps / ApplicationSets
- [ ] Safe secret handling
- [ ] Promotion workflow with gates

</details>

<details>
<summary><strong>Phase 8 — Kubernetes Advanced</strong></summary>

- [ ] Custom Resource Definitions
- [ ] Kubernetes operators
- [ ] Admission webhooks
- [ ] API extension patterns
- [ ] Multi-cluster Kubernetes

</details>

<details>
<summary><strong>Phase 9 — Observability Engineering</strong></summary>

- [ ] Observability fundamentals
- [ ] OpenTelemetry
- [ ] Metrics with Prometheus
- [ ] Logging with Loki
- [ ] Distributed tracing with Tempo
- [ ] Grafana dashboards
- [ ] SLOs and error budgets
- [ ] Platform observability strategy

</details>

<details>
<summary><strong>Project 3 — Observability Platform</strong></summary>

- [ ] OTel Collector (DaemonSet + gateway)
- [ ] Prometheus / Loki / Tempo / Alertmanager / Grafana
- [ ] Platform overview dashboard as code
- [ ] SLOs + burn-rate alerts with runbooks

</details>

<details>
<summary><strong>Phase 10 — Security and Policy Engineering</strong></summary>

- [ ] Security principles for platform teams
- [ ] Kubernetes RBAC deep dive
- [ ] Policy as code with Kyverno
- [ ] Secret management
- [ ] Supply chain security
- [ ] Image signing and verification
- [ ] Runtime security
- [ ] Zero trust for platforms

</details>

<details>
<summary><strong>Phase 11 — Kubernetes Networking</strong></summary>

- [ ] Networking fundamentals
- [ ] CNI plugins
- [ ] Network policies
- [ ] Cilium and eBPF
- [ ] Kubernetes Gateway API
- [ ] Service mesh reference

</details>

<details>
<summary><strong>Phase 12 — Developer Experience and IDP</strong></summary>

- [ ] IDP architecture
- [ ] Backstage fundamentals
- [ ] Backstage software catalog
- [ ] Backstage software templates
- [ ] Backstage plugins
- [ ] Golden paths
- [ ] Platform CLI tools
- [ ] Developer portal documentation

</details>

<details>
<summary><strong>Project 4 — Internal Developer Platform</strong></summary>

- [ ] Backstage deployed and configured
- [ ] Golden-path service templates
- [ ] Core plugins (ArgoCD, Kubernetes, Grafana, cost)
- [ ] Platform CLI for common tasks

</details>

<details>
<summary><strong>Phase 13 — Platform SRE</strong></summary>

- [ ] Platform SRE fundamentals
- [ ] Platform SLOs
- [ ] Incident management
- [ ] Capacity planning
- [ ] Chaos engineering
- [ ] Disaster recovery

</details>

<details>
<summary><strong>Phase 14 — FinOps and Cost Engineering</strong></summary>

- [ ] Cloud cost fundamentals
- [ ] Kubernetes cost management
- [ ] Cost attribution and chargeback
- [ ] Cost optimization patterns
- [ ] FinOps culture and process

</details>

<details>
<summary><strong>Phase 15 — Multi-Cluster and Multi-Cloud</strong></summary>

- [ ] Multi-cluster architecture
- [ ] Fleet management with Cluster API
- [ ] Multi-cloud platform patterns
- [ ] Global load balancing and edge

</details>

<details>
<summary><strong>Phase 16 — Advanced Platform Topics</strong></summary>

- [ ] Platform engineering maturity model
- [ ] AI-assisted platform engineering
- [ ] Platform engineering metrics
- [ ] Platform engineering culture and organization

</details>

<details>
<summary><strong>Capstones</strong></summary>

- [ ] Capstone 1 — Production Kubernetes Platform
- [ ] Capstone 2 — Full IDP with Backstage
- [ ] Capstone 3 — Multi-Cluster GitOps Platform
- [ ] Capstone 4 — Production Platform Reference Architecture

</details>

---

_Keep going. Depth beats speed._
