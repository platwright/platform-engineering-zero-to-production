# ${{ values.name }}

${{ values.description }}

A Python/FastAPI service scaffolded from the platform golden path. Hardened container,
CI, GitOps deployment, observability, and docs are wired in by default.

- **Run locally:** `uvicorn app.main:app --reload --port 8080`
- **Docs:** see `docs/` (rendered as TechDocs in the portal)
- **Deploy:** the `gitops/` overlay is delivered by ArgoCD
- **Owner:** `${{ values.owner }}`
