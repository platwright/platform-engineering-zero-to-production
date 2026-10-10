# ADR-013 — Why app-of-apps + ApplicationSets

## Status

Accepted
Date: 2026-10-10

## Context

The platform serves multiple teams, each with services, each deployed to three
environments. Creating and maintaining an ArgoCD `Application` by hand for every
service × environment would be dozens of near-identical YAML files — tedious,
error-prone, and a magnet for copy-paste drift. We need a way to bootstrap the whole
platform from one place and to generate Applications programmatically.

Constraints: adding a service or environment should be a small, reviewable change;
there should be a single entry point to bootstrap a cluster; and the pattern must
scale without hand-maintained Application sprawl.

## Decision

We will bootstrap with the **app-of-apps** pattern (one root `Application` that
creates the others) and generate per-environment Applications with
**ApplicationSets** using a Git directory generator.

## Consequences

- **Easier:** `kubectl apply` of a single root Application bootstraps the entire
  platform (platform components + all app ApplicationSets). Rebuilding a cluster is
  one command plus a sync.
- **Easier:** adding a service is adding a folder under `apps/.../overlays/*`; the
  ApplicationSet generates its Applications automatically — no new Application YAML to
  write.
- **Easier:** environment sync policy is expressed once per ApplicationSet (non-prod
  auto-sync, prod manual), not repeated per app.
- **Harder / trade-offs:** ApplicationSet templating (path segments, generators) has
  a learning curve, and a bad template change can affect many generated Applications
  at once — so the ApplicationSets themselves warrant careful review.

## Alternatives considered

- **Hand-written Applications per service/env** — simplest to understand for one or
  two apps, but doesn't scale and invites copy-paste drift. Rejected for a
  multi-team platform.
- **A single giant Application for everything** — loses per-service/per-environment
  sync status, health, and blast-radius isolation. Rejected.
- **Helm-templated Applications** — viable, but ApplicationSets are purpose-built for
  exactly this generation problem and integrate natively with ArgoCD.

## References

- [Argo CD — Cluster Bootstrapping (app of apps)](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Argo CD — ApplicationSet](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/)
