<!-- markdownlint-disable MD033 -->
<div align="center">

# Platform Engineering — From Zero to Production

**Build and operate production-grade Internal Developer Platforms, Kubernetes platforms, and the tooling and culture that let software teams ship fast without drowning in operational debt.**

[![License: CC BY-SA 4.0](https://img.shields.io/badge/Content-CC%20BY--SA%204.0-lightgrey.svg)](./LICENSE)
[![Code License: MIT](https://img.shields.io/badge/Code-MIT-blue.svg)](./LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](./CONTRIBUTING.md)
[![Status: In Progress](https://img.shields.io/badge/status-in%20progress-orange.svg)](./ROADMAP.md)

</div>

> **This is not a course about running `kubectl` commands.**
> It is a course about building the platforms that *other* engineers build on —
> and understanding everything from first principles.

A free, self-paced, open-source course. No paywalls, no cohort fees, no gatekeeping.
Work through it at your own pace, in the open, and build a portfolio of real
platform systems while you learn.

---

## Why this course exists

Great platform engineering courses are usually expensive, locked inside cohorts,
or reduced to a tour of tools. This repository takes a different stance:

> Understand the problem first. Build the smallest solution yourself.
> Then use the production tool. Know **why** every component exists.

Engineers who only know the tools — without understanding the problems those tools
solve — build fragile platforms that nobody wants to use. This course is designed
to make you the engineer who understands the *why*, not just the *how*.

---

## What you'll learn

By the end of this course you will be able to:

- Explain what platform engineering is, and how it differs from DevOps and SRE.
- Apply **product thinking** to an internal developer platform.
- Build minimal, secure, multi-stage container images.
- Operate, secure, and debug production Kubernetes clusters.
- Write and test Terraform at scale and provision infrastructure with Crossplane.
- Design multi-environment GitOps workflows with ArgoCD.
- Build Kubernetes operators, CRDs, and admission webhooks.
- Instrument platforms with OpenTelemetry and run a full metrics/logs/traces stack.
- Enforce policy-as-code, manage secrets safely, and secure the software supply chain.
- Build an Internal Developer Platform with Backstage and design golden paths.
- Define SLOs, run GameDays, and operate multi-cluster fleets.
- Attribute and optimize platform cost (FinOps).

See [Target Outcomes in the ROADMAP](./ROADMAP.md) for the complete, detailed list.

---

## Who this is for

This course is for engineers moving into — or formalizing — platform work:

- Software engineers moving into platform roles
- DevOps engineers formalizing platform engineering practices
- SREs building internal platforms
- Cloud and infrastructure engineers building self-service systems
- Technical leads evaluating platform engineering adoption

**Assumed background** (no Kubernetes or platform experience required):

```text
Comfortable with the Linux command line
Basic Git and GitHub
Basic Python or another scripting language
Basic cloud concepts
```

Not sure you're ready? Start with
[`00-orientation/prerequisites.md`](./00-orientation/prerequisites.md) — it has a
self-check and links to fill any gaps.

---

## The platform you'll build

You don't just read — you build. Across four projects and four capstones you will
assemble, piece by piece, a production-grade Internal Developer Platform:

```text
                     Developer
                         │
                         ▼
                    IDP (Backstage) ── CLI ── API
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         Golden-path templates (service scaffolds)
              │          │          │
              └──────────┼──────────┘
                         ▼
                Platform CI/CD (GitHub Actions)
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
             Dev      Staging     Prod
          (auto-sync) (auto-sync) (manual gate)   ← ArgoCD GitOps
                         ▼
               Platform services layer
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
   GitOps Engine    Observability     Security & Policy
   (ArgoCD)        (OTel + LGTM)      (Kyverno, ESO, Falco)
                         ▼
                 Kubernetes (GKE) + Cloud
```

---

## Course architecture

Every module follows the same learning arc, because tool-first teaching produces
fragile engineers:

```text
Concept → Why it matters → Mental model → Minimal implementation →
Hands-on lab → Production considerations → Common mistakes →
Assessment → Further reading
```

The curriculum progresses from foundations to scale:

```text
Platform Foundations → Containerization → Kubernetes Fundamentals →
Infrastructure as Code → CI/CD → Package Management → GitOps →
Kubernetes Advanced → Observability → Security & Policy → Networking →
Developer Experience & IDP → Platform SRE → FinOps → Multi-Cluster →
Advanced Topics → Capstones
```

---

## Projects and capstones

Theory is scaffolding; the projects are where it becomes skill.

| # | Project | You build |
|---|---------|-----------|
| 1 | Container Platform Foundation | A GKE cluster foundation with RBAC, quotas, CI build→scan→sign→push, and policy enforcement |
| 2 | GitOps Platform | Multi-environment GitOps delivery with ArgoCD and safe secret management |
| 3 | Observability Platform | A full OTel + Prometheus/Loki/Tempo/Grafana stack with SLOs, delivered via GitOps |
| 4 | Internal Developer Platform | A Backstage IDP with golden paths, catalog, and self-service |

**Capstones:** a production Kubernetes platform, a full IDP, a multi-cluster GitOps
platform, and a complete reference architecture another organization could adopt.
See the [ROADMAP](./ROADMAP.md#capstone-projects).

---

## Technology stack

The course deliberately avoids tool sprawl — **one primary tool per problem**.

| Area | Primary tools |
|------|---------------|
| Languages | Python, Go, Bash |
| Containers | Docker / BuildKit, Docker Compose, crane / skopeo |
| Kubernetes | Kubernetes (GKE), kubectl, Kustomize, Helm, kind / k3d |
| IaC | Terraform, Crossplane, tfsec / Checkov, Terratest |
| CI/CD | GitHub Actions, OIDC (keyless auth) |
| GitOps | ArgoCD, External Secrets Operator / Sealed Secrets |
| Observability | OpenTelemetry, Prometheus, Loki, Tempo, Grafana, Alertmanager |
| Security | Kyverno, External Secrets Operator, Vault, Cosign / Sigstore, Falco |
| Networking | Cilium, Hubble, Kubernetes Gateway API |
| Developer platform | Backstage, Cobra + Viper (Go), MkDocs |
| Cloud | Google Cloud (GKE, GCS, Artifact Registry, Secret Manager) |

> Cloud-specific material is kept isolated so the underlying concepts stay valid
> across providers. AWS and Azure appear as optional references.

---

## How to start

```bash
# 1. Clone the repository
git clone https://github.com/<your-org>/platform-engineering-from-zero-to-production.git
cd platform-engineering-from-zero-to-production

# 2. Read the orientation module first — it explains how everything works
#    and how to set up your environment.
#    -> 00-orientation/README.md

# 3. Copy the progress tracker and start checking things off
cp 00-orientation/learning-progress.md my-learning-progress.md
```

Then begin the curriculum:

1. **[00 · Orientation](./00-orientation/)** — how the course works, prerequisites,
   environment setup, cloud setup, and the glossary. **Start here.**
2. **[01 · Platform Foundations](./01-platform-foundations/)** — what platform
   engineering actually is, platform-as-a-product, developer experience, the IDP,
   and team topologies.
3. Continue through the [full curriculum in the ROADMAP](./ROADMAP.md).

---

## Learning tracks

The same core curriculum supports three tracks. See
[`00-orientation/learning-path.md`](./00-orientation/learning-path.md) for details.

- **Track A — Platform Engineer:** build and operate the platform itself.
- **Track B — Developer Experience Engineer:** focus on the IDP and developer tooling.
- **Track C — Platform Architect:** design and evaluate platform strategies.

In a hurry and already strong on DevOps/cloud? There's a
[12-week fast track](./ROADMAP.md#suggested-12-week-fast-track).

---

## Repository structure

```text
platform-engineering-from-zero-to-production/
├── 00-orientation/              # How to use this course (start here)
├── 01-platform-foundations/     # What platform engineering is
├── 02-containerization/ … 23-cheat-sheets/   # The rest of the curriculum
├── shared/                      # Reusable modules, charts, actions, templates
├── scripts/                     # Helper scripts (prereq checks, etc.)
├── diagrams/                    # Architecture, network, and platform diagrams
├── datasets/ · notebooks/       # Supporting data and notebooks
└── .github/                     # CI workflows, issue/PR templates
```

The complete module tree lives in the [ROADMAP](./ROADMAP.md#full-curriculum).

> **Status:** This repository is being built in the open. The **entire core
> curriculum is complete** — all content phases (`00`–`20`), all four platform
> projects, and the four capstone briefs (`21`). The remaining work is the reference
> material: interview preparation (`22`) and cheat sheets (`23`). Track progress in the
> [ROADMAP](./ROADMAP.md) and [CHANGELOG](./CHANGELOG.md).

---

## Contributing

Contributions are welcome — fixes, clarifications, new labs, diagrams, and whole
modules. Please read:

- [CONTRIBUTING.md](./CONTRIBUTING.md) — how to propose and structure changes
- [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md) — the behavior we expect
- [SECURITY.md](./SECURITY.md) — how to report a security issue

New to the content model? Start from
[`shared/templates/module-template.md`](./shared/templates/module-template.md).

---

## License

- **Course content** (prose, lessons, diagrams, exercises) —
  [Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0)](./LICENSE).
- **Source code** (scripts, configuration, manifests, code samples) —
  [MIT License](./LICENSE).

You are free to use, share, and adapt this material — including commercially —
as long as you give attribution and share adaptations of the course content under
the same license. See [LICENSE](./LICENSE) for the full terms.

---

<div align="center">

**Ready?** Open [`00-orientation/`](./00-orientation/) and begin.

*A learner should not finish this course saying "I know how to use Kubernetes."*
*They should be able to say: "I understand the principles underlying modern platforms,*
*and I can build, operate, secure, and measure one — from first principles."*

</div>
