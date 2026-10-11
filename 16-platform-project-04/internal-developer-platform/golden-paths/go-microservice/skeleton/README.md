# ${{ values.name }}

${{ values.description }}

A Go microservice scaffolded from the platform golden path. Hardened container, CI,
GitOps deployment, observability, and docs are wired in by default.

- **Run locally:** `go run .` then `curl localhost:8080/`
- **Docs:** see `docs/` (rendered as TechDocs in the portal)
- **Deploy:** the `gitops/` overlay is delivered by ArgoCD
- **Owner:** `${{ values.owner }}`
