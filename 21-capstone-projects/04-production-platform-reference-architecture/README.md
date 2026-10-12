# Capstone 4 — Production Platform Reference Architecture

> Combine all previous capstones into a single, fully documented reference architecture
> that **another organization could adopt**. This is the summit of the course: not a new
> build, but the integration of everything — the cluster platform, the IDP, and the
> multi-cluster fleet — into one coherent, reproducible, exhaustively documented whole.

**Type:** Capstone (the ultimate portfolio piece)
**Estimated effort:** ~80–120 hours (or an ongoing, evolving project)
**Builds on:** Capstones [1](../01-production-kubernetes-platform/),
[2](../02-full-idp-with-backstage/), and
[3](../03-multi-cluster-gitops-platform/) — and, through them, the entire course.

## Goal

A complete, documented platform another organization could take and adopt: a developer
opens a portal, picks a golden path, and ships to a secured, observable, cost-attributed,
multi-cluster platform — with every layer explained, every decision recorded, and the
whole thing reproducible from the repository. If Capstones 1–3 prove you can build the
pieces, Capstone 4 proves you can architect, integrate, and *communicate* a platform.

## The reference architecture

```text
                     Developer
                         │
                         ▼
                    Backstage IDP
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         Go Service  Python App  (RAG App)      ← golden-path templates
         Template    Template    Template
              │          │          │
              └──────────┼──────────┘
                         ▼
                Platform CI/CD pipeline          ← build → scan → sign → push
                         │
              ┌──────────┼──────────┐
              ▼          ▼          ▼
             Dev      Staging     Prod           ← GitOps promotion with gates
          (auto-sync) (auto-sync) (manual)
              │          │          │
              └──────────┼──────────┘
                         ▼
               Platform services layer
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
   GitOps Engine    Observability    Security layer
   (ArgoCD)         (LGTM stack)     (Kyverno + Falco)
        │                │                │
        └────────────────┼────────────────┘
                         ▼
              Kubernetes clusters (GKE)
              ┌──────────┼──────────┐
              ▼          ▼          ▼
         Cilium CNI   Karpenter   Gateway API
                         │
                         ▼
                    Google Cloud
                (GKE, GCS, Artifact Registry, Secret Manager, KMS)
```

Every box in that diagram is something you built and documented earlier. Capstone 4 is
the act of assembling them into one reference, resolving the integration seams, and
documenting it so thoroughly that a stranger could adopt it.

## What it combines

- **Capstone 1** — the production Kubernetes platform (cluster, security, GitOps,
  observability, cost, DR).
- **Capstone 2** — the full Backstage IDP (self-service onboarding, golden paths,
  plugins).
- **Capstone 3** — the multi-cluster GitOps fleet (management cluster, Cluster API,
  cross-region DR).
- **The AI path (optional):** a third golden-path template for a RAG/AI service, tying
  into [Module 20.2 · AI-Assisted Platform Engineering](../../20-advanced-platform-topics/02-ai-assisted-platform-engineering/)
  and the "platform that hosts AI services" idea.

## Definition of done

Meets the [portfolio standard](../portfolio-standard.md) **completely** and answers
**every** question in the [production readiness checklist](../production-readiness-checklist.md).
This is the one capstone where "mostly done" isn't the goal — a reference architecture
others adopt must be whole. Concretely:

- [ ] A developer goes from "create service" in the portal to running-in-prod across the
  multi-cluster fleet, self-service.
- [ ] Every structural concern (security, delivery, observability, cost, DR) is built in
  and demonstrable.
- [ ] The entire platform is reproducible from the repository by someone who has never
  seen it.
- [ ] Every significant decision has an ADR; every failure mode has a runbook.
- [ ] The production readiness checklist is fully answered (gaps are documented
  limitations, not surprises).

## Deliverables

- A **GitHub repository**: complete, reproducible, documented.
- **Architecture Decision Records** for every major choice (consolidate and extend the
  ADRs from Projects 1–4 and Capstones 1–3).
- A **production readiness checklist**, filled and passing (or with documented
  limitations).
- A **runbook library** for all platform failure modes.
- An **IDP demo video** of the end-to-end developer journey.
- A **blog post**: *"How We Built Our Internal Developer Platform"* — the narrative that
  turns a repository into something others learn from.

> The blog post and demo matter more than they look. The difference between an engineer
> who *built* a platform and one who can *lead* platform work is the ability to explain
> the why — the decisions, the trade-offs, the lessons. That's what a reference
> architecture communicates.

## Where to start

1. **Don't start from scratch.** Capstone 4 is Capstones 1–3 integrated. Build (or reuse)
   those first.
2. **Resolve the seams:** make the IDP (Capstone 2) scaffold onto the multi-cluster fleet
   (Capstone 3) running the hardened platform (Capstone 1). The integration *is* the
   work.
3. **Document relentlessly:** consolidate ADRs, write the runbook library, fill the
   readiness checklist, and record the demo.
4. **Write the story:** the blog post explaining how and why you built it.

> Treat this as a living reference, not a one-time deliverable
> ([the repository's long-term-evolution philosophy](../../README.md)). The best
> platform portfolios keep growing: new Kubernetes releases, new tooling, case studies,
> and lessons learned.

---

## 🎓 You've reached the summit

If you can build and document this, you can honestly say what the course set out to
teach you to say:

> "I understand the infrastructure and software-engineering principles underlying modern
> platforms. I can build a self-service Internal Developer Platform, operate it with SLOs
> and on-call, secure it with policy-as-code and supply-chain verification, run it across
> clusters and regions, attribute and optimize its cost — and measure its impact on
> developer productivity. From first principles."

Next, sharpen how you *talk* about all this: the
[Interview Preparation](../../22-interview-preparation/) track and the
[Cheat Sheets](../../23-cheat-sheets/).

---

_Back to:_ [Capstones overview](../README.md)
· _Previous:_ [03 — Multi-Cluster GitOps Platform](../03-multi-cluster-gitops-platform/)
