# Production readiness checklist

> Before you call a platform "production-ready," it must *answer* these questions —
> not vaguely, but concretely. Every capstone works through this checklist. A question
> you can't answer is a gap to close or a limitation to document.

This is the operational companion to the [portfolio standard](./portfolio-standard.md):
the portfolio standard says *what a project must contain*; this says *what it must be
able to withstand*.

## Availability

- [ ] What is the **SLO** for each platform service?
- [ ] What happens if **ArgoCD is down**? (Can running workloads continue? Can you still
  deploy in an emergency?)
- [ ] What happens if the **API server is unreachable**?
- [ ] Is there a **fallback for every critical dependency**?
- [ ] Are **PodDisruptionBudgets** configured for platform workloads?

## Security

- [ ] Are **all containers running as non-root**?
- [ ] Are images **signed and signature-verified** before deployment?
- [ ] Are there **network policies enforcing default-deny** in every namespace?
- [ ] Are **secrets stored outside Git**?
- [ ] Is **RBAC following least privilege**?
- [ ] Is **runtime security (Falco)** deployed and alerting?

## Observability

- [ ] Can you **trace a deployment from Git push to running pod**?
- [ ] Can you **see which team is consuming the most resources**?
- [ ] Do **all platform service alerts link to runbooks**?
- [ ] Are **SLO burn-rate alerts** configured?

## Cost

- [ ] Is **every workload labeled** with team and cost-center?
- [ ] Are **cost reports delivered to teams** (e.g. weekly)?
- [ ] Are **spot instances used** for appropriate workloads?
- [ ] Is **cluster autoscaling configured to scale down** when idle (e.g. at night)?

## Operations

- [ ] Can a **new cluster be provisioned end-to-end from Terraform**?
- [ ] Is there a **tested DR procedure** for total cluster loss?
- [ ] Are **cluster upgrades automated and tested**?
- [ ] Is there a **runbook for every alert**?

---

## Where the course taught each answer

You already learned how to answer all of these. If a box is hard to check, revisit the
module:

| Area | Where it's taught |
|------|-------------------|
| SLOs, burn-rate alerts | [Module 11.7](../11-observability-engineering/07-slos-and-error-budgets/), [Module 17.2](../17-platform-sre/02-platform-slos/) |
| PodDisruptionBudgets, availability | [Module 03.8](../03-kubernetes-fundamentals/08-health-and-scheduling/) |
| Non-root, signed images, runtime security | [Module 02.5](../02-containerization/05-container-security/), [Phase 10 · Security](../13-security-and-policy-engineering/) |
| Default-deny network policy | [Module 14.3](../14-kubernetes-networking/03-network-policies/) |
| Secrets outside Git | [Module 13.4](../13-security-and-policy-engineering/04-secret-management/), Project 2 |
| RBAC least privilege | [Module 03.6](../03-kubernetes-fundamentals/06-rbac/), [Module 13.2](../13-security-and-policy-engineering/02-kubernetes-rbac-deep-dive/) |
| Trace push→pod, resource attribution | [Phase 9 · Observability](../11-observability-engineering/), [Phase 14 · FinOps](../18-finops-and-cost-engineering/) |
| Cost labels, spot, scale-down | [Phase 14 · FinOps](../18-finops-and-cost-engineering/) |
| Provision from Terraform | [Phase 4 · IaC](../05-infrastructure-as-code/) |
| DR, cluster upgrades | [Module 17.6](../17-platform-sre/06-disaster-recovery-for-platform/) |
| Runbook per alert | [Module 17.3](../17-platform-sre/03-platform-incident-management/) |

> The goal isn't to tick every box on day one — some become documented "known
> limitations." The goal is to have *consciously answered* each question, so nothing
> about how your platform behaves under stress is a surprise.
