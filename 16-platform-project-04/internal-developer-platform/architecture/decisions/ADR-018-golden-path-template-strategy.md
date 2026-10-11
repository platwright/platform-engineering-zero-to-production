# ADR-018 — Golden-path template strategy

## Status

Accepted
Date: 2026-10-11

## Context

The IDP's value is in what "create a service" actually produces. We must decide how to
structure the golden-path templates: how much they include, how teams consume them, and
how they evolve. The risk at both extremes is real — too thin and developers still
assemble the hard parts by hand (no cognitive-load reduction); too rigid and teams
can't adapt and route around the platform.

Constraints: a scaffolded service must be **production-ready by default** (hardened,
observable, wired into CI and GitOps); templates must be **versioned** so teams adopt a
known-good one and migrate deliberately; and there must be **escape hatches** for
legitimate deviation (Module 01.3).

## Decision

We will ship **complete, opinionated, versioned** golden-path templates — one per
supported stack (Go, Python/FastAPI) — each producing a full service skeleton (app,
Dockerfile, CI, Helm chart, GitOps overlay, `catalog-info.yaml`, docs), and treat them
as a **product** (the "pipeline templates as a product" idea from Module 06.4, applied
to whole services).

## Consequences

- **Easier:** a developer gets a hardened, observable, deployable service from one form
  — the extraneous cognitive load is genuinely removed, not relocated. Every service
  starts consistent (same security defaults, same CI, same GitOps shape).
- **Easier:** versioned templates mean fixes/improvements roll out as a new version;
  teams migrate on a known path rather than each service drifting.
- **Harder / trade-offs:** maintaining rich templates is real, ongoing work (they're
  software); supporting multiple stacks multiplies that cost; and opinionated defaults
  must still allow documented escape hatches so teams aren't boxed in.

## Alternatives considered

- **Thin "hello world" templates** — cheap to maintain, but leave developers to wire CI,
  deployment, and observability themselves — defeating the IDP's purpose. Rejected.
- **A single mega-template with many options** — one template to maintain, but a
  confusing form and brittle conditional logic. Rejected in favor of one clean template
  per stack.
- **No templates (docs only)** — "here's how to set up a service" — relies on every
  developer doing it right every time. That's the pre-platform status quo we're
  replacing.

## References

- [Module 15.4 · Backstage Software Templates](../../../../15-developer-experience-and-idp/04-backstage-software-templates/)
- [Module 15.6 · Golden Paths](../../../../15-developer-experience-and-idp/06-golden-paths/)
- [Module 06.4 · Pipeline Templates as a Platform Product](../../../../06-cicd-for-platform-teams/04-pipeline-templates-as-product/)
