# `shared/` — reusable building blocks

This directory holds assets meant to be reused across modules, labs, and projects,
so the course teaches *one good way* to do something instead of re-inventing it in
every module.

| Folder | What goes here |
|--------|----------------|
| [`terraform-modules/`](./terraform-modules/) | Reusable Terraform modules (e.g. `gke-cluster`, `vpc`, `gcs-bucket`) consumed by project environments. |
| [`helm-charts/`](./helm-charts/) | Platform-standard Helm charts (e.g. a hardened `platform-app` chart). |
| [`github-actions/`](./github-actions/) | Shared composite actions and reusable workflows (build-and-push, terraform-plan, deploy-helm). |
| [`scripts/`](./scripts/) | Helper scripts reused by multiple modules. |
| [`templates/`](./templates/) | Authoring templates for new content (module, lab, ADR). |

## Principles

- **Versioned interfaces.** Shared modules and charts expose a stable, documented
  interface. Breaking changes are called out in the [CHANGELOG](../CHANGELOG.md).
- **Minimal required inputs, sensible defaults.** A consumer should get a secure,
  working result with as few inputs as possible.
- **Secure by default.** Non-root containers, least-privilege IAM, no secrets in
  code. If a shared asset makes insecure defaults easy, fix the asset.
- **Documented.** Every module/chart/action has a README with inputs, outputs,
  and an example.

Most subfolders are populated as the relevant curriculum phases land — see the
[ROADMAP](../ROADMAP.md).
