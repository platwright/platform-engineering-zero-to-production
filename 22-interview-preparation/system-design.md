# Interview Prep — Platform Architecture and System Design

> This domain tests senior and staff signal: can you structure an open-ended
> design, state assumptions, and reason about trade-offs rather than name tools?
> Interviewers care how you think — requirements first, then a layered design,
> then how you would measure success. Practice answering out loud with a clear
> spine, and treat each checklist below as the structure to talk through.

## How to approach a platform design interview

Open-ended prompts reward structure over trivia. A reliable spine:

- **Clarify and scope** — ask about scale, teams, clouds, compliance, and existing estate before designing. State your assumptions explicitly.
- **Lead with requirements** — functional (what teams need) and non-functional (reliability, security, cost, isolation).
- **Design in layers** — clusters and tenancy, networking, security, delivery/GitOps, observability, cost, and the self-service interface on top.
- **Name trade-offs** — every choice has a cost; say what you are optimizing for and what you give up.
- **Close with success metrics** — adoption, DORA, platform SLOs, and cost, because a platform is a product.
- **Treat it as a product** — start from a Thinnest Viable Platform and grow by demand, not a big-bang build.

## Design prompts

### Design: a Kubernetes platform for 100 development teams

**Clarifying questions:**

- One cloud or several? Regulatory or data-residency constraints? Expected workload types (stateless, stateful, batch, ML)?
- How strong must tenant isolation be — trusted internal teams, or hostile multi-tenancy?
- What exists today, and what is the adoption and migration appetite?

**A strong answer covers:**

- **Requirements** — self-service for 100 teams, strong-enough isolation, secure and observable by default, cost attribution, and low cognitive load.
- **Cluster and namespace design** — namespace-per-team (or per-service) as the default tenancy unit, with a few larger clusters per environment/region rather than 100 tiny clusters; reserved clusters only for workloads that need hard isolation. Use ResourceQuotas and LimitRanges per namespace.
- **Networking** — a flat pod network via one CNI (Cilium), **default-deny NetworkPolicy** per namespace, and a shared ingress/Gateway with per-team routes.
- **Security** — RBAC least privilege with a ServiceAccount per workload, **Restricted** Pod Security, Kyverno guardrails (limits, non-root, signed images, required labels), and externally managed secrets.
- **Delivery / GitOps** — a golden-path pipeline plus ArgoCD; teams ship by pull request; ApplicationSets template apps per team/cluster.
- **Observability** — OTel defaults, multi-tenant Prometheus/Loki/Tempo/Grafana, and SLO templates so every service is observable by default.
- **Cost** — enforced cost labels, OpenCost attribution, right-sizing, spot for interruptible work, Karpenter consolidation, and showback per team.
- **Self-service** — a portal/CLI and templates (the developer control plane) that orchestrate repo, pipeline, resources, observability, and security from one request.
- **Measuring success** — adoption percentage, time-to-first-deploy, DORA for teams on versus off the platform, platform SLOs, and cost per team.

**Going deeper:** [19.1 · Multi-Cluster Architecture](../19-multi-cluster-and-multi-cloud/01-multi-cluster-architecture/) and [21.1 · Production Kubernetes Platform](../21-capstone-projects/01-production-kubernetes-platform/)

### Design: self-service environment provisioning

**Clarifying questions:**

- What is an "environment" — a namespace, a set of cloud resources, or a whole cluster? Ephemeral (per-PR) or long-lived?
- Which backing resources are needed (databases, queues, buckets)? How fast must provisioning be?
- Who approves, and what are the guardrails and TTLs?

**A strong answer covers:**

- **Requirements** — a team requests an environment and gets it in minutes, consistently, with guardrails, and it is cleaned up automatically.
- **Interface** — one declarative request: a manifest, a portal form, or a CLI command (the developer control plane), not a ticket.
- **Orchestration** — the request fans across planes: namespace + quotas, resources via **Crossplane/Terraform**, GitOps wiring, observability, RBAC, and secrets.
- **Resource plane** — prefer **Crossplane Claims** for a Kubernetes-native, continuously reconciled, RBAC-gated self-service API; Terraform where the ecosystem fits.
- **Guardrails and lifecycle** — policy as code on every request, **TTL and auto-teardown** for ephemeral environments to control cost, and quotas to cap blast radius.
- **GitOps** — the environment's desired state lands in Git; ArgoCD reconciles it, so it is reproducible and auditable.
- **Measuring success** — provisioning lead time, success rate, idle/leaked environment cost, and adoption.

**Going deeper:** [15.1 · IDP Architecture](../15-developer-experience-and-idp/01-idp-architecture/) and [05.6 · Crossplane](../05-infrastructure-as-code/06-crossplane/)

### Design: a GitOps multi-environment promotion workflow

**Clarifying questions:**

- How many environments (dev, staging, prod) and regions? What gates are required for prod (approvals, compliance)?
- Monorepo or repo-per-app for config? Who owns the promotion decision?
- What is the rollback expectation and the change-failure tolerance?

**A strong answer covers:**

- **Source of truth** — Git holds desired state; CI builds and tests and publishes an **immutable image digest**.
- **Environment modeling** — a shared base with per-environment **Kustomize overlays** or Helm values, so only the version and genuine differences vary.
- **Promotion** — promotion is a **Git change** moving the **same tested digest** from dev to staging to prod via **pull request**, never a rebuild per environment.
- **Gating** — PR review and **policy as code** on prod; optional progressive delivery (canary/blue-green via Argo Rollouts) with automated analysis.
- **Reconciliation** — ArgoCD (with ApplicationSets) reconciles each environment and self-heals drift.
- **Rollback** — `git revert` or re-point to the previous known-good revision; deterministic because state is versioned and immutable.
- **Measuring success** — lead time through environments, change-failure rate, and time to restore.

**Going deeper:** [08.4 · Multi-Environment GitOps](../08-gitops/04-multi-environment-gitops/) and [07.3 · Kustomize](../07-kubernetes-package-management/03-kustomize/)

### Design: multi-cluster fleet management

**Clarifying questions:**

- Why multiple clusters — scale, blast-radius isolation, region/latency, compliance, or multi-cloud? How many, and growing how fast?
- Do workloads span clusters, or is each self-contained? What is the networking model between them?
- One control plane of record, or fully independent clusters?

**A strong answer covers:**

- **Drivers and topology** — justify the cluster count (isolation, locality, regulation) and avoid needless sprawl; pick hub-and-spoke or regional cells.
- **Cluster lifecycle** — provision clusters declaratively with **Cluster API** (clusters as Kubernetes resources) so creation, upgrade, and teardown are reconciled, not clicked.
- **Fleet delivery** — a single GitOps control plane with **ApplicationSet cluster generators** rolls workloads and platform add-ons across the fleet from one source of truth.
- **Consistency** — the same golden paths, policies (Kyverno), and baselines applied everywhere, with per-cluster overrides via generators.
- **Networking and identity** — cross-cluster connectivity only where needed (mesh or Cilium Cluster Mesh), global DNS/load balancing, and federated identity.
- **Observability and cost** — centralized multi-cluster metrics/logs/traces and per-cluster/per-team cost attribution.
- **Measuring success** — time to stand up or upgrade a cluster, config-drift rate across the fleet, and fleet-wide policy compliance.

**Going deeper:** [19.2 · Fleet Management with Cluster API](../19-multi-cluster-and-multi-cloud/02-fleet-management-with-cluster-api/) and [21.3 · Multi-Cluster GitOps Platform](../21-capstone-projects/03-multi-cluster-gitops-platform/)

### Design: how you would measure the success of a platform team

**Clarifying questions:**

- What outcome does leadership care about — delivery speed, reliability, cost, security posture, or retention?
- Is adoption voluntary? What baseline exists to compare against?
- What time horizon and what is the current maturity?

**A strong answer covers:**

- **Adoption first** — percentage of teams and services on the golden path; this is the headline, since a platform is a product and adoption is the scoreboard.
- **Delivery outcomes** — **DORA** (deployment frequency, lead time, change-failure rate, time to restore) for teams on versus off the platform.
- **Developer experience** — satisfaction and friction surveys, **time-to-first-deploy** for a new service, and SPACE-style signals.
- **Reliability** — **platform SLOs** and error-budget health for the self-service journeys teams depend on.
- **Cost** — cost per team/service and **unit economics** trending flat or down as usage grows.
- **Anti-patterns to call out** — vanity metrics (clusters managed, YAML written) and using delivery metrics to rank individuals.

**Going deeper:** [20.3 · Platform Engineering Metrics](../20-advanced-platform-topics/03-platform-engineering-metrics/) and [01.2 · Platform as a Product](../01-platform-foundations/02-platform-as-a-product/)

### Design: a secrets management strategy for the platform

**Clarifying questions:**

- Where do secrets live today, and what compliance/rotation requirements apply?
- Is delivery GitOps-based? Which clouds and secret stores are available?
- Who needs access, and at what granularity?

**A strong answer covers:**

- **Principle** — no cleartext in Git ever; Git holds an **encrypted blob or a reference**, never the value.
- **Storage** — a dedicated manager (Vault or cloud secrets manager) as the system of record.
- **Delivery** — **External Secrets Operator** to sync into the cluster, or **Sealed Secrets**/**SOPS** for GitOps, or the **CSI Secrets Store** to keep secrets out of etcd.
- **At rest and access** — enable **encryption at rest** (KMS-backed), tight **RBAC** on Secrets, and avoid env-var exposure.
- **Identity and rotation** — workload identity (SPIFFE/IRSA) and **short-lived credentials**, OIDC federation from CI instead of static keys, and automated rotation.
- **Guardrails** — policy to block plaintext Secrets and enforce the approved pattern.
- **Measuring success** — zero plaintext secrets in repos, rotation coverage, and time-to-revoke.

**Going deeper:** [13.4 · Secret Management](../13-security-and-policy-engineering/04-secret-management/) and [08.5 · Secrets in GitOps](../08-gitops/05-secrets-in-gitops/)

### Design: multi-tenant isolation on a shared cluster

**Clarifying questions:**

- Are tenants trusted internal teams or mutually untrusted? Any regulated workloads?
- What is the acceptable blast radius if one tenant misbehaves?
- Soft isolation (namespaces) acceptable, or is hard isolation required?

**A strong answer covers:**

- **Tenancy model** — namespace-per-tenant for trusted teams; separate node pools or clusters for workloads needing hard isolation.
- **Resource isolation** — **ResourceQuotas** and **LimitRanges** per namespace so no tenant starves others; priority classes for critical workloads.
- **Network isolation** — **default-deny NetworkPolicy** per namespace, opening only required flows; identity-based policy with Cilium.
- **Access isolation** — RBAC scoped per namespace, ServiceAccount per workload, no shared cluster-admin.
- **Policy** — Kyverno guardrails (Restricted Pod Security, required labels, no host access) applied to every namespace, generated on namespace creation.
- **Noisy-neighbor and cost** — right-sized requests, consolidation, and per-tenant cost attribution.
- **Measuring success** — isolation incidents, quota-breach rate, and unallocated cost.

**Going deeper:** [13.2 · Kubernetes RBAC Deep Dive](../13-security-and-policy-engineering/02-kubernetes-rbac-deep-dive/) and [14.3 · Network Policies](../14-kubernetes-networking/03-network-policies/)

### Design: the observability stack for the platform

**Clarifying questions:**

- Who are the consumers — app teams, the platform team, or both? What retention and compliance apply?
- Expected scale and cardinality? Build on open source or buy?
- What must be observable by default versus opt-in?

**A strong answer covers:**

- **Requirements** — every service observable by default, shared tooling, controlled cost, and SLO support.
- **Instrumentation** — **OpenTelemetry** defaults with a **Collector** so apps are backend-agnostic.
- **Backends** — multi-tenant metrics (Prometheus/Mimir), logs (Loki), traces (Tempo), and Grafana for a single pane.
- **SLOs and alerting** — SLO templates and **multi-window, multi-burn-rate** alerts on symptoms, not causes.
- **Cost and scale** — manage **cardinality**, retention, and **tail sampling** so observability does not become the biggest bill.
- **Self-service** — golden-path dashboards and alerts provisioned with each new service.
- **Measuring success** — coverage (services with golden signals and SLOs), MTTD/MTTR, and telemetry cost per service.

**Going deeper:** [11.8 · Platform Observability Strategy](../11-observability-engineering/08-platform-observability-strategy/) and [12 · Observability Platform project](../12-platform-project-03/observability-platform/README.md)

### Design: a migration that moves 100 existing services onto the platform

**Clarifying questions:**

- Is adoption mandated or voluntary? What is the current state of these services and their teams?
- What is the business driver and deadline? Who are the likely early adopters?
- What does "migrated" mean — repo, pipeline, runtime, observability?

**A strong answer covers:**

- **Product framing** — treat adoption as a product problem: the paved road must be genuinely **easier** than the status quo, not merely mandated.
- **Start thin** — a **Thinnest Viable Platform** that solves one real, observed pain, validated with a few friendly early-adopter teams.
- **Golden path and templates** — a "create/onboard a service" template that wires repo, CI, manifests, observability, and policy, so onboarding is minutes not weeks.
- **Incremental migration** — strangler-style, service by service, with escape hatches; avoid a risky big-bang cutover.
- **Enablement** — docs, support channel, and enabling-team pairing; publish migration guides.
- **Guardrails** — policy to keep migrated services compliant without blocking teams.
- **Measuring success** — adoption curve, time-to-onboard, DORA deltas for migrated teams, and support-ticket volume trending down.

**Going deeper:** [01.2 · Platform as a Product](../01-platform-foundations/02-platform-as-a-product/) and [20.1 · Platform Engineering Maturity Model](../20-advanced-platform-topics/01-platform-engineering-maturity-model/)
