# ADR-007 — Why Backstage over Port/Cortex/custom

## Status

Accepted
Date: 2026-10-11

## Context

The IDP needs a **developer control plane** — the interface where developers find
services, read docs, and request new ones (the catalog + templates + docs). The common
options are the open-source **Backstage** framework and SaaS portals like **Port**,
**Cortex**, or **Atlassian Compass**, or a **custom** build. This is the build-vs-buy
decision from [Module 01.4](../../../../01-platform-foundations/04-the-internal-developer-platform/README.md),
applied to the portal.

Constraints: we want deep extensibility (custom scaffolder actions, plugins for our
ArgoCD/Grafana/Cost stack), the course's "build on open source you can run" ethos, and
a control plane that can evolve with the platform. We also accept the course's
principle that **the portal is largely a commodity** — our differentiation is the
golden paths behind it, not the UI.

## Decision

We will use **Backstage** (CNCF) as the developer portal for the IDP.

## Consequences

- **Easier:** maximum extensibility — custom software templates, scaffolder actions,
  and plugins (ArgoCD, Kubernetes, Grafana, Cost Insights) integrate the exact stack we
  built in Projects 1–3; the software catalog and TechDocs are first-class.
- **Easier:** it's the de-facto open standard with a large plugin ecosystem, and it's
  free to run — aligned with the course's approach.
- **Harder / trade-offs:** Backstage is a **framework you operate**, not a turnkey SaaS
  — you run a Node.js app and a database, write TypeScript for custom plugins, and own
  upgrades. Port/Cortex trade that effort for speed-to-value and less control.

## Alternatives considered

- **Port / Cortex / Compass (SaaS)** — much faster to stand up, no portal to operate;
  excellent when you want results quickly and can accept SaaS and less extensibility. A
  very reasonable choice; we pick Backstage for control, extensibility, and the
  open-source fit.
- **Custom portal** — total control, but you rebuild catalog, templates, and docs from
  scratch — rarely worth it given Backstage exists. Reserved for genuinely unusual
  needs on top of a solid platform API.

> Remember the guidance from Module 01.4: spend your scarce effort on **golden paths
> and orchestration**, not on reimplementing a catalog UI. The portal choice matters
> far less than the paved roads behind it.

## References

- [Backstage](https://backstage.io/) · [Port](https://www.port.io/) · [Cortex](https://www.cortex.io/)
- [Module 01.4 · The Internal Developer Platform](../../../../01-platform-foundations/04-the-internal-developer-platform/README.md)
- [Module 15.2 · Backstage Fundamentals](../../../../15-developer-experience-and-idp/02-backstage-fundamentals/)
