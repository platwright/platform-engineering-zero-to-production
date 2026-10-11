# ${{ values.name }}

${{ values.description }}

This service was scaffolded from the **Python FastAPI** golden path. It ships, by
default, with a hardened non-root container, a build → scan → sign → push CI pipeline, a
GitOps deployment overlay, OpenTelemetry instrumentation, and this documentation.

## Local development

```bash
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8080
curl localhost:8080/        # {"message": "hello from ${{ values.name }}", ...}
curl localhost:8080/healthz # {"status": "ok"}
```

## How it ships

- **CI** builds, scans (Trivy), signs (Cosign), and pushes the image by digest.
- **GitOps**: the `gitops/` overlay is delivered by ArgoCD to `${{ values.owner }}-dev`.
- **Observability**: OTLP export to the platform collector; view in Grafana.

## Owner

Owned by `${{ values.owner }}`. See the catalog entity for contacts, dashboards, and
deployment status.
