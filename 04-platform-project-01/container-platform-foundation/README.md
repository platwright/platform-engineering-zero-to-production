# Project 1 — Container Platform Foundation

> Build a production-grade Kubernetes cluster **foundation** with all the baseline
> platform capabilities a team needs to start deploying services safely: isolation,
> least-privilege access, resource guardrails, a hardened golden-path workload, and
> a secure build pipeline.

This project sits right after [Kubernetes Fundamentals](../../03-kubernetes-fundamentals/).
You already have everything you need to build the **core** of it today, on a free
local cluster. The production-grade pieces (Terraform, CI signing, policy
enforcement, external secrets, Cilium) are introduced in later phases — so you'll
build this in **two passes**.

---

## The two-pass approach

A real platform foundation is never finished in one sitting, and neither is this
one. Build it in two passes so you make something real **now** and grow it into
production as the course teaches each capability.

```text
PASS 1 — Build it now (free, local, on kind)        ← you can do all of this today
  • Multi-team namespaces (platform-system, team-a, team-b)
  • Per-namespace RBAC (least privilege) + a CI deployer ServiceAccount
  • LimitRanges + ResourceQuotas per team namespace
  • A hardened, non-root, read-only golden-path workload
  • A bootstrap script and a cleanup script

PASS 2 — Upgrade to production (as later phases teach it)
  • Terraform provisions GKE + VPC + node pools + GCS state   → Phase 4 (IaC)
  • CI pipeline: build → Trivy scan → Cosign sign → push      → Phases 5–6 (CI/CD)
  • Non-root/read-only enforced by Kyverno policy             → Phase 13 (Security)
  • Secrets via External Secrets Operator + GCP Secret Manager→ Phase 13 (Security)
  • Cilium CNI with default-deny NetworkPolicies              → Phase 14 (Networking)
```

Each Pass 2 item has a pointer to the exact phase that teaches it. You don't need to
wait — but you also shouldn't block Pass 1 on skills you haven't learned yet.

---

## What you'll build (target architecture)

```text
GitHub
  │
  ▼
GitHub Actions (CI)
  │   Build → Scan (Trivy) → Sign (Cosign) → Push
  ▼
GHCR / Artifact Registry  ──(immutable digest)──┐
                                                │
GKE Cluster (provisioned by Terraform)          │
  ├─ Namespaces: platform-system, team-a, team-b│
  ├─ RBAC: per-namespace roles + CI deployer SA  │
  ├─ LimitRanges + ResourceQuotas per namespace  │
  ├─ Kyverno: non-root, read-only, signed images◄┘
  ├─ External Secrets Operator → GCP Secret Manager
  └─ Cilium CNI + default-deny NetworkPolicies
```

Mapped to the **five planes** of an IDP (from
[Module 01.4](../../01-platform-foundations/04-the-internal-developer-platform/README.md)):

| Plane | This project provides |
|-------|-----------------------|
| Developer control plane | `kubectl` + namespaces as the team's entry point (a portal/CLI comes later) |
| Integration & delivery | CI build→scan→sign→push pipeline (Pass 2) |
| Resource plane | The GKE cluster, namespaces, quotas (Terraform in Pass 2) |
| Monitoring plane | Baseline cluster metrics (stretch goal; full stack in Phase 9) |
| Security plane | RBAC, non-root/read-only, signed images, external secrets |

See [architecture/architecture.md](./architecture/architecture.md) for the full
component inventory and the decisions behind it.

---

## Requirements

From the course outline. The **Status** column shows what you build in Pass 1 vs the
phase that completes it in Pass 2.

| # | Requirement | Pass | Taught in |
|---|-------------|------|-----------|
| 1 | Cluster, VPC, node pools, remote state provisioned as code | 2 | [Phase 4 · IaC](../../05-infrastructure-as-code/) |
| 2 | Namespaces with RBAC for 3 teams | **1** | [Phase 3 · RBAC](../../03-kubernetes-fundamentals/06-rbac/) |
| 3 | LimitRanges and ResourceQuotas per team namespace | **1** | [Phase 3 · Resource management](../../03-kubernetes-fundamentals/07-resource-management/) |
| 4 | CI pipeline: build → Trivy scan → Cosign sign → push | 2 | [Phase 5 · CI/CD](../../06-cicd-for-platform-teams/) |
| 5 | Deployment blocked if critical CVEs found | 2 | [Phase 5 · CI/CD](../../06-cicd-for-platform-teams/) |
| 6 | Non-root, read-only containers enforced by policy | **1** (by hand) → 2 (Kyverno) | [Phase 13 · Security](../../13-security-and-policy-engineering/) |
| 7 | Secrets via External Secrets Operator + Secret Manager | 2 | [Phase 13 · Security](../../13-security-and-policy-engineering/) |

**Stretch goals:** node auto-provisioning (Karpenter), cluster upgrade automation,
basic Prometheus cluster monitoring (full observability is
[Phase 9](../../11-observability-engineering/)).

---

## Prerequisites

- Completed [Phase 1](../../01-platform-foundations/), [Phase 2](../../02-containerization/),
  and [Phase 3](../../03-kubernetes-fundamentals/).
- Core tools installed (see [environment setup](../../00-orientation/environment-setup.md)):
  Docker, `kubectl`, and `kind`. For Pass 2: Terraform, `gcloud`, `cosign`, `trivy`.
- For Pass 2 cloud work: a GCP project with a **budget alert**
  ([cloud account setup](../../00-orientation/cloud-account-setup.md)).

---

## Build it

The full, staged, copy-pasteable walkthrough is the project's lab:

➡️ **[Build guide — step by step](./build-guide.md)**

Pass 1 is a single sitting on a local `kind` cluster using the manifests in
[`kubernetes/`](./kubernetes/). Run it end to end, break it on purpose (exceed a
quota, try an action your RBAC forbids), and confirm the guardrails hold.

Quick start:

```bash
# From this project directory
./scripts/bootstrap.sh     # create a kind cluster and apply the platform foundation
# ... explore, test the guardrails (see the build guide) ...
./scripts/cleanup.sh       # tear everything down
```

---

## Repository layout

```text
container-platform-foundation/
├── README.md                 # you are here
├── build-guide.md            # the staged build walkthrough (the project "lab")
├── architecture/
│   ├── architecture.md       # full architecture + component inventory
│   ├── decisions/            # ADRs (why GKE, why Cilium, why Kyverno, why ESO)
│   └── diagrams/             # put exported diagrams here
├── kubernetes/
│   ├── platform/             # namespaces, RBAC, LimitRanges, ResourceQuotas
│   └── apps/                 # a hardened sample golden-path workload
├── terraform/                # Pass 2 — GKE/VPC/state (Phase 4)
├── helm/                     # Pass 2 — chart packaging (Phase 6)
├── docs/
│   ├── onboarding.md         # how a new team gets onboarded onto this foundation
│   └── runbooks/             # operational runbooks
├── scripts/
│   ├── bootstrap.sh          # create kind cluster + apply platform foundation
│   └── cleanup.sh            # tear down
└── .github/workflows/        # Pass 2 — CI build→scan→sign→push (Phases 5–6)
```

---

## Portfolio-ready checklist

This project is portfolio-ready (and "done" for Pass 1) when you can tick:

- [ ] Clear problem statement and architecture diagram in the README
- [ ] Reproducible from scratch: `./scripts/bootstrap.sh` builds it on a clean machine
- [ ] Three namespaces with **least-privilege** RBAC (verified with `kubectl auth can-i`)
- [ ] LimitRanges + ResourceQuotas enforced (you demonstrated a quota blocking a deploy)
- [ ] A workload running **non-root** with a **read-only** root filesystem and dropped capabilities
- [ ] A CI deployer ServiceAccount that can deploy to one namespace and nothing else
- [ ] At least one [ADR](./architecture/decisions/) explaining a key decision
- [ ] An [onboarding guide](./docs/onboarding.md) for a new team
- [ ] Cleanup works and leaves nothing running (no surprise cloud bill)

Pass 2 adds: IaC for all infra, a signing CI pipeline, policy enforcement, external
secrets, network policy, and runbooks for 3+ failure modes.

---

## Cost & cleanup

- **Pass 1 costs nothing** — it runs entirely on a local `kind` cluster.
- **Pass 2 touches the cloud.** Set a budget alert first, prefer the smallest node
  sizes, use spot where possible, and **always** run cleanup. The cleanest teardown
  is to delete the whole GCP project.
- Every build step in the [build guide](./build-guide.md) has a matching cleanup.

```bash
./scripts/cleanup.sh         # removes the kind cluster and all Pass 1 resources
```

---

## Architecture decisions

The choices behind this foundation are documented as ADRs you can read and
challenge:

- [ADR-001 — Why GKE over self-managed Kubernetes](./architecture/decisions/ADR-001-why-gke.md)
- [ADR-002 — Why Cilium as the CNI](./architecture/decisions/ADR-002-why-cilium.md)
- [ADR-004 — Why Kyverno for policy](./architecture/decisions/ADR-004-why-kyverno.md)
- [ADR-005 — Why External Secrets Operator](./architecture/decisions/ADR-005-why-external-secrets-operator.md)

---

_Previous:_ [03 · Kubernetes Fundamentals](../../03-kubernetes-fundamentals/)
· _Next:_ [05 · Infrastructure as Code](../../05-infrastructure-as-code/)
