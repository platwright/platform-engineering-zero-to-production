# ${{ values.name }}

${{ values.description }}

This service was scaffolded from the **Go microservice** golden path. It ships, by
default, with a hardened container, a build → scan → sign → push CI pipeline, a GitOps
deployment overlay, OpenTelemetry instrumentation, and this documentation — rendered in
the developer portal via TechDocs.

## Local development

```bash
go run .
curl localhost:8080/        # hello from ${{ values.name }}
curl localhost:8080/healthz # ok
```

## How it ships

- **CI** builds, scans (Trivy), signs (Cosign), and pushes the image by digest.
- **GitOps**: the overlay under `gitops/` is delivered by ArgoCD to the `${{ values.owner }}-dev`
  namespace; promotion to staging/prod follows the platform's GitOps flow.
- **Observability**: the app exports OTLP to the platform collector; find its metrics,
  logs, and traces in Grafana.

## Owner

Owned by `${{ values.owner }}`. See the entity in the software catalog for contacts,
dashboards, and deployment status.
