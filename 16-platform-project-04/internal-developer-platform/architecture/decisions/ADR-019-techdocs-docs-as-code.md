# ADR-019 — Docs-as-code with TechDocs

## Status

Accepted
Date: 2026-10-11

## Context

The IDP needs documentation — for each service, for its APIs, and for the platform
itself — that developers can find and trust. Documentation that lives in a separate
wiki, disconnected from the code, goes stale fast: it's edited by different people, at
different times, and nobody notices when it drifts from reality. We need a
documentation approach that keeps docs close to the code and surfaces them in the
portal next to the thing they describe.

Constraints: docs should be reviewable like code (in pull requests), versioned with the
service, and rendered automatically in Backstage so there's one place to look.

## Decision

We will use **docs-as-code** with **TechDocs**: documentation is written in Markdown
(MkDocs) **in each service's repository**, and Backstage renders it in the portal on the
service's page.

## Consequences

- **Easier:** docs live with the code, change in the same pull request as the code they
  describe, and are reviewed the same way — so they stay current. Backstage renders them
  automatically, giving developers one place (the service page) for code, docs, APIs,
  deployment status, and dashboards.
- **Easier:** the golden-path skeleton ships a `mkdocs.yml` + `docs/` by default, so new
  services are documented from day one.
- **Harder / trade-offs:** TechDocs needs a build/publish step and a place to store
  rendered docs; Markdown/MkDocs is less rich than some dedicated doc platforms; and
  "docs with the code" only works if teams actually treat docs as part of done.

## Alternatives considered

- **A separate wiki (Confluence, etc.)** — familiar and rich, but disconnected from code
  and prone to staleness; no automatic link to the catalog entity. Rejected as the
  default (still fine for org-wide, non-service docs).
- **READMEs only** — better than nothing and co-located with code, but not rendered as
  navigable docs in the portal and awkward for multi-page architecture/runbook docs.
  TechDocs builds on the same docs-as-code instinct with better presentation.
- **No standard** — every team documents differently (or not at all) — the status quo
  TechDocs replaces.

## References

- [Module 15.8 · Developer Portal Documentation](../../../../15-developer-experience-and-idp/08-developer-portal-documentation/)
- [Backstage TechDocs](https://backstage.io/docs/features/techdocs/)
- [MkDocs](https://www.mkdocs.org/)
