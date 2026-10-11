# ${{ values.name }}

${{ values.description }}

A Go microservice generated from the platform **go-microservice** golden-path
template. It starts on the paved road: a secure multi-stage build, a Helm chart with
sane defaults, platform CI, and a catalog entry — all wired in by default.

## Owner

This service is owned by `${{ values.owner }}`.

## Run locally

```bash
go run .
# serves on :8080
curl localhost:8080/healthz
```

## Build the container

```bash
docker build -t ${{ values.name }}:dev .
docker run -p 8080:8080 ${{ values.name }}:dev
```

## What you get by default

- A health endpoint at `/healthz`.
- A non-root, distroless runtime image.
- CI that consumes the platform reusable workflow (lint, test, build, scan, sign).
- A Helm chart under `chart/` for GitOps deployment.
- A `catalog-info.yaml` so the service appears in the developer portal.

## Documentation

Docs live with the code and render in the portal via TechDocs. See `mkdocs.yml` and
the `docs/` directory (added in the documentation golden path).
