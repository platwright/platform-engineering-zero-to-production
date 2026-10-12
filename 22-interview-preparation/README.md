# Interview Prep — Platform Engineering Interview Track

> A domain-by-domain question bank with model answers for platform engineering
> interviews — from fundamentals to senior and staff system design. Every question
> is answerable from this course, and each answer links back to the module that
> teaches it, so interview prep doubles as revision.

## What this track is

This is the reference companion to the curriculum: eleven question banks that turn
the modules you studied into interview-ready answers. The questions expand the seed
set from the course outline with the obvious adjacent questions a real interview
asks. Answers aim for the course's depth — real mechanisms, not buzzwords — and call
out the **red flags** that signal a weak candidate.

## How to use it

Practice like an interview, not a reading exercise:

1. Read the question and the **What they're really asking** line to find the signal.
2. Answer **out loud**, and first explain the idea **without naming a specific tool** — describe the problem and the mechanism, then name the tool.
3. Only then open the model answer and compare; note anything you missed.
4. Follow the **Going deeper** links to revise the module when a gap shows up.
5. Re-read the **Red flags** so you can avoid the common weak answers under pressure.

For system design, talk through the structure — clarify, state assumptions, design
in layers, name trade-offs, and close with how you would measure success.

## Topic files

| Domain | What it covers | Taught in |
|--------|----------------|-----------|
| [Platform engineering fundamentals](./platform-engineering-fundamentals.md) | Definition, DevOps/SRE, cognitive load, golden paths, TVP, success | [Phase 1](../01-platform-foundations/) |
| [Containers and Kubernetes](./containers-and-kubernetes.md) | Isolation, the control plane, controllers, probes, debugging | [Phases 2–3](../03-kubernetes-fundamentals/) |
| [Infrastructure as Code](./infrastructure-as-code.md) | State, drift, secrets, modules, testing, Crossplane | [Phase 4](../05-infrastructure-as-code/) |
| [GitOps](./gitops.md) | Reconciliation, ArgoCD drift, App of Apps, promotion, rollback | [Phase 7](../08-gitops/) |
| [Observability](./observability.md) | Pillars, OpenTelemetry, SLOs, burn-rate alerting, sampling | [Phase 9](../11-observability-engineering/) |
| [Security](./security.md) | Pod Security, RBAC, Kyverno, secrets, supply chain, runtime | [Phase 10](../13-security-and-policy-engineering/) |
| [Networking](./networking.md) | Flat pod model, Services/DNS, NetworkPolicy, Cilium, Gateway API | [Phase 11](../14-kubernetes-networking/) |
| [Developer experience and IDP](./developer-experience.md) | Cognitive load, DORA/SPACE, five planes, Backstage | [Phase 12](../15-developer-experience-and-idp/) |
| [Platform SRE](./platform-sre.md) | Platform SLOs, error budgets, toil, incidents, chaos, DR | [Phase 13](../17-platform-sre/) |
| [FinOps](./finops.md) | Pricing, attribution, OpenCost, right-sizing, showback/chargeback | [Phase 14](../18-finops-and-cost-engineering/) |
| [Platform architecture and system design](./system-design.md) | Open-ended design: 100 teams, self-service, fleets, metrics | [Phase 15](../19-multi-cluster-and-multi-cloud/) and [capstones](../21-capstone-projects/) |

## Every answer is taught in the course

Nothing here requires outside material. If a question stumps you, the **Going deeper**
links point to the exact module that teaches it, so you can close the gap and come
back. Use the [ROADMAP](../ROADMAP.md) to see where each domain sits in the full
curriculum, and treat this track as the final lap before an interview.
