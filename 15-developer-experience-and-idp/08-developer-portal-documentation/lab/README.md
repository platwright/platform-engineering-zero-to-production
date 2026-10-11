# Lab — Docs-as-Code with TechDocs

> Build a docs-as-code starter for a service: an `mkdocs.yml` and a `docs/` tree with
> an overview, architecture, an ADR, and a runbook, then wire it to a catalog entity so
> TechDocs renders it in the portal. Local MkDocs preview is optional.

**Estimated time:** ~40–55 minutes
**Type:** Build
**Deliverable:** A `docs/` set plus `mkdocs.yml` that previews with MkDocs and renders
in Backstage via the `techdocs-ref` annotation — including an ADR and a runbook.

## Objectives

- Lay out a standard service documentation set as docs-as-code.
- Write an ADR and a runbook to a repeatable standard.
- Wire the docs into the portal with one annotation.

## Prerequisites

- [Module 15.8](../README.md) and a running Backstage app
  ([Module 15.2](../../02-backstage-fundamentals/)).
- The starter files in this folder: [`mkdocs.yml`](./mkdocs.yml) and
  [`docs/`](./docs/).
- Optional local preview: Python 3 + `pip install mkdocs-techdocs-core`.

## Steps

1. **Read the starter.** Open [`mkdocs.yml`](./mkdocs.yml) and the
   [`docs/`](./docs/) tree:

   - [`docs/index.md`](./docs/index.md) — overview and how to run locally.
   - [`docs/architecture.md`](./docs/architecture.md) — how it works and dependencies.
   - [`docs/adr/0001-record-architecture-decisions.md`](./docs/adr/0001-record-architecture-decisions.md)
     — the first ADR (deciding to use ADRs).
   - [`docs/runbooks/service-unavailable.md`](./docs/runbooks/service-unavailable.md)
     — a runbook an alert would link to.

2. **Preview locally (optional).** From this `lab/` folder:

   ```bash
   pip install mkdocs-techdocs-core
   mkdocs serve
   # open http://localhost:8000
   ```

   Navigate the nav defined in `mkdocs.yml`. This is exactly what TechDocs renders.

3. **Write an ADR.** Add `docs/adr/0002-....md` for a real decision (e.g. "use
   PostgreSQL for the orders datastore"). Keep the Status / Context / Decision /
   Consequences structure. Note it is append-only — never edit 0001 to change a past
   decision.

4. **Write a runbook to the standard.** Confirm the runbook has: symptom, how to
   confirm, likely causes, step-by-step mitigation, and escalation. Then (conceptually)
   link it from an alert via a `runbook_url` annotation — the connection back to Phase
   11 observability.

5. **Wire it into the portal.** Ensure the service's `catalog-info.yaml` has the
   TechDocs annotation, then reload Backstage and open the service's **Docs** tab:

   ```yaml
   metadata:
     annotations:
       backstage.io/techdocs-ref: dir:.
   ```

6. **Make it a default.** Note where these files belong in the golden-path skeleton
   (Module 15.4) so every new service is documented from creation.

## Expected result

`mkdocs serve` renders a docs site with an overview, architecture, an ADR, and a
runbook; and the same docs appear on the service's **Docs** tab in Backstage. The
runbook meets the standard and an alert could link straight to it.

## Cleanup

> MkDocs preview is a local process; no cloud resources are created.

```bash
# Stop `mkdocs serve` with Ctrl-C. Optionally remove the local build:
rm -rf site/
# Revert any catalog location/annotation changes in your Backstage app-config.yaml.
```

## Reflection

- Which doc would most shorten your next incident — and is it currently one click from
  the alert?
- If this `docs/` tree shipped in the golden-path skeleton, what would change about doc
  coverage across the org?
- Why is an ADR more valuable six months later than the day it is written?

## Stretch goals (optional)

- Add a `docs/api.md` that embeds or links the service's OpenAPI spec (Module 15.3).
- Add Material for MkDocs theming and a diagram to `architecture.md`.
- Draft the platform's *own* TechDocs home page: how to use the Go golden path, the
  platform API reference, and the support contract.
