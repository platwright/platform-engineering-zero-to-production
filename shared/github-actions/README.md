# `shared/github-actions/`

Shared composite actions and reusable workflows that application and platform
repositories consume instead of writing pipelines from scratch.

Planned (introduced in **[06 · CI/CD for Platform Teams](../../06-cicd-for-platform-teams/)**):

```text
build-and-push/     # composite: build → scan (Trivy) → sign (Cosign) → push
terraform-plan/     # composite: fmt → validate → tfsec → plan (comment on PR)
deploy-helm/        # composite: helm upgrade with values per environment
```

Reusable workflows (called via `workflow_call`) demonstrate "pipeline templates
as a product": teams adopt a versioned golden-path pipeline rather than
maintaining their own.

> 🚧 Populated during Phase 5. See the [ROADMAP](../../ROADMAP.md).
