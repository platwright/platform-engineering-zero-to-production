# Learning Path & Tracks

There's one core curriculum, and a few sensible ways through it. This page helps
you choose.

## The default: go in order

If you're newer to platform engineering, **the numbering is the path**:
`00 → 01 → 02 → …`. Each phase builds on the previous one, and the projects
(`04`, `09`, `12`, `16`) are placed exactly where you'll have the knowledge to
tackle them. You don't need to overthink it — start at [01 · Platform
Foundations](../01-platform-foundations/) and keep going.

Choose a **track** below only if you have relevant experience or a specific role
in mind.

---

## Pick a pace

| Pace | Cadence | Core finishes in | Good for |
|------|---------|------------------|----------|
| **Fast track** | ~Full-time | ~12 weeks | Between roles, bootcamp-style focus |
| **Steady** | ~10 hrs/week | ~4–5 months | Learning alongside a job |
| **Relaxed** | ~6 hrs/week | ~6–9 months | Evenings and weekends |

Depth beats speed. It is far better to *understand* 10 modules than to *skim* 20.
Whatever the pace, **do the labs** — reading alone won't build the skill.

---

## The three tracks

All tracks share the Foundations and Kubernetes core. They differ in where you go
deep. You can switch tracks later; they overlap heavily.

### Track A — Platform Engineer

For engineers building and operating the platform itself. This is the fullest path.

```text
01 Platform Foundations
02 Containerization
03 Kubernetes Fundamentals          → Project 1
05 Infrastructure as Code
06 CI/CD for Platform Teams
07 Kubernetes Package Management
08 GitOps                           → Project 2
10 Kubernetes Advanced
11 Observability Engineering        → Project 3
13 Security and Policy Engineering
14 Kubernetes Networking
17 Platform SRE
18 FinOps and Cost Engineering
19 Multi-Cluster and Multi-Cloud
```

### Track B — Developer Experience Engineer

For engineers focused on the IDP and developer-facing tooling.

```text
01 Platform Foundations (all modules)
03 Kubernetes Fundamentals
08 GitOps
15 Developer Experience and IDP     → Project 4
   - IDP architecture
   - Backstage (catalog, templates, plugins)
   - Golden paths
   - Platform CLI tools
   - Developer portal documentation
20 Advanced Platform Topics (metrics & culture, DX focus)
```

### Track C — Platform Architect

For engineers designing and evaluating platform strategies.

```text
01 Platform Foundations (all modules)
03 Kubernetes Fundamentals (architecture focus)
05 Infrastructure as Code (patterns focus)
08 GitOps (patterns focus)
10 Kubernetes Advanced
13 Security and Policy Engineering (architecture focus)
14 Kubernetes Networking (architecture focus)
15 Developer Experience and IDP (architecture focus)
19 Multi-Cluster and Multi-Cloud
20 Advanced Platform Topics (maturity model, metrics, culture)
```

> Whichever track you pick, the **projects and capstones** are what turn knowledge
> into a portfolio. Don't skip them.

---

## Suggested 12-week fast track

For engineers with strong DevOps or cloud experience who want the core quickly.

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

## Before you start

1. **Check prerequisites** — [`prerequisites.md`](./prerequisites.md).
2. **Set up your environment** — [`environment-setup.md`](./environment-setup.md).
3. **Set up cloud, safely** — [`cloud-account-setup.md`](./cloud-account-setup.md).
   You can defer this until the first module that needs cloud (Infrastructure as
   Code / Project 1), but setting the billing alerts early is wise.
4. **Copy the progress tracker** — [`learning-progress.md`](./learning-progress.md).

Then begin: [**01 · Platform Foundations →**](../01-platform-foundations/)
