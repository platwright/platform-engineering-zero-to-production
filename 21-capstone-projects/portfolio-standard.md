# Portfolio standard

> A capstone (or any project) is only a portfolio piece when someone else can
> understand it, trust it, and reproduce it. "A cluster of YAML files without
> architecture, without documentation, and without reproducible deployment is **not**
> a portfolio piece." This is the bar every capstone is held to.

## The checklist

A project is portfolio-ready only if it has all of these:

- [ ] **Clear problem statement** in the README — what problem does this platform solve,
  and for whom?
- [ ] **Architecture diagram** — a real one that explains the system, not a box-and-line
  placeholder.
- [ ] **Fully reproducible** — another engineer can deploy it from scratch, from your
  docs, without you in the room.
- [ ] **IaC for all infrastructure** (Terraform) — no click-ops, no undocumented manual
  steps.
- [ ] **Delivered via GitOps** — the cluster's state comes from Git, not `kubectl apply`.
- [ ] **Tests** — IaC tests (Terratest), policy tests, and smoke tests.
- [ ] **Observability** — metrics, logs, and traces configured and demonstrably working.
- [ ] **SLOs** defined for every platform service.
- [ ] **Security** — non-root containers, signed images, policy enforcement.
- [ ] **Secrets managed** — nothing sensitive in Git; an external secret store.
- [ ] **Cost considerations documented** — what it costs, and how you'd reduce it.
- [ ] **Runbooks** for at least three failure modes.
- [ ] **DR plan** documented *and tested* (not assumed).
- [ ] **Known limitations** — an honest list of what it doesn't do.
- [ ] **Future improvements** — where you'd take it next.
- [ ] **ADRs** — architecture decisions documented, with the trade-offs you weighed.
- [ ] **Onboarding guide** — how a new developer gets their first service deployed.

## Why each item matters

The list isn't bureaucracy — each item is a signal a hiring manager or teammate looks
for:

- **Problem statement + architecture diagram** show you can *think about systems*, not
  just assemble tools.
- **Reproducible + IaC + GitOps** show you build things that survive you leaving — the
  whole point of platform engineering.
- **Tests + SLOs + runbooks + DR** show you think about *operating* the thing, not just
  standing it up.
- **Security + secrets + cost** show the structural concerns are built in, not bolted
  on (the course's recurring theme).
- **ADRs + known limitations + future work** show engineering maturity: you made
  deliberate choices, you know the trade-offs, and you're honest about the gaps.

## How to use it

- **Before you start:** read this list so you build the right things from the beginning.
  Retrofitting observability, tests, and docs onto a finished pile of YAML is miserable.
- **As you build:** write the ADRs and runbooks *as decisions happen and failures
  occur*, not at the end from memory.
- **Before you call it done:** walk the list honestly. Any unchecked box is either a
  thing to finish or a "known limitation" to document — never a thing to hide.

> The documentation is not an afterthought to the build; for a portfolio piece, it *is*
> half the build. A modest platform that is beautifully documented and reproducible
> beats an ambitious one nobody can understand or run.

See also the [production readiness checklist](./production-readiness-checklist.md) for
the operational questions every capstone must answer.
