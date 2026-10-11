# Lab — Build a Go Microservice Golden-Path Template

> Build a Backstage Software Template that scaffolds a production-ready Go service:
> a parameter form, a `fetch → publish → register` step sequence, and a real skeleton
> (Go service, secure Dockerfile, Helm chart, platform CI, `catalog-info.yaml`). The
> core is local; the GitHub publish step is optional.

**Estimated time:** ~60–90 minutes
**Type:** Build
**Deliverable:** A working `go-microservice` template that appears in Backstage's
*Create* page and generates a complete, catalogued service from a short form.

## Objectives

- Author a `Template` with typed parameters and ordered steps.
- Template a multi-file skeleton with `${{ values.* }}` substitutions.
- Register the template in Backstage and run it (publish optional).

## Prerequisites

- [Module 15.4](../README.md) and a running Backstage app from
  [Module 15.2](../../02-backstage-fundamentals/).
- Go 1.22+ to build/run the generated service locally (optional).
- The starter files in this folder: [`template.yaml`](./template.yaml) and the
  [`skeleton/`](./skeleton/) directory.
- For the optional publish step: a GitHub account and a token with `repo` scope.

## Steps

1. **Read the template.** Open [`template.yaml`](./template.yaml). Identify the three
   parts: `metadata`, `spec.parameters` (the form: `name`, `owner`, `description`,
   optional advanced overrides), and `spec.steps` (`fetch:template` → `publish:github`
   → `catalog:register`). Note `copyWithoutTemplating` protects the CI workflow's
   GitHub expressions.

2. **Read the skeleton.** Browse [`skeleton/`](./skeleton/). Every file is a real
   default you now get for free:

   - [`main.go`](./skeleton/main.go) — a minimal HTTP service with a health endpoint.
   - [`Dockerfile`](./skeleton/Dockerfile) — multi-stage, non-root, distroless.
   - [`chart/`](./skeleton/chart/) — a Helm chart with sane defaults.
   - [`.github/workflows/ci.yaml`](./skeleton/.github/workflows/ci.yaml) — CI that
     *consumes* the platform's reusable workflow (Module 06.4). `copyWithoutTemplating`
     preserves its GitHub Actions expressions.
   - [`catalog-info.yaml`](./skeleton/catalog-info.yaml) — so the service is catalogued
     on creation.

   Spot the `${{ values.name }}` and `${{ values.owner }}` placeholders that the
   scaffolder fills in.

3. **Register the template in Backstage.** Add a catalog location pointing at
   `template.yaml`, then reload:

   ```yaml
   # app-config.yaml
   catalog:
     locations:
       - type: file
         target: ../../path/to/template.yaml
         rules:
           - allow: [Template]
   ```

4. **Run the template (dry run / local).** Open **Create** in Backstage, choose *Go
   Microservice*, fill in a name (e.g. `widget-service`) and an owner, and submit.
   Without GitHub credentials, run the scaffolder in dry-run mode to inspect the
   rendered output rather than publishing.

5. **(Optional) Publish for real.** Configure a GitHub integration token in
   `app-config.yaml` (via an environment variable), set `repoUrl`'s owner to your org,
   and submit. Backstage creates the repo, pushes the rendered skeleton, and registers
   it in the catalog. Open the new repo and confirm `catalog-info.yaml`, the chart, and
   the workflow are all present and correctly named.

6. **Verify the generated service builds (optional).** Clone the generated repo (or use
   the dry-run output) and run:

   ```bash
   go build ./...
   go run .   # serves on :8080; try: curl localhost:8080/healthz
   ```

## Expected result

*Go Microservice* appears in Backstage's *Create* page. Submitting the form produces a
complete service — Go code, Dockerfile, Helm chart, platform CI, and a
`catalog-info.yaml` named after the service — and (if you published) registers it in
the catalog automatically. **Ask little, generate a lot.**

## Cleanup

> Delete any throwaway repositories you published; local runs create nothing to bill.

```bash
# If you published a test repo, delete it from GitHub (Settings -> Danger Zone),
# and remove the test entity from the catalog. Revert any app-config.yaml locations.
```

## Reflection

- How many decisions did the developer make versus how much they received? Could any
  parameter become a convention instead?
- Which earlier phases did this one template pull together (Dockerfile, CI, chart,
  catalog)?
- What custom action would you add to also open a GitOps PR, so the service deploys
  itself? (That is the Project 4 orchestration.)

## Stretch goals (optional)

- Add a default-off **advanced** parameter page (e.g. override the base image) as a
  visible escape hatch.
- Add a `github:actions:dispatch` step to trigger the first CI build after publish.
- Add a boolean `needsDatabase` parameter and sketch the custom action that would
  provision Postgres via Crossplane (the resource plane).
